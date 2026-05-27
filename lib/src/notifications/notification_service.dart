import 'package:flutter/foundation.dart';

import 'notification.dart';
import 'notification_progress_controller.dart';

/// Workbench-level notification service.
///
/// Hosts mount a single `NotificationHost` widget inside
/// [WorkbenchLayout] and call [show] from anywhere in the subtree to
/// post stacked toast cards anchored bottom-right.
///
/// The service exposes its current notification list as an immutable
/// view through [notifications]; the host widget observes this list
/// via [ChangeNotifier] subscription and rebuilds when it changes.
///
/// See package SPEC §10 for design rationale.
class NotificationService extends ChangeNotifier {
  final List<WorkbenchNotification> _notifications = <WorkbenchNotification>[];
  final Map<Object, NotificationProgressController> _progressControllers =
      <Object, NotificationProgressController>{};
  int _nextId = 0;

  /// Source of [DateTime.now] for the `createdAt` field. Injectable
  /// so tests can pin time without monkeypatching the clock.
  final DateTime Function() _now;

  /// Constructs a notification service.
  ///
  /// [now] defaults to [DateTime.now] and is overridable for tests
  /// that need deterministic timestamps.
  NotificationService({DateTime Function()? now}) : _now = now ?? DateTime.now;

  /// Current notifications, oldest first. Returned as an unmodifiable
  /// view — mutations must go through [show] / [dismiss] so observers
  /// receive change notifications.
  List<WorkbenchNotification> get notifications =>
      List.unmodifiable(_notifications);

  /// Post a new notification.
  ///
  /// Returns the [WorkbenchNotification.id] minted for the card so
  /// callers can pass it to [dismiss]. Listeners are notified
  /// synchronously.
  Object show({
    required NotificationSeverity severity,
    required String message,
    List<NotificationAction> actions = const [],
  }) {
    final id = _mintId();
    final notification = WorkbenchNotification(
      id: id,
      severity: severity,
      message: message,
      actions: List.unmodifiable(actions),
      createdAt: _now(),
    );
    _notifications.add(notification);
    notifyListeners();
    return id;
  }

  /// Post an in-flight progress notification.
  ///
  /// Returns a [NotificationProgressController] the host uses to
  /// [NotificationProgressController.report] updates,
  /// [NotificationProgressController.complete] the task successfully,
  /// or [NotificationProgressController.fail] with an error. When
  /// [cancellable] is `true`, the card renders a cancel affordance
  /// that resolves [NotificationProgressController.cancellation].
  ///
  /// The progress card persists until the controller terminates — it
  /// is exempt from the standard auto-dismiss timer (SPEC §10
  /// "Dismissal policy by severity").
  NotificationProgressController showProgress({
    required String message,
    bool cancellable = false,
  }) {
    final id = _mintId();
    final notification = WorkbenchNotification(
      id: id,
      severity: NotificationSeverity.progress,
      message: message,
      createdAt: _now(),
      cancellable: cancellable,
    );
    _notifications.add(notification);
    final controller = NotificationProgressController(
      id: id,
      service: this,
      cancellable: cancellable,
    );
    _progressControllers[id] = controller;
    notifyListeners();
    return controller;
  }

  /// Dismiss the notification with [id], if present.
  ///
  /// No-op when [id] does not match any live notification — callers
  /// commonly invoke this from a timer or action callback racing
  /// against an operator-initiated dismiss, and the service tolerates
  /// the double dismissal silently.
  void dismiss(Object id) {
    final removed = _notifications.length;
    _notifications.removeWhere((n) => n.id == id);
    final controller = _progressControllers.remove(id);
    controller?.onExternalDismiss();
    if (_notifications.length != removed) {
      notifyListeners();
    }
  }

  /// Dismiss every live notification. Used by the host widget's
  /// "Clear All" control.
  void clear() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
    final controllers = _progressControllers.values.toList(growable: false);
    _progressControllers.clear();
    for (final controller in controllers) {
      controller.onExternalDismiss();
    }
    notifyListeners();
  }

  /// Returns the live [NotificationProgressController] for [id], if
  /// the notification still carries one. The host widget uses this to
  /// wire the cancel affordance back to the controller without
  /// threading callbacks through the [WorkbenchNotification] value
  /// type.
  NotificationProgressController? progressControllerFor(Object id) =>
      _progressControllers[id];

  /// Internal — update the message/progress of a live progress
  /// notification in place. Used by
  /// [NotificationProgressController.report]. The notification's [id]
  /// and `createdAt` are preserved so the host widget updates without
  /// re-stacking.
  void updateProgress({
    required Object id,
    String? message,
    double? progress,
    required bool clearProgress,
  }) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return;
    final current = _notifications[index];
    final next = current.copyWith(
      message: message,
      progress: clearProgress ? null : (progress ?? current.progress),
    );
    if (next == current) return;
    _notifications[index] = next;
    notifyListeners();
  }

  /// Internal — convert a live progress notification to a terminal
  /// severity (success or error) in place. Used by
  /// [NotificationProgressController.complete] and
  /// [NotificationProgressController.fail].
  void replaceSeverity({
    required Object id,
    required NotificationSeverity severity,
    required String message,
  }) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) {
      _progressControllers.remove(id);
      return;
    }
    final current = _notifications[index];
    _notifications[index] = current.copyWith(
      severity: severity,
      message: message,
      progress: null,
      cancellable: false,
    );
    _progressControllers.remove(id);
    notifyListeners();
  }

  /// Mint a fresh opaque id. Ids are monotonically increasing
  /// integers wrapped in [Object] so callers cannot meaningfully
  /// arithmetic on them.
  Object _mintId() {
    final value = _nextId;
    _nextId += 1;
    return _NotificationId(value);
  }
}

/// Opaque identifier for a live notification. Wraps an int so the
/// public API exposes [Object] without callers depending on the
/// representation.
@immutable
class _NotificationId {
  final int value;
  const _NotificationId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _NotificationId && other.value == value);

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NotificationId($value)';
}

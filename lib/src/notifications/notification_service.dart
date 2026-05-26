import 'package:flutter/foundation.dart';

import 'notification.dart';

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

  /// Dismiss the notification with [id], if present.
  ///
  /// No-op when [id] does not match any live notification — callers
  /// commonly invoke this from a timer or action callback racing
  /// against an operator-initiated dismiss, and the service tolerates
  /// the double dismissal silently.
  void dismiss(Object id) {
    final removed = _notifications.length;
    _notifications.removeWhere((n) => n.id == id);
    if (_notifications.length != removed) {
      notifyListeners();
    }
  }

  /// Dismiss every live notification. Used by the host widget's
  /// "Clear All" control.
  void clear() {
    if (_notifications.isEmpty) return;
    _notifications.clear();
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

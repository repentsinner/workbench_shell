import 'dart:async';

import 'notification.dart';
import 'notification_service.dart';

/// Controller returned by [NotificationService.showProgress].
///
/// Exposes the mutable surface for in-flight progress: [report] to
/// update message and progress in place, [complete] for success
/// termination, [fail] for failure termination, and [cancellation] to
/// observe operator-initiated cancel (cancellable cards only).
///
/// All terminal methods are idempotent — calling [complete] or [fail]
/// after termination is a silent no-op so racing host code does not
/// crash. The [cancellation] future also completes when the card is
/// terminated externally so awaiting hosts don't leak.
///
/// See package SPEC §10 "Progress notifications".
class NotificationProgressController {
  /// The id of the live notification this controller drives.
  final Object id;

  final NotificationService _service;
  final bool _cancellable;
  final Completer<void> _cancellation = Completer<void>();
  bool _terminated = false;

  /// Internal — instances are minted by
  /// [NotificationService.showProgress].
  NotificationProgressController({
    required this.id,
    required NotificationService service,
    required bool cancellable,
  }) : _service = service,
       _cancellable = cancellable;

  /// Whether the controller is still tracking an in-flight task.
  /// Becomes `false` after [complete] or [fail].
  bool get isActive => !_terminated;

  /// Future that completes when the operator presses the cancel
  /// affordance, when the card is dismissed externally, or when the
  /// host terminates the controller. Hosts awaiting cancellation
  /// always observe completion; they then call [fail] (or [complete])
  /// to convert the card to its terminal form.
  Future<void> get cancellation => _cancellation.future;

  /// Update the live notification's message and progress in place.
  ///
  /// [progress] is clamped to `[0.0, 1.0]`. Omitting [progress] keeps
  /// the previous value (including `null` for indeterminate). Omitting
  /// [message] keeps the previous message. The notification's [id] is
  /// preserved so the host widget updates in place without re-stacking.
  ///
  /// No-op after termination.
  void report({String? message, double? progress}) {
    if (_terminated) return;
    final clamped = progress == null
        ? null
        : progress < 0.0
        ? 0.0
        : progress > 1.0
        ? 1.0
        : progress;
    _service.updateProgress(
      id: id,
      message: message,
      progress: clamped,
      clearProgress: false,
    );
  }

  /// Terminate successfully.
  ///
  /// If [successMessage] is supplied, the progress card converts to a
  /// `success` notification (subject to the standard 6-second
  /// auto-dismiss). Otherwise the card is dismissed immediately.
  ///
  /// Idempotent — subsequent calls are silent no-ops.
  void complete({String? successMessage}) {
    if (_terminated) return;
    _terminated = true;
    if (successMessage == null) {
      _service.dismiss(id);
    } else {
      _service.replaceSeverity(
        id: id,
        severity: NotificationSeverity.success,
        message: successMessage,
      );
    }
    _resolveCancellation();
  }

  /// Terminate with failure.
  ///
  /// Converts the progress card to a persistent `error` notification
  /// carrying [errorMessage] so the failure isn't silently lost.
  ///
  /// Idempotent — subsequent calls are silent no-ops.
  void fail(String errorMessage) {
    if (_terminated) return;
    _terminated = true;
    _service.replaceSeverity(
      id: id,
      severity: NotificationSeverity.error,
      message: errorMessage,
    );
    _resolveCancellation();
  }

  /// Operator-initiated cancel. Resolves [cancellation]; the host
  /// then observes that future and tears down its work, eventually
  /// calling [complete] or [fail] to terminate the controller.
  ///
  /// No-op on a non-cancellable controller (the cancel affordance is
  /// hidden in that case, so this is mainly defensive).
  void cancel() {
    if (!_cancellable) return;
    _resolveCancellation();
  }

  /// Called by the service when the underlying notification is
  /// dismissed externally (e.g. operator closed the card, host called
  /// `service.dismiss(id)` directly). Forces the controller into a
  /// terminated state so subsequent host calls become silent no-ops.
  void onExternalDismiss() {
    if (_terminated) return;
    _terminated = true;
    _resolveCancellation();
  }

  void _resolveCancellation() {
    if (_cancellation.isCompleted) return;
    _cancellation.complete();
  }
}

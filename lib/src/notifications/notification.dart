import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Severity for a [Notification].
///
/// Drives the card's icon, accent colour, and dismissal policy. Info
/// and success auto-dismiss after a short interval; warning and error
/// persist until the operator dismisses them (SPEC §10).
enum NotificationSeverity {
  /// Neutral informational notice. Auto-dismisses.
  info,

  /// Positive completion notice (e.g. file saved). Auto-dismisses.
  success,

  /// Recoverable issue the operator should see. Persists until
  /// dismissed.
  warning,

  /// Failure condition the operator must acknowledge. Persists until
  /// dismissed.
  error,
}

/// Convenience predicate for the persistence rule (SPEC §10
/// "Dismissal policy by severity"). Warning and error cards stay
/// until the operator dismisses them; info and success auto-dismiss.
extension NotificationSeverityPersistence on NotificationSeverity {
  /// Whether this severity persists until manually dismissed.
  bool get persists =>
      this == NotificationSeverity.warning ||
      this == NotificationSeverity.error;
}

/// A button rendered inside a notification card.
///
/// Tapping the action runs [onInvoke] and dismisses the card in the
/// same frame (SPEC §10 "Action invocation"). Hosts that need to keep
/// state visible after an action runs post a follow-up notification
/// from inside [onInvoke].
class NotificationAction extends Equatable {
  /// Button label. The host supplies natural case; the host widget
  /// renders the label as-is (action buttons are not subject to the
  /// uppercase tab/section convention).
  final String label;

  /// Callback invoked when the operator taps the action.
  final VoidCallback onInvoke;

  const NotificationAction({required this.label, required this.onInvoke});

  @override
  List<Object?> get props => [label, onInvoke];
}

/// A live notification managed by [NotificationService].
///
/// Identity is the opaque [id] minted by the service; hosts use it to
/// dismiss programmatically. Cards never mutate after creation — a
/// host that wants to update a message posts a new notification (the
/// progress card API, defined in a later workstream, supplies the
/// mutable surface).
///
/// Named `WorkbenchNotification` rather than `Notification` to avoid
/// colliding with Flutter's framework `Notification` class (the
/// ancestor for `NotificationListener` bubbling). Consumers importing
/// both `package:flutter/widgets.dart` and
/// `package:workbench_shell/workbench_shell.dart` would otherwise hit
/// an ambiguous-import error.
@immutable
class WorkbenchNotification extends Equatable {
  /// Opaque identifier minted by [NotificationService.show]. Stable
  /// for the lifetime of the card.
  final Object id;

  /// Severity tier. Drives icon, accent, and auto-dismiss policy.
  final NotificationSeverity severity;

  /// Operator-facing message. Plain text; the host widget owns
  /// rendering and wrapping.
  final String message;

  /// Action buttons rendered at the bottom of the card. Empty by
  /// default; the host omits the action row entirely when empty.
  final List<NotificationAction> actions;

  /// Wall-clock instant the card was created. Used by the host
  /// widget for stable ordering (newest at the bottom of the stack).
  final DateTime createdAt;

  const WorkbenchNotification({
    required this.id,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.actions = const [],
  });

  @override
  List<Object?> get props => [id, severity, message, actions, createdAt];
}

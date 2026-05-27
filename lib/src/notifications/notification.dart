import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Severity for a [Notification].
///
/// Drives the card's icon, accent colour, and dismissal policy. Info
/// and success auto-dismiss after a short interval; warning, error,
/// and in-flight progress cards persist until manually or
/// programmatically dismissed (SPEC §10).
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

  /// In-flight task tracked by a [NotificationProgressController].
  /// Persists until the host's `complete` or `fail` call resolves it.
  progress,
}

/// Convenience predicate for the persistence rule (SPEC §10
/// "Dismissal policy by severity"). Warning, error, and progress
/// cards stay until manually or programmatically dismissed; info and
/// success auto-dismiss.
extension NotificationSeverityPersistence on NotificationSeverity {
  /// Whether this severity persists until manually dismissed.
  bool get persists =>
      this == NotificationSeverity.warning ||
      this == NotificationSeverity.error ||
      this == NotificationSeverity.progress;
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
/// dismiss programmatically. Most cards never mutate after creation —
/// a host that wants to update a message posts a new notification.
/// Progress cards are the exception: `report`, `complete`, and `fail`
/// on a [NotificationProgressController] replace the live card under
/// the same [id] in place so the host widget can update without
/// re-stacking.
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

  /// Progress value in `[0.0, 1.0]` for a determinate progress
  /// notification, or `null` for indeterminate (spinner). Always
  /// `null` for non-`progress` severities.
  final double? progress;

  /// Whether a `progress` notification renders a cancel affordance.
  /// Always `false` for non-`progress` severities.
  final bool cancellable;

  const WorkbenchNotification({
    required this.id,
    required this.severity,
    required this.message,
    required this.createdAt,
    this.actions = const [],
    this.progress,
    this.cancellable = false,
  });

  /// Return a copy with selected fields replaced. Used by the
  /// progress controller to mutate the live card in place without
  /// breaking the immutable value contract.
  WorkbenchNotification copyWith({
    NotificationSeverity? severity,
    String? message,
    List<NotificationAction>? actions,
    Object? progress = _sentinel,
    bool? cancellable,
  }) {
    return WorkbenchNotification(
      id: id,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      actions: actions ?? this.actions,
      createdAt: createdAt,
      progress: identical(progress, _sentinel)
          ? this.progress
          : progress as double?,
      cancellable: cancellable ?? this.cancellable,
    );
  }

  @override
  List<Object?> get props => [
    id,
    severity,
    message,
    actions,
    createdAt,
    progress,
    cancellable,
  ];
}

/// Sentinel so [WorkbenchNotification.copyWith] can distinguish
/// "leave progress unchanged" from "clear progress to null".
const Object _sentinel = Object();

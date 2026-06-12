import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../layout_constants.dart';
import '../workbench_theme.dart';
import 'notification.dart';
import 'notification_service.dart';

/// Overlay anchored to the bottom-right of the workbench that
/// renders the stacked toast cards owned by [NotificationService].
///
/// Hosts mount this widget once inside `WorkbenchLayout` (typically
/// wrapped around the editor or layout so it covers the workbench
/// surfaces). The widget subscribes to [service] and rebuilds on
/// change.
///
/// Behaviour summary (SPEC §spec:notification-center):
///
/// - Cards render newest-at-bottom.
/// - Info/success auto-dismiss after 6 s of uninterrupted
///   non-hover, window-focused time. Hovering pauses the timer; the
///   window losing focus pauses it (`AppLifecycleState.inactive` or
///   `paused`); resuming focus / leaving the hover resumes it from
///   the remaining duration.
/// - Warning and error persist until manually dismissed.
/// - When two or more cards are present, a "Clear All" control
///   appears above the stack.
/// - When more than [WorkbenchLayoutConstants.notificationMaxVisible]
///   cards would render simultaneously, the oldest non-persistent
///   cards collapse into a "+N more" summary card occupying the top
///   slot. Tapping the summary expands the hidden cards into a
///   scrollable list. Persistent cards fill the visible slots first.
class NotificationHost extends StatefulWidget {
  /// Service whose notifications this host renders.
  final NotificationService service;

  /// Optional [child] rendered beneath the notification overlay.
  /// Typically the workbench layout itself.
  final Widget? child;

  /// Pixels reserved at the bottom edge before the card stack begins.
  /// Callers that wrap the host around content containing a status bar
  /// (e.g. a workbench layout) should pass the status bar's height so
  /// cards float above it instead of occluding it. Stacks with the
  /// standard [WorkbenchLayoutConstants.notificationStackInset] applied
  /// on top of this reservation.
  final double bottomInset;

  const NotificationHost({
    super.key,
    required this.service,
    this.child,
    this.bottomInset = 0,
  });

  @override
  State<NotificationHost> createState() => _NotificationHostState();
}

class _NotificationHostState extends State<NotificationHost>
    with WidgetsBindingObserver {
  /// Per-notification timer state. Keyed by notification id.
  final Map<Object, _AutoDismissTimer> _timers = {};

  /// Whether the host window is currently focused. Drives the
  /// window-focus pause behaviour for auto-dismiss timers.
  bool _windowFocused = true;

  /// Whether the +N more summary is expanded.
  bool _summaryExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _windowFocused = _isFocusedLifecycle(
      WidgetsBinding.instance.lifecycleState,
    );
    widget.service.addListener(_handleServiceChanged);
    _syncTimers();
  }

  @override
  void didUpdateWidget(covariant NotificationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      oldWidget.service.removeListener(_handleServiceChanged);
      widget.service.addListener(_handleServiceChanged);
      for (final timer in _timers.values) {
        timer.dispose();
      }
      _timers.clear();
      _syncTimers();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.service.removeListener(_handleServiceChanged);
    for (final timer in _timers.values) {
      timer.dispose();
    }
    _timers.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final focused = _isFocusedLifecycle(state);
    if (focused == _windowFocused) return;
    _windowFocused = focused;
    for (final timer in _timers.values) {
      timer.windowFocused = focused;
    }
  }

  /// `AppLifecycleState.inactive` and `AppLifecycleState.paused`
  /// indicate the host window is no longer foregrounded. `resumed`
  /// brings us back; `hidden` and `detached` are treated as
  /// unfocused so timers don't tick on a backgrounded app.
  static bool _isFocusedLifecycle(AppLifecycleState? state) {
    if (state == null) return true;
    return state == AppLifecycleState.resumed;
  }

  void _handleServiceChanged() {
    setState(() {
      _syncTimers();
      if (widget.service.notifications.isEmpty) {
        _summaryExpanded = false;
      }
    });
  }

  /// Reconcile [_timers] with the current notification set. New
  /// non-persistent notifications get a timer; removed notifications
  /// drop theirs.
  void _syncTimers() {
    final liveIds = <Object>{};
    for (final notification in widget.service.notifications) {
      liveIds.add(notification.id);
      if (notification.severity.persists) continue;
      _timers.putIfAbsent(notification.id, () {
        final timer = _AutoDismissTimer(
          duration: WorkbenchLayoutConstants.notificationAutoDismissDuration,
          onExpired: () => widget.service.dismiss(notification.id),
        );
        timer.windowFocused = _windowFocused;
        timer.start();
        return timer;
      });
    }
    final stale = _timers.keys.where((id) => !liveIds.contains(id)).toList();
    for (final id in stale) {
      _timers.remove(id)?.dispose();
    }
  }

  void _setHovered(Object id, bool hovered) {
    final timer = _timers[id];
    if (timer == null) return;
    timer.hovered = hovered;
  }

  /// Partition the notification list into visible and overflow
  /// according to SPEC §spec:notification-center: persistent cards (warning, error) fill
  /// the visible slots first; the oldest non-persistent cards
  /// overflow into the summary.
  _PartitionedNotifications _partition(List<WorkbenchNotification> all) {
    final budget = WorkbenchLayoutConstants.notificationMaxVisible;
    if (all.length <= budget) {
      return _PartitionedNotifications(visible: all, overflow: const []);
    }
    // Walk newest-first, keeping every persistent card and as many
    // transient cards as fit in the remaining slots. Everything
    // dropped becomes overflow.
    final reversed = all.reversed.toList();
    final keptReversed = <WorkbenchNotification>[];
    final overflow = <WorkbenchNotification>[];
    for (final n in reversed) {
      if (keptReversed.length < budget) {
        keptReversed.add(n);
      } else if (n.severity.persists) {
        // Persistent card cannot overflow; evict the oldest transient
        // card from kept and push it into overflow instead.
        final evictIndex = keptReversed.lastIndexWhere(
          (k) => !k.severity.persists,
        );
        if (evictIndex == -1) {
          // No transient to evict — pathological case where there
          // are more persistent cards than slots. Render all of them
          // anyway (operator must dismiss); the overflow stays
          // empty.
          keptReversed.add(n);
        } else {
          overflow.add(keptReversed.removeAt(evictIndex));
          keptReversed.add(n);
        }
      } else {
        overflow.add(n);
      }
    }
    return _PartitionedNotifications(
      visible: keptReversed.reversed.toList(),
      overflow: overflow,
    );
  }

  void _toggleSummary() {
    setState(() {
      _summaryExpanded = !_summaryExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifications = widget.service.notifications;
    final partition = _partition(notifications);
    final overlay = _NotificationOverlay(
      service: widget.service,
      visible: partition.visible,
      overflow: partition.overflow,
      summaryExpanded: _summaryExpanded,
      onToggleSummary: _toggleSummary,
      onHoverChanged: _setHovered,
    );
    return Stack(
      children: [
        if (widget.child != null) Positioned.fill(child: widget.child!),
        Positioned(
          right: WorkbenchLayoutConstants.notificationStackInset,
          bottom:
              widget.bottomInset +
              WorkbenchLayoutConstants.notificationStackInset,
          child: overlay,
        ),
      ],
    );
  }
}

/// Auto-dismiss timer with hover-pause and window-focus-pause.
///
/// Tracks remaining duration so a resume after a pause continues
/// from where it left off rather than restarting. The expiration
/// callback fires at most once.
class _AutoDismissTimer {
  final Duration duration;
  final VoidCallback onExpired;

  Duration _remaining;
  DateTime? _resumedAt;
  Timer? _timer;
  bool _expired = false;
  bool _hovered = false;
  bool _windowFocused = true;

  _AutoDismissTimer({required this.duration, required this.onExpired})
    : _remaining = duration;

  bool get hovered => _hovered;
  set hovered(bool value) {
    if (_hovered == value) return;
    _hovered = value;
    _refresh();
  }

  bool get windowFocused => _windowFocused;
  set windowFocused(bool value) {
    if (_windowFocused == value) return;
    _windowFocused = value;
    _refresh();
  }

  /// Whether the timer is currently counting down.
  bool get isRunning => _timer != null;

  /// Remaining duration. Snapshot — does not tick.
  Duration get remaining {
    if (_resumedAt == null) return _remaining;
    final elapsed = DateTime.now().difference(_resumedAt!);
    final left = _remaining - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  void start() {
    if (_expired) return;
    _refresh();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _resumedAt = null;
  }

  void _refresh() {
    if (_expired) return;
    if (_hovered || !_windowFocused) {
      _pause();
    } else {
      _resume();
    }
  }

  void _pause() {
    if (_resumedAt != null) {
      final elapsed = DateTime.now().difference(_resumedAt!);
      _remaining -= elapsed;
      if (_remaining.isNegative) _remaining = Duration.zero;
    }
    _timer?.cancel();
    _timer = null;
    _resumedAt = null;
  }

  void _resume() {
    if (_timer != null) return;
    if (_remaining <= Duration.zero) {
      _fire();
      return;
    }
    _resumedAt = DateTime.now();
    _timer = Timer(_remaining, _fire);
  }

  void _fire() {
    if (_expired) return;
    _expired = true;
    _timer?.cancel();
    _timer = null;
    _resumedAt = null;
    // Defer so the dismiss happens off the timer callback —
    // notifyListeners during widget build is unsafe.
    SchedulerBinding.instance.scheduleTask(onExpired, Priority.animation);
  }
}

class _PartitionedNotifications {
  final List<WorkbenchNotification> visible;
  final List<WorkbenchNotification> overflow;
  const _PartitionedNotifications({
    required this.visible,
    required this.overflow,
  });
}

/// Layout for the bottom-right notification stack. Owns the Clear
/// All control, the +N more summary, and the card column.
class _NotificationOverlay extends StatelessWidget {
  final NotificationService service;
  final List<WorkbenchNotification> visible;
  final List<WorkbenchNotification> overflow;
  final bool summaryExpanded;
  final VoidCallback onToggleSummary;
  final void Function(Object id, bool hovered) onHoverChanged;

  const _NotificationOverlay({
    required this.service,
    required this.visible,
    required this.overflow,
    required this.summaryExpanded,
    required this.onToggleSummary,
    required this.onHoverChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (visible.isEmpty && overflow.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = context.workbenchTheme;
    final totalCount = visible.length + overflow.length;
    final cardWidth = WorkbenchLayoutConstants.notificationCardWidth;
    return SizedBox(
      width: cardWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (totalCount >= 2)
            _ClearAllControl(
              count: totalCount,
              theme: theme,
              onClear: service.clear,
            ),
          if (totalCount >= 2)
            const SizedBox(
              height: WorkbenchLayoutConstants.notificationStackGap,
            ),
          if (overflow.isNotEmpty) ...[
            _SummaryCard(
              hiddenCount: overflow.length,
              expanded: summaryExpanded,
              theme: theme,
              onTap: onToggleSummary,
              overflow: overflow,
              service: service,
            ),
            const SizedBox(
              height: WorkbenchLayoutConstants.notificationStackGap,
            ),
          ],
          for (var i = 0; i < visible.length; i++) ...[
            _NotificationCard(
              notification: visible[i],
              theme: theme,
              onDismiss: () => service.dismiss(visible[i].id),
              onHoverChanged: (h) => onHoverChanged(visible[i].id, h),
              onCancelProgress: visible[i].cancellable
                  ? () => service.progressControllerFor(visible[i].id)?.cancel()
                  : null,
            ),
            if (i != visible.length - 1)
              const SizedBox(
                height: WorkbenchLayoutConstants.notificationStackGap,
              ),
          ],
        ],
      ),
    );
  }
}

/// Small "Clear All" pill above the stack. Visible when at least two
/// notifications (visible or overflow) are present.
class _ClearAllControl extends StatelessWidget {
  final int count;
  final WorkbenchTheme theme;
  final VoidCallback onClear;

  const _ClearAllControl({
    required this.count,
    required this.theme,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onClear,
          borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchLayoutConstants.spacingSm,
              vertical: WorkbenchLayoutConstants.spacingXs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Symbols.clear_all_rounded,
                  size: WorkbenchLayoutConstants.iconSm,
                  color: theme.notificationCloseForeground,
                ),
                const SizedBox(width: WorkbenchLayoutConstants.spacingXs),
                Text(
                  'Clear All',
                  style: theme.captionText.copyWith(
                    color: theme.notificationCloseForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Summary card at the top of the stack when overflow cards exist.
/// Tap to expand into a scrollable list.
class _SummaryCard extends StatelessWidget {
  final int hiddenCount;
  final bool expanded;
  final WorkbenchTheme theme;
  final VoidCallback onTap;
  final List<WorkbenchNotification> overflow;
  final NotificationService service;

  const _SummaryCard({
    required this.hiddenCount,
    required this.expanded,
    required this.theme,
    required this.onTap,
    required this.overflow,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    final caret = expanded
        ? Symbols.expand_less_rounded
        : Symbols.expand_more_rounded;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.notificationBackground,
        borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
        border: Border.all(color: theme.notificationBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: WorkbenchLayoutConstants.spacingMd,
                  vertical: WorkbenchLayoutConstants.spacingSm,
                ),
                child: Row(
                  children: [
                    Icon(
                      caret,
                      size: WorkbenchLayoutConstants.iconMd,
                      color: theme.notificationCloseForeground,
                    ),
                    const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
                    Expanded(
                      child: Text(
                        '+$hiddenCount more',
                        style: theme.bodyText.copyWith(
                          color: theme.notificationForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: WorkbenchLayoutConstants.spacingSm,
                  vertical: WorkbenchLayoutConstants.spacingSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < overflow.length; i++) ...[
                      _NotificationCard(
                        notification: overflow[i],
                        theme: theme,
                        onDismiss: () => service.dismiss(overflow[i].id),
                        onHoverChanged: (_) {
                          // Overflow cards inside the summary do not
                          // run timers — they are already past the
                          // visible budget. Hover-pause is irrelevant.
                        },
                        onCancelProgress: overflow[i].cancellable
                            ? () => service
                                  .progressControllerFor(overflow[i].id)
                                  ?.cancel()
                            : null,
                      ),
                      if (i != overflow.length - 1)
                        const SizedBox(
                          height: WorkbenchLayoutConstants.notificationStackGap,
                        ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single notification card. Renders the severity icon, message,
/// optional actions, and a close button. Tracks pointer hover so
/// the host can pause the auto-dismiss timer.
class _NotificationCard extends StatelessWidget {
  final WorkbenchNotification notification;
  final WorkbenchTheme theme;
  final VoidCallback onDismiss;
  final ValueChanged<bool> onHoverChanged;

  /// Invoked when the operator presses the progress card's cancel
  /// affordance. Null disables the affordance (non-progress cards or
  /// non-cancellable progress).
  final VoidCallback? onCancelProgress;

  const _NotificationCard({
    required this.notification,
    required this.theme,
    required this.onDismiss,
    required this.onHoverChanged,
    this.onCancelProgress,
  });

  IconData _iconFor(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return Symbols.info_rounded;
      case NotificationSeverity.success:
        return Symbols.check_circle_rounded;
      case NotificationSeverity.warning:
        return Symbols.warning_rounded;
      case NotificationSeverity.error:
        return Symbols.error_rounded;
      case NotificationSeverity.progress:
        // Progress cards render the indicator (determinate bar or
        // indeterminate spinner) inside the card body; the header
        // icon doubles as a "working" affordance.
        return Symbols.sync_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = theme.severityForeground(notification.severity);
    // Severity accent renders as a leading stripe positioned inside
    // the rounded card. Flutter forbids mixing a non-uniform Border
    // with borderRadius, so the stripe is a sibling Positioned widget
    // rather than a fourth BorderSide.
    //
    // Material ancestor: the card lives inside an Overlay-style Stack
    // with no Material in the parent chain, so descendant Text widgets
    // would render with the debug "missing default text style" yellow
    // double-underline. A transparent Material restores DefaultTextStyle
    // without contributing its own visual chrome.
    return Material(
      type: MaterialType.transparency,
      child: MouseRegion(
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: ClipRRect(
          borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.notificationBackground,
              borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
              border: Border.all(color: theme.notificationBorder),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Severity accent stripe — fills the card's full height
                  // even though the content column drives the intrinsic
                  // size.
                  SizedBox(width: 3, child: ColoredBox(color: severityColor)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        WorkbenchLayoutConstants.spacingMd,
                        WorkbenchLayoutConstants.spacingSm,
                        WorkbenchLayoutConstants.spacingSm,
                        WorkbenchLayoutConstants.spacingSm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _iconFor(notification.severity),
                                color: severityColor,
                                size: WorkbenchLayoutConstants.iconMd,
                              ),
                              const SizedBox(
                                width: WorkbenchLayoutConstants.spacingSm,
                              ),
                              Expanded(
                                child: Padding(
                                  // Match the icon's optical baseline so
                                  // the message text sits next to the
                                  // glyph rather than against the top of
                                  // the icon box.
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(
                                    notification.message,
                                    style: theme.bodyText.copyWith(
                                      color: theme.notificationForeground,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: WorkbenchLayoutConstants.spacingSm,
                              ),
                              _CloseButton(
                                color: theme.notificationCloseForeground,
                                onTap: onDismiss,
                              ),
                            ],
                          ),
                          if (notification.severity ==
                              NotificationSeverity.progress) ...[
                            const SizedBox(
                              height: WorkbenchLayoutConstants.spacingSm,
                            ),
                            _ProgressIndicatorRow(
                              value: notification.progress,
                              theme: theme,
                            ),
                            if (onCancelProgress != null) ...[
                              const SizedBox(
                                height: WorkbenchLayoutConstants.spacingSm,
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _ActionButton(
                                  action: NotificationAction(
                                    label: 'Cancel',
                                    onInvoke: onCancelProgress!,
                                  ),
                                  theme: theme,
                                  // Cancel must not dismiss the card —
                                  // the host owns the terminal transition
                                  // via complete()/fail(). Invoke the
                                  // host callback only.
                                  onInvoke: onCancelProgress!,
                                ),
                              ),
                            ],
                          ],
                          if (notification.actions.isNotEmpty) ...[
                            const SizedBox(
                              height: WorkbenchLayoutConstants.spacingSm,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                spacing: WorkbenchLayoutConstants.spacingSm,
                                runSpacing: WorkbenchLayoutConstants.spacingXs,
                                children: [
                                  for (final action in notification.actions)
                                    _ActionButton(
                                      action: action,
                                      theme: theme,
                                      onInvoke: () {
                                        // Run host callback first, then
                                        // dismiss synchronously in the
                                        // same frame so the operator
                                        // sees the card vanish as the
                                        // action completes (SPEC §spec:notification-center).
                                        action.onInvoke();
                                        onDismiss();
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _CloseButton({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            Symbols.close_rounded,
            size: WorkbenchLayoutConstants.iconSm,
            color: color,
            semanticLabel: 'Dismiss notification',
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final NotificationAction action;
  final WorkbenchTheme theme;
  final VoidCallback onInvoke;
  const _ActionButton({
    required this.action,
    required this.theme,
    required this.onInvoke,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.notificationActionBackground,
      borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
      child: InkWell(
        onTap: onInvoke,
        borderRadius: WorkbenchLayoutConstants.notificationCardRadius,
        hoverColor: theme.notificationActionHoverBackground,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: WorkbenchLayoutConstants.spacingMd,
            vertical: WorkbenchLayoutConstants.spacingXs,
          ),
          child: Text(
            action.label,
            style: theme.buttonTextStyle.copyWith(
              color: theme.notificationActionForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress indicator inside a `NotificationSeverity.progress` card.
/// Renders a [LinearProgressIndicator] driven by [value] — determinate
/// when [value] is non-null, indeterminate otherwise. Theme tokens
/// come from `notificationProgressTrack`/`notificationProgressFill`
/// so the indicator stays consistent with workbench progress chrome.
class _ProgressIndicatorRow extends StatelessWidget {
  final double? value;
  final WorkbenchTheme theme;

  const _ProgressIndicatorRow({required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        WorkbenchLayoutConstants.notificationProgressBarHeight / 2,
      ),
      child: SizedBox(
        height: WorkbenchLayoutConstants.notificationProgressBarHeight,
        child: LinearProgressIndicator(
          value: value,
          minHeight: WorkbenchLayoutConstants.notificationProgressBarHeight,
          backgroundColor: theme.notificationProgressTrack,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.notificationProgressFill,
          ),
        ),
      ),
    );
  }
}

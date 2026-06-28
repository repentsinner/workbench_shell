import 'package:flutter/material.dart';

import 'layout_constants.dart';
import 'workbench_theme.dart';

/// Canonical resize sash for the workbench's resizable seams — the sidebar
/// width, the bottom-panel height, and the view-stack pane boundaries
/// (§spec:workbench-layout, §spec:view-stack). Drives a single [value] between
/// [min] and [max] with VS Code-aligned behavior, so every seam feels the same:
///
/// - **Absolute-anchored drag**: the value tracks the pointer's offset from
///   where the drag began, not an accumulated per-event delta. Overshooting a
///   clamp therefore parks the sash at the limit and it re-tracks the cursor
///   with no offset once the pointer returns — a delta-accumulating drag would
///   discard the overshoot and trail the cursor by it.
/// - **Directional cursor**: bidirectional while the sash can move both ways, a
///   single-direction arrow at each limit. [axis] and [growSign] decide which
///   way (VS Code's `ns-resize`/`ew-resize` and the `minimum`/`maximum` states).
/// - **Drag-time cursor overlay**: while dragging, a full-window overlay carries
///   the cursor so it stays correct when the pointer overshoots off the thin
///   sash strip. The gesture is already captured, so the overlay only paints
///   the cursor.
/// - **Two-level highlight**: the sash paints `WorkbenchTheme.sashHoverBorder`
///   over its strip — a subtler tint on hover, the full color while dragging.
///   VS Code uses one `sash.hoverBorder` color for both states (hover after a
///   delay, active immediately); the hover/drag opacity split gives that
///   two-level feel.
///
/// Internal — not exported. Shared by `WorkbenchLayout`'s resizers and the
/// view-stack pane sashes.
class WorkbenchSash extends StatefulWidget {
  const WorkbenchSash({
    super.key,
    required this.axis,
    required this.growSign,
    required this.onChanged,
    required this.child,
    this.value = 0,
    this.min = 0,
    this.max = 1,
    this.resolveBasis,
    this.hoverCursor,
    this.onChangeEnd,
    this.onReset,
  });

  /// The drag axis. [Axis.horizontal] resizes a width (the sidebar);
  /// [Axis.vertical] resizes a height (the panel).
  final Axis axis;

  /// Current size and bounds for a *prop-driven* sash (the sidebar/panel, whose
  /// value is stored state). A *derived* sash (the view stack, whose value comes
  /// from live layout) supplies [resolveBasis] instead and may leave these at
  /// their defaults.
  final double value;
  final double min;
  final double max;

  /// Resolves the drag basis — the value and its bounds — at drag start, from
  /// live geometry. When non-null it overrides [value]/[min]/[max] for the
  /// drag, so the drag seeds from on-screen sizes rather than a build snapshot
  /// (the view stack reads its pane heights here).
  final ({double value, double min, double max}) Function()? resolveBasis;

  /// Static hover cursor for the strip. When null it is computed from
  /// [value]/[min]/[max]; a derived sash supplies it (it knows its at-limit
  /// state from stored sizes). The drag cursor is always computed from the live
  /// drag against the basis.
  final MouseCursor? hoverCursor;

  /// Sign mapping pointer movement to the value: `+1` when increasing the
  /// pointer coordinate (moving right / down) grows it, `-1` when it shrinks it.
  /// Also orients the directional cursor toward the side with room.
  final double growSign;

  /// Called with the new clamped value during a drag.
  final ValueChanged<double> onChanged;

  /// Notified once when a drag ends, with the final clamped value
  /// (§spec:resize-geometry). The seam's owner commits this for persistence;
  /// per-frame [onChanged] drives the live resize, this fires only on release.
  final ValueChanged<double>? onChangeEnd;

  /// Called on a double-click of the strip — the canonical "reset this seam to
  /// its default" gesture (VS Code's `onDidSashReset`, e.g. the centered-layout
  /// margins snapping back to the golden ratio). Null leaves double-click inert.
  final VoidCallback? onReset;

  /// The visible sash strip (hairline, hit target).
  final Widget child;

  @override
  State<WorkbenchSash> createState() => _WorkbenchSashState();
}

class _WorkbenchSashState extends State<WorkbenchSash> {
  double _startValue = 0;
  double _startPointer = 0;
  double _startMin = 0;
  double _startMax = 1;
  double? _lastEmitted;
  bool _hovering = false;
  bool _dragging = false;
  OverlayEntry? _overlay;
  final ValueNotifier<MouseCursor> _overlayCursor = ValueNotifier(
    SystemMouseCursors.basic,
  );

  double _axisPos(Offset global) =>
      widget.axis == Axis.horizontal ? global.dx : global.dy;

  /// Cursor for [value] against [min]/[max]: at [min] the value can only grow
  /// and at [max] only shrink, so the arrow points the way with room; otherwise
  /// bidirectional. Mirrors VS Code's sash cursors (ew/ns-resize free;
  /// e/w- or n/s-resize at the limits).
  MouseCursor _cursorFor(double value, double min, double max) {
    final atMin = value <= min;
    final atMax = value >= max;
    if (widget.axis == Axis.horizontal) {
      final grow = widget.growSign >= 0
          ? SystemMouseCursors.resizeRight
          : SystemMouseCursors.resizeLeft;
      final shrink = widget.growSign >= 0
          ? SystemMouseCursors.resizeLeft
          : SystemMouseCursors.resizeRight;
      if (atMin) return grow;
      if (atMax) return shrink;
      return SystemMouseCursors.resizeLeftRight;
    }
    final grow = widget.growSign >= 0
        ? SystemMouseCursors.resizeDown
        : SystemMouseCursors.resizeUp;
    final shrink = widget.growSign >= 0
        ? SystemMouseCursors.resizeUp
        : SystemMouseCursors.resizeDown;
    if (atMin) return grow;
    if (atMax) return shrink;
    return SystemMouseCursors.resizeUpDown;
  }

  void _onStart(DragStartDetails d) {
    final basis = widget.resolveBasis?.call();
    _startValue = basis?.value ?? widget.value;
    _startMin = basis?.min ?? widget.min;
    _startMax = basis?.max ?? widget.max;
    _lastEmitted = _startValue;
    _startPointer = _axisPos(d.globalPosition);
    _overlayCursor.value = _cursorFor(_startValue, _startMin, _startMax);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay != null) {
      _overlay = OverlayEntry(
        builder: (_) => Positioned.fill(
          child: ValueListenableBuilder<MouseCursor>(
            valueListenable: _overlayCursor,
            builder: (_, cursor, _) => MouseRegion(cursor: cursor),
          ),
        ),
      );
      overlay.insert(_overlay!);
    }
    setState(() => _dragging = true);
  }

  void _onUpdate(DragUpdateDetails d) {
    final offset = _axisPos(d.globalPosition) - _startPointer;
    final next = (_startValue + widget.growSign * offset).clamp(
      _startMin,
      _startMax,
    );
    _overlayCursor.value = _cursorFor(next, _startMin, _startMax);
    if (next != _lastEmitted) {
      _lastEmitted = next;
      widget.onChanged(next);
    }
  }

  void _onEnd() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() => _dragging = false);
    // Surface the final clamped value once on release (§spec:resize-geometry).
    // The seam's owner commits it for persistence; per-frame onChanged already
    // drove the live resize. _lastEmitted is seeded at drag start, so it is
    // non-null here.
    final last = _lastEmitted;
    if (last != null) widget.onChangeEnd?.call(last);
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlayCursor.dispose();
    super.dispose();
  }

  /// The hover/drag highlight: a centered band of
  /// [WorkbenchLayoutConstants.sashHoverSize] along the boundary, full color
  /// while dragging and half-alpha on hover (VS Code's `sash.hoverBorder`).
  /// Null when the seam is idle or the theme suppresses the color.
  Widget? _highlight(BuildContext context) {
    if (!_hovering && !_dragging) return null;
    final base = Theme.of(context).extension<WorkbenchTheme>()?.sashHoverBorder;
    if (base == null) return null;
    final color = _dragging ? base : base.withValues(alpha: base.a * 0.5);
    const band = WorkbenchLayoutConstants.sashHoverSize;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          child: SizedBox(
            width: widget.axis == Axis.horizontal ? band : double.infinity,
            height: widget.axis == Axis.horizontal ? double.infinity : band,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _highlight(context);
    final strip = MouseRegion(
      cursor:
          widget.hoverCursor ??
          _cursorFor(widget.value, widget.min, widget.max),
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onStart,
        onPanUpdate: _onUpdate,
        onPanEnd: (_) => _onEnd(),
        onPanCancel: _onEnd,
        onDoubleTap: widget.onReset,
        child: highlight == null
            ? widget.child
            : Stack(children: [widget.child, highlight]),
      ),
    );
    // The sash owns its cross-axis thickness so call sites can't pick an
    // arbitrary width — every seam is the canonical sash size
    // (§spec:workbench-layout). The main axis fills the boundary it sits on.
    const size = WorkbenchLayoutConstants.sashSize;
    return SizedBox(
      width: widget.axis == Axis.horizontal ? size : null,
      height: widget.axis == Axis.horizontal ? null : size,
      child: strip,
    );
  }
}

import 'package:flutter/material.dart';

/// Canonical resize sash for the workbench's resizable seams — the sidebar
/// width and the bottom-panel height. Drives a single [value] between [min]
/// and [max] with VS Code-aligned behavior, so every seam feels the same:
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
///
/// Internal — not exported. Shared by `WorkbenchLayout`'s resizers.
class WorkbenchSash extends StatefulWidget {
  const WorkbenchSash({
    super.key,
    required this.axis,
    required this.value,
    required this.min,
    required this.max,
    required this.growSign,
    required this.onChanged,
    required this.child,
    this.onDragChanged,
  });

  /// The drag axis. [Axis.horizontal] resizes a width (the sidebar);
  /// [Axis.vertical] resizes a height (the panel).
  final Axis axis;

  /// Current size the sash drives.
  final double value;
  final double min;
  final double max;

  /// Sign mapping pointer movement to [value]: `+1` when increasing the pointer
  /// coordinate (moving right / down) grows the value, `-1` when it shrinks it.
  /// Also orients the directional cursor toward the side with room.
  final double growSign;

  /// Called with the new clamped [value] during a drag.
  final ValueChanged<double> onChanged;

  /// Notified when a drag begins (`true`) and ends (`false`) — lets the host
  /// paint a drag/hover background on [child].
  final ValueChanged<bool>? onDragChanged;

  /// The visible sash strip (hairline, hit target, drag background).
  final Widget child;

  @override
  State<WorkbenchSash> createState() => _WorkbenchSashState();
}

class _WorkbenchSashState extends State<WorkbenchSash> {
  double _startValue = 0;
  double _startPointer = 0;
  OverlayEntry? _overlay;
  final ValueNotifier<MouseCursor> _overlayCursor = ValueNotifier(
    SystemMouseCursors.basic,
  );

  double _axisPos(Offset global) =>
      widget.axis == Axis.horizontal ? global.dx : global.dy;

  /// Cursor for [value] given the clamp state: at [min] the value can only grow
  /// and at [max] only shrink, so the arrow points the way with room; otherwise
  /// bidirectional. Mirrors VS Code's sash cursors (ew/ns-resize free;
  /// e/w- or n/s-resize at the limits).
  MouseCursor _cursorFor(double value) {
    final atMin = value <= widget.min;
    final atMax = value >= widget.max;
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
    _startValue = widget.value;
    _startPointer = _axisPos(d.globalPosition);
    _overlayCursor.value = _cursorFor(widget.value);
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
    widget.onDragChanged?.call(true);
  }

  void _onUpdate(DragUpdateDetails d) {
    final offset = _axisPos(d.globalPosition) - _startPointer;
    final next = (_startValue + widget.growSign * offset).clamp(
      widget.min,
      widget.max,
    );
    _overlayCursor.value = _cursorFor(next);
    if (next != widget.value) widget.onChanged(next);
  }

  void _onEnd() {
    _overlay?.remove();
    _overlay = null;
    widget.onDragChanged?.call(false);
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlayCursor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: _cursorFor(widget.value),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _onStart,
        onPanUpdate: _onUpdate,
        onPanEnd: (_) => _onEnd(),
        onPanCancel: _onEnd,
        child: widget.child,
      ),
    );
  }
}

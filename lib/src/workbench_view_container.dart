import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'layout_constants.dart';
import 'workbench_content.dart';
import 'workbench_sash.dart';
import 'workbench_theme.dart';

/// Typed descriptor for one view in a [WorkbenchViewContainer]
/// (§spec:view-stack). The host supplies an ordered list of these — never a
/// free-form sidebar-body widget — and the container renders the stack.
///
/// A descriptor carries no `collapsible` flag: collapsibility is derived by
/// the container from the number of views (§spec:view-stack), not chosen per
/// view. The descriptor owns the body and the view's expansion *state*
/// (controlled or uncontrolled, §spec:section-disclosure); the container owns
/// the *collapsible* decision.
class WorkbenchViewDescriptor {
  /// Stable identity. The container keys each pane by this id so expansion
  /// state survives reorders within the same descriptor list.
  final String id;

  final String title;

  /// Optional metadata icon tooltip in the header (the shell's analog of VS
  /// Code's dimmed `.description`).
  final String? infoTooltip;

  /// Host-supplied header widgets, placed and revealed by the pane
  /// (§spec:section-header-actions).
  final List<Widget> actions;

  /// Pin [actions] on regardless of hover or focus, while expanded.
  final bool actionsAlwaysVisible;

  /// Seed for uncontrolled expansion. Ignored when [expanded] is supplied.
  final bool initiallyExpanded;

  /// Controlled expansion. When non-null the host drives the value; tapping
  /// the header reports the requested next value via [onExpandedChanged] and
  /// does not self-toggle until the host pushes a new descriptor list.
  final bool? expanded;

  /// Fired when header activation requests a new expanded state.
  final ValueChanged<bool>? onExpandedChanged;

  /// Optional cap on this pane's apportioned body height, in pixels
  /// (§spec:view-pane-max-body). Null is unbounded — the pane fills its share
  /// as before. Mirrors VS Code's `maximumBodySize`: the clamp is canon
  /// (`min(max(value, minBody), maxBody)`), so a value below
  /// [WorkbenchLayoutConstants.viewPaneMinBodyHeight] wins over the floor and
  /// the pane renders below it (hug-to-content).
  final double? maximumBodySize;

  /// Builds the view body. The host owns body content (§spec:scope); the
  /// container owns the header and the stacking chrome.
  final Widget Function(BuildContext) bodyBuilder;

  const WorkbenchViewDescriptor({
    required this.id,
    required this.title,
    this.infoTooltip,
    this.actions = const [],
    this.actionsAlwaysVisible = false,
    this.initiallyExpanded = true,
    this.expanded,
    this.onExpandedChanged,
    this.maximumBodySize,
    required this.bodyBuilder,
  });
}

/// Typed spec for one activity-bar view container (§spec:view-stack). The
/// host returns one per container id from `WorkbenchLayout.containerBuilder`,
/// replacing the retired free-form `sidebarBuilder` widget slot
/// (§spec:capability-boundary): the host supplies typed view descriptors, not
/// a sidebar-body widget.
class WorkbenchViewContainerSpec {
  /// Ordered views rendered as the container's pane stack. Empty renders an
  /// empty container.
  final List<WorkbenchViewDescriptor> views;

  /// When the container holds exactly one view, merge it with the container:
  /// hide the pane header and let the body fill. No effect with 2+ views.
  /// Single-purpose containers set this to preserve a full-body sidebar.
  final bool mergeSingleView;

  /// Controlled pane order: the descriptor ids in render order
  /// (§spec:view-stack). When supplied, the shell renders this order and a
  /// header drag fires [onReorder] without self-mutating — the host updates
  /// this list. Null (the default) lets the shell own the order, seeded from
  /// the [views] order. Mirrors a descriptor's controlled `expanded`.
  final List<String>? order;

  /// Notified when the user drags a pane header to a new slot
  /// (§spec:view-stack). Optional: the shell owns the order and reorders
  /// itself, so this is a notification (e.g. to persist the order across
  /// restarts), not a requirement. Mirrors a descriptor's `onExpandedChanged`.
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Controlled sash body sizing: descriptor id → user-set body height
  /// (§spec:view-stack, §spec:view-container-state). When supplied, the shell
  /// apportions expanded bodies from this map and a sash drag fires
  /// [onSizesChanged] without self-mutating — the host owns the sizing and
  /// rebuilds with a new map. Null (the default) lets the shell own the sizing,
  /// permuted by drags. Mirrors [order] and a descriptor's controlled
  /// `expanded`.
  final Map<String, double>? sizes;

  /// Notified when a sash drag re-divides two neighbors' body heights
  /// (§spec:view-stack, §spec:view-container-state), carrying the full next
  /// sizing map. Optional: the shell owns the sizing and re-divides itself by
  /// default, so this is a notification (e.g. to persist body sizing across
  /// restarts), not a control input. Mirrors [onReorder] and a descriptor's
  /// `onExpandedChanged`.
  final void Function(Map<String, double> sizes)? onSizesChanged;

  const WorkbenchViewContainerSpec({
    required this.views,
    this.mergeSingleView = false,
    this.order,
    this.onReorder,
    this.sizes,
    this.onSizesChanged,
  });
}

/// Renders an ordered list of [WorkbenchViewDescriptor]s as a flush stack of
/// [WorkbenchViewPane]s (§spec:view-stack), the VS Code view-container model.
///
/// **Container-derived collapsibility** (VS Code
/// `ViewPaneContainer.updateViewHeaders`): two or more views make every pane
/// collapsible with its header visible; a single view is non-collapsible
/// (header visible) unless [mergeSingleView] merges it with the container —
/// header hidden, body fills. The host passes no per-view collapsible flag;
/// the container sets each pane's collapsibility.
///
/// **Fixed-height splitview** (§spec:view-stack): panes stack at
/// [WorkbenchLayoutConstants.viewPaneHeaderHeight] with no inter-pane gap —
/// the header band and 1px top rule already on each pane provide the
/// separation. The container apportions its available height among the
/// **expanded** panes rather than letting each grow to its content: each
/// expanded pane is header + an apportioned body, distributed evenly (the
/// sash-resize foundation will weight it), never below
/// [WorkbenchLayoutConstants.viewPaneMinBodyHeight]. A collapsed pane occupies
/// only its header height and contributes nothing to the apportionment, so
/// collapsing one hands its freed body height to the expanded siblings.
///
/// Each expanded pane's body is bounded and **scrolls internally** when its
/// content exceeds its allotment — the per-pane scroll boundary. The whole
/// stack scrolls as one region only as an *overflow fallback*: when the
/// expanded panes cannot fit even at their minimum body heights, each sits at
/// its minimum and the enclosing scroll view scrolls the stack.
///
/// **Why the container tracks expansion**: to derive collapsibility *and* to
/// redistribute freed height to siblings, the container must know each view's
/// expansion. It renders every pane in controlled mode — seeding from
/// [WorkbenchViewDescriptor.initiallyExpanded] for uncontrolled descriptors,
/// and forwarding to the descriptor's [WorkbenchViewDescriptor.onExpandedChanged]
/// when the descriptor is controlled — so the pane's controlled/uncontrolled
/// contract (§spec:section-disclosure) is preserved while the container holds
/// the knowledge its layout needs.
class WorkbenchViewContainer extends StatefulWidget {
  final List<WorkbenchViewDescriptor> views;

  /// When the container holds exactly one view, merge it with the container:
  /// hide the pane header and let the body fill. No effect with 2+ views.
  final bool mergeSingleView;

  /// Controlled pane order as descriptor ids (§spec:view-stack). When non-null
  /// the shell renders this order and a header drag fires [onReorder] without
  /// permuting its own state — the host owns the order and rebuilds with the
  /// moved list. Null (the default) lets the shell own the order, seeded from
  /// the [views] order and permuted by drags. Mirrors a descriptor's
  /// controlled [WorkbenchViewDescriptor.expanded].
  final List<String>? order;

  /// Notified when the user drags a pane header to a new slot (§spec:view-stack,
  /// VS Code `PaneView` header drag-and-drop), with the dragged pane's current
  /// index and its target index. Optional: the shell owns the order and
  /// reorders itself by default, so this is a notification (e.g. to persist
  /// order across restarts), not a control input. Mirrors
  /// [WorkbenchViewDescriptor.onExpandedChanged]. Reorder needs distinct slots,
  /// so it engages only with two or more views (the collapsible case).
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// Controlled sash body sizing as descriptor id → user-set body height
  /// (§spec:view-stack sash-resize, §spec:view-container-state). When non-null
  /// the shell apportions expanded bodies from this map and a sash drag fires
  /// [onSizesChanged] with the next full map without mutating its own state —
  /// the host owns the sizing and rebuilds with the new map. Null (the default)
  /// lets the shell own the sizing, permuted by drags. Mirrors the controlled
  /// [order] and a descriptor's controlled
  /// [WorkbenchViewDescriptor.expanded].
  final Map<String, double>? sizes;

  /// Notified when a sash drag re-divides two adjacent expanded panes' body
  /// heights (§spec:view-stack sash-resize, §spec:view-container-state), with
  /// the full next sizing map. Optional: the shell owns the sizing and
  /// re-divides itself by default, so this is a notification (e.g. to persist
  /// body sizing across restarts), not a control input. Mirrors [onReorder] and
  /// [WorkbenchViewDescriptor.onExpandedChanged].
  final void Function(Map<String, double> sizes)? onSizesChanged;

  const WorkbenchViewContainer({
    super.key,
    required this.views,
    this.mergeSingleView = false,
    this.order,
    this.onReorder,
    this.sizes,
    this.onSizesChanged,
  });

  @override
  State<WorkbenchViewContainer> createState() => _WorkbenchViewContainerState();
}

class _WorkbenchViewContainerState extends State<WorkbenchViewContainer> {
  /// Uncontrolled expansion seeds, keyed by descriptor id. Controlled
  /// descriptors read their value from [WorkbenchViewDescriptor.expanded]
  /// instead and never write here.
  final Map<String, bool> _uncontrolledExpanded = {};

  /// User-set body weights from sash drags, keyed by descriptor id
  /// (§spec:view-stack, sash-resize). An entry overrides the even-default weight
  /// for that pane; panes without an entry take the even-default weight. A sash
  /// drag writes both neighbors so their stored weights re-divide only the height
  /// between them. Weights are proportional, not absolute, and persist across
  /// collapse/expand: the render object always rescales them to fill the body
  /// pool, and a collapsed pane retains its weight so a re-expand restores its
  /// prior size while the survivors shrink proportionally (VS Code SplitView
  /// canon).
  final Map<String, double> _manualBody = {};

  /// The body sizing in effect for layout: the controlled
  /// [WorkbenchViewContainer.sizes] when the host supplies one, otherwise the
  /// shell-owned [_manualBody]. Reads (apportionment, cursor) route through here
  /// so a host can drive sizing; writes go to [_manualBody] only in the
  /// uncontrolled case (the host pushes a new [WorkbenchViewContainer.sizes] in
  /// the controlled case). Mirrors how [_orderedViews] reads
  /// [WorkbenchViewContainer.order] over [_order].
  Map<String, double> get _effectiveSizes => widget.sizes ?? _manualBody;

  /// Uncontrolled pane order, a list of descriptor ids. The shell owns the
  /// stack order (§spec:view-stack): seeded from the descriptor-list order and
  /// permuted by header drags. Null until first seeded. Ignored when the host
  /// supplies a controlled [WorkbenchViewContainer.order]. Mirrors the
  /// expansion model — [_uncontrolledExpanded] is to `expanded` as this is to
  /// `order`.
  List<String>? _order;

  /// The descriptors in their effective render order: the controlled
  /// [WorkbenchViewContainer.order] when the host supplies one, otherwise the
  /// shell-owned [_order], reconciled against the current descriptor set —
  /// dropped ids removed, new ids appended in descriptor-list position. Like
  /// [_isExpanded], this lazily seeds during build (no setState).
  List<WorkbenchViewDescriptor> _orderedViews() {
    final byId = {for (final view in widget.views) view.id: view};
    final List<String> ids;
    if (widget.order != null) {
      ids = widget.order!;
    } else {
      _order ??= [for (final view in widget.views) view.id];
      _order!.removeWhere((id) => !byId.containsKey(id));
      for (final view in widget.views) {
        if (!_order!.contains(view.id)) _order!.add(view.id);
      }
      ids = _order!;
    }
    final ordered = <WorkbenchViewDescriptor>[];
    final seen = <String>{};
    for (final id in ids) {
      final view = byId[id];
      if (view != null && seen.add(id)) ordered.add(view);
    }
    // Descriptors a controlled order omits fall back to the descriptor-list tail.
    for (final view in widget.views) {
      if (seen.add(view.id)) ordered.add(view);
    }
    return ordered;
  }

  /// Reads the live render geometry so a sash drag seeds from the actual
  /// on-screen body heights rather than recomputing the apportionment.
  final GlobalKey _stackKey = GlobalKey();

  /// One header focus node per view, keyed by descriptor id (§spec:view-pane-focus).
  /// The container owns these — it injects each into its pane's header so it can
  /// move focus between header stops for Up/Down traversal (§spec:view-stack)
  /// without reaching into private pane state. Keyed by id so a node survives a
  /// reorder; a node for a dropped view is disposed in [_syncHeaderNodes].
  final Map<String, FocusNode> _headerNodes = {};

  /// Return the owned header focus node for view [id], creating it on first use.
  /// The container disposes these in [dispose] and prunes dropped ids in
  /// [_syncHeaderNodes].
  FocusNode _headerNodeFor(String id) => _headerNodes.putIfAbsent(
    id,
    () => FocusNode(debugLabel: 'WorkbenchViewPane header $id'),
  );

  /// One stable [GlobalKey] per view, keyed by descriptor id (§spec:view-pane-focus).
  /// An expanded non-first pane is wrapped in a sash [Stack]; collapsing it
  /// removes that wrapper, so the pane changes depth in the tree. Without a
  /// stable key Flutter rebuilds the pane's [State] at the new slot, detaching
  /// its header [Focus] and dropping the focus a click just placed (the ring
  /// vanishes and Up/Down restart from the stack edge). The [GlobalKey] makes
  /// Flutter move the existing element across the reparent, preserving focus.
  final Map<String, GlobalKey> _paneKeys = {};

  /// Return the stable pane key for view [id], creating it on first use. Pruned
  /// for dropped ids in [_syncHeaderNodes]; [GlobalKey]s need no disposal.
  GlobalKey _paneKeyFor(String id) =>
      _paneKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'WorkbenchViewPane $id'));

  /// Drop header nodes for views no longer present (§spec:view-pane-focus), so a
  /// removed view's node does not leak. Called each build with the live ordered
  /// id set.
  void _syncHeaderNodes(Iterable<String> liveIds) {
    final live = liveIds.toSet();
    final stale = _headerNodes.keys.where((id) => !live.contains(id)).toList();
    for (final id in stale) {
      _headerNodes.remove(id)!.dispose();
    }
    _paneKeys.removeWhere((id, _) => !live.contains(id));
  }

  @override
  void dispose() {
    for (final node in _headerNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Move header focus to the [delta]-adjacent pane header, clamped to the stack
  /// (§spec:view-pane-focus). Down is `+1`, Up is `-1`. Traversal is over the
  /// owned header nodes in render order only — it never descends into pane
  /// bodies. Focus clamps at the ends (no wrap): when a header holds focus the
  /// key is consumed (handled) even at an edge, so Flutter's default directional
  /// traversal can neither wrap nor escape the stack. Returns ignored only when
  /// no header holds focus, so the container does not swallow Up/Down elsewhere.
  KeyEventResult _moveHeaderFocus(List<String> orderedIds, int delta) {
    final nodes = [for (final id in orderedIds) _headerNodes[id]];
    final current = nodes.indexWhere((n) => n != null && n.hasFocus);
    if (current < 0) return KeyEventResult.ignored;
    final next = current + delta;
    // Clamp at the ends: a header holds focus, so consume the key (no wrap, no
    // escape) even when there is no neighbor to move to.
    if (next < 0 || next >= nodes.length) return KeyEventResult.handled;
    final target = nodes[next];
    if (target == null) return KeyEventResult.handled;
    target.requestFocus();
    return KeyEventResult.handled;
  }

  /// Intercept Down/Up at the container to walk header focus (§spec:view-pane-focus).
  /// The per-pane header handler leaves these keys unhandled so they bubble here;
  /// other keys pass through. Engaged only with [collapsible] (two or more panes).
  KeyEventResult _handleContainerKey(
    List<String> orderedIds,
    bool collapsible,
    KeyEvent event,
  ) {
    if (!collapsible) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      return _moveHeaderFocus(orderedIds, 1);
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return _moveHeaderFocus(orderedIds, -1);
    }
    return KeyEventResult.ignored;
  }

  bool _isExpanded(WorkbenchViewDescriptor view) {
    if (view.expanded != null) return view.expanded!;
    return _uncontrolledExpanded.putIfAbsent(
      view.id,
      () => view.initiallyExpanded,
    );
  }

  void _handleToggle(WorkbenchViewDescriptor view, bool next) {
    if (view.expanded == null) {
      setState(() => _uncontrolledExpanded[view.id] = next);
    }
    view.onExpandedChanged?.call(next);
  }

  /// Index of the pane whose header is being dragged for reorder, or null when
  /// no reorder drag is active (§spec:view-stack).
  int? _dragIndex;

  /// The drop target: the pane index the dragged header currently hovers and
  /// whether it would land before (above) or after (below) it, mirroring VS
  /// Code's `ViewPaneDropOverlay` UP/DOWN split. Null when the pointer is over
  /// no valid target.
  ({int index, bool before})? _dropTarget;

  /// Translate a hover over pane [targetIndex] into the index the dragged pane
  /// would occupy after the move (VS Code `PaneView.movePane` splice). Dropping
  /// before the target lands at its index; dropping after lands just past it.
  /// Removing the dragged pane first shifts later targets down by one, so a
  /// downward move subtracts one.
  int _resolveNewIndex(int from, int targetIndex, bool before) {
    var insertAt = before ? targetIndex : targetIndex + 1;
    if (insertAt > from) insertAt -= 1;
    return insertAt.clamp(0, widget.views.length - 1);
  }

  void _commitReorder() {
    final from = _dragIndex;
    final target = _dropTarget;
    if (from != null && target != null) {
      final newIndex = _resolveNewIndex(from, target.index, target.before);
      if (newIndex != from) {
        // The shell owns the order: permute it directly (§spec:view-stack). A
        // controlled host order defers to the host, which updates `order` from
        // the notification below. `onReorder` is an optional notification in
        // either mode, not a requirement.
        if (widget.order == null) {
          _order ??= [for (final view in widget.views) view.id];
          final moved = _order!.removeAt(from);
          _order!.insert(newIndex, moved);
        }
        widget.onReorder?.call(from, newIndex);
      }
    }
    setState(() {
      _dragIndex = null;
      _dropTarget = null;
    });
  }

  /// Make [header] a reorder drag handle for the pane at [index]
  /// (§spec:view-stack). The drag payload is the pane index; the feedback is the
  /// header itself at reduced opacity, and the source slot dims while dragging —
  /// VS Code shows a drag image and leaves the origin in place.
  Widget _draggableHeader(int index, Widget header) {
    return Draggable<int>(
      data: index,
      // The default childDragAnchorStrategy pins the feedback to the pointer,
      // so [_updateDropTarget] can read the pointer position from the feedback
      // top-left.
      onDragStarted: () => setState(() {
        _dragIndex = index;
        _dropTarget = null;
      }),
      onDraggableCanceled: (_, offset) => _commitReorder(),
      onDragEnd: (_) => _commitReorder(),
      feedback: _DragFeedback(width: _paneWidth(index), child: header),
      childWhenDragging: Opacity(opacity: 0.4, child: header),
      child: header,
    );
  }

  /// The on-screen width of the pane at [index], so the floating drag image is
  /// laid out at the pane's width (the header `Row` needs a bounded width for
  /// its `Expanded` title). Falls back to the container width, then a sane
  /// default, before the box is measured.
  double _paneWidth(int index) {
    final box = _dropTargetKeys[index]?.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) return box.size.width;
    final self = context.findRenderObject();
    if (self is RenderBox && self.hasSize) return self.size.width;
    return 200.0;
  }

  /// Wrap [pane] (the pane at [index]) as a reorder drop target
  /// (§spec:view-stack). While a header is dragged over it, the target reads the
  /// pointer's position within its own box to pick the UP/DOWN half (VS Code's
  /// `ViewPaneDropOverlay`) and overlays the drop indicator on that half.
  Widget _reorderTarget(int index, Widget pane) {
    final key = _dropTargetKeys.putIfAbsent(index, GlobalKey.new);
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) {
        _updateDropTarget(index, details.offset);
        return true;
      },
      onMove: (details) => _updateDropTarget(index, details.offset),
      onLeave: (_) {
        if (_dropTarget?.index == index) {
          setState(() => _dropTarget = null);
        }
      },
      builder: (context, candidate, rejected) {
        final active = _dropTarget;
        final showIndicator = active != null && active.index == index;
        // The key sits on the pane box so [_updateDropTarget] can split it into
        // UP/DOWN halves from the pointer's local y.
        final keyed = KeyedSubtree(key: key, child: pane);
        if (!showIndicator) return keyed;
        return Stack(
          children: [
            keyed,
            Positioned.fill(
              child: _DropIndicator(
                before: active.before,
                color: context.workbenchTheme.sideBarDropBackground,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Resolve which half of pane [index] the pointer at global [pointer] sits in,
  /// and record it as the active drop target. The target's render box converts
  /// the global pointer to a local y; above the vertical midpoint drops before
  /// (UP), below drops after (DOWN). [pointer] is the drag feedback's top-left,
  /// which `childDragAnchorStrategy` pins to the pointer.
  void _updateDropTarget(int index, Offset pointer) {
    final box = _dropTargetKeys[index]?.currentContext?.findRenderObject();
    var before = true;
    if (box is RenderBox && box.hasSize) {
      final local = box.globalToLocal(pointer);
      before = local.dy < box.size.height / 2;
    }
    if (_dropTarget?.index != index || _dropTarget?.before != before) {
      setState(() => _dropTarget = (index: index, before: before));
    }
  }

  /// Stable keys per drop target, so [_updateDropTarget] can read each target's
  /// render box to split it into UP/DOWN halves.
  final Map<int, GlobalKey> _dropTargetKeys = {};

  /// Pair total captured when the active sash drag begins, so [_sashedPane]'s
  /// `onChanged` sets the lower body to `pair - newUpper` and leaves the other
  /// panes untouched.
  double? _activeSashPair;

  /// Hover cursor for the sash on the boundary above [lowerId]: directional when
  /// a neighbor is already pinned at its minimum body height, otherwise
  /// bidirectional (§spec:view-stack). The drag cursor is computed live by the
  /// sash from its basis.
  /// The body-height cap for the pane with descriptor [id]
  /// (§spec:view-pane-max-body), or [double.infinity] when unbounded.
  double _maxBodyOf(String id) {
    for (final view in widget.views) {
      if (view.id == id) return view.maximumBodySize ?? double.infinity;
    }
    return double.infinity;
  }

  MouseCursor _sashCursor(String upperId, String lowerId) {
    const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;
    final upper = _effectiveSizes[upperId];
    final lower = _effectiveSizes[lowerId];
    if (upper != null && upper <= minBody + 0.5) {
      return SystemMouseCursors.resizeDown;
    }
    if (lower != null && lower <= minBody + 0.5) {
      return SystemMouseCursors.resizeUp;
    }
    return SystemMouseCursors.resizeUpDown;
  }

  /// Overlay a resize sash on the top boundary of [pane], an expanded pane whose
  /// nearest expanded neighbor above is [upperId]. The shared [WorkbenchSash]
  /// owns the absolute-anchored drag, the directional cursor, and the hover/drag
  /// highlight (§spec:view-stack). The drag basis is read from live layout at
  /// drag start — a transfer re-apportions only between this pair, conserving
  /// their combined height, so the upper body ranges over `[minBody, pair - minBody]`.
  Widget _sashedPane({
    required String upperId,
    required String lowerId,
    required Widget pane,
  }) {
    return Stack(
      children: [
        pane,
        Positioned(
          // Height owned by WorkbenchSash (sashSize); a thin grab strip on the
          // pane's top boundary.
          top: 0,
          left: 0,
          right: 0,
          child: WorkbenchSash(
            key: ValueKey('workbench-view-sash-$lowerId'),
            axis: Axis.vertical,
            growSign: 1,
            hoverCursor: _sashCursor(upperId, lowerId),
            resolveBasis: () {
              const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;
              final render = _stackKey.currentContext?.findRenderObject();
              final upper = render is _RenderViewStack
                  ? (render.bodyHeightOf(upperId) ?? minBody)
                  : minBody;
              final lower = render is _RenderViewStack
                  ? (render.bodyHeightOf(lowerId) ?? minBody)
                  : minBody;
              final pair = upper + lower;
              _activeSashPair = pair;
              // A finite cap on either pane bounds the drag: the upper pane
              // cannot grow past its own cap, nor shrink the lower below its
              // cap (§spec:view-pane-max-body). The floor stays the minimum
              // body height.
              final upperCap = _maxBodyOf(upperId);
              final lowerCap = _maxBodyOf(lowerId);
              var max = pair - minBody;
              if (max > upperCap) max = upperCap;
              var min = minBody;
              final lowerFloor = pair - lowerCap;
              if (lowerFloor > min) min = lowerFloor;
              if (max < min) max = min;
              return (value: upper, min: min, max: max);
            },
            onChanged: (newUpper) {
              final pair = _activeSashPair ?? newUpper;
              // The next full sizing map: a copy of the effective sizes with
              // only this neighbor pair re-divided. In controlled mode the host
              // owns the map, so the shell notifies without self-mutating; in
              // uncontrolled mode the shell permutes its own [_manualBody] and
              // fires the same notification optionally.
              final next = Map<String, double>.from(_effectiveSizes)
                ..[upperId] = newUpper
                ..[lowerId] = pair - newUpper;
              if (widget.sizes == null) {
                setState(() {
                  _manualBody[upperId] = newUpper;
                  _manualBody[lowerId] = pair - newUpper;
                });
              }
              widget.onSizesChanged?.call(next);
            },
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final views = _orderedViews();

    // Prune header focus nodes for views no longer present, so a removed view's
    // node does not leak (§spec:view-pane-focus).
    _syncHeaderNodes([for (final view in views) view.id]);

    // Merged single view: no pane, body fills the container.
    if (views.length == 1 && widget.mergeSingleView) {
      return Builder(builder: views.single.bodyBuilder);
    }

    // Collapsibility is derived from view count: 2+ → all collapsible; a lone
    // pane is non-collapsible (header stays visible).
    final collapsible = views.length > 1;

    // Reorder engages with two or more panes (the collapsible case): a lone
    // pane has no slot to move to. The shell owns the order, so reorder needs
    // no host callback — it is on whenever there are slots (§spec:view-stack).
    final reorderable = collapsible;

    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        // The previous expanded pane's id, threaded down the stack so each
        // expanded pane after the first gets a sash on the boundary it shares
        // with its nearest expanded neighbor above. A collapsed pane has no body
        // boundary, so it neither carries a sash nor becomes a sash neighbor.
        String? prevExpandedId;
        for (var i = 0; i < views.length; i++) {
          final view = views[i];
          final expanded = _isExpanded(view);
          final isExpandedPane = !collapsible || expanded;
          // A sash sits above this pane only when an expanded pane precedes it.
          final upperId = (isExpandedPane && collapsible) ? prevExpandedId : null;
          final index = i;
          final pane = WorkbenchViewPane.inContainer(
            // A stable key so the pane's element (and its header Focus) survives
            // the sash-wrapper reparent on collapse/expand (§spec:view-pane-focus).
            key: _paneKeyFor(view.id),
            title: view.title,
            infoTooltip: view.infoTooltip,
            actions: view.actions,
            actionsAlwaysVisible: view.actionsAlwaysVisible,
            collapsible: collapsible,
            // The rule separates adjacent panes; the first pane omits it
            // (no divider above the first pane — §spec:view-stack).
            showTopRule: i > 0,
            // The splitview bounds each expanded body so it scrolls internally
            // within its apportioned height (§spec:view-stack).
            boundedBody: true,
            // When reorder is enabled the header is a drag handle that carries
            // this pane's index (§spec:view-stack).
            headerWrapper:
                reorderable ? (header) => _draggableHeader(index, header) : null,
            // The container owns the header focus stop so it can move focus
            // between headers for Up/Down traversal (§spec:view-pane-focus).
            headerFocusNode: _headerNodeFor(view.id),
            expanded: expanded,
            onExpandedChanged: (next) => _handleToggle(view, next),
            child: Builder(builder: view.bodyBuilder),
          );
          Widget paneVisual = upperId == null
              ? pane
              : _sashedPane(
                  upperId: upperId,
                  lowerId: view.id,
                  pane: pane,
                );
          // Each pane is a drop target during a reorder drag, painting the
          // drop-overlay on the half the dragged header would land
          // (§spec:view-stack).
          if (reorderable) {
            paneVisual = _reorderTarget(index, paneVisual);
          }
          children.add(
            _ViewStackChild(
              key: ValueKey('workbench-view-pane-${view.id}'),
              viewId: view.id,
              collapsed: collapsible && !expanded,
              // The render object reads this as a proportional weight for an
              // expanded pane; null leaves it on the even-default weight. A
              // collapsed pane carries no weight into the distribution but
              // retains its stored size, so a re-expand restores it.
              weight: isExpandedPane ? _effectiveSizes[view.id] : null,
              // Per-pane body cap (§spec:view-pane-max-body); null is unbounded.
              maxBody: view.maximumBodySize,
              // An expanded pane after the first carries a resize sash on the
              // boundary it shares with its expanded neighbor above.
              child: paneVisual,
            ),
          );
          if (isExpandedPane) prevExpandedId = view.id;
        }

        // The stack lays out at exactly the available height when the expanded
        // panes fit at or above their minimum body heights; the enclosing
        // scroll view then has nothing to scroll. It overflows (and the scroll
        // view scrolls the whole stack) only as the minimum-body fallback
        // (§spec:view-stack).
        // Each WorkbenchSash carries its own drag-time cursor overlay, so the
        // container needs none of its own.
        final Widget stack = SingleChildScrollView(
          key: const ValueKey('workbench-view-stack-scroll'),
          child: _ViewStack(
            key: _stackKey,
            availableHeight: constraints.maxHeight,
            children: children,
          ),
        );

        // Header focus traversal (§spec:view-pane-focus): a [FocusTraversalGroup]
        // scopes the stack, and a non-focusable [Focus] catches Down/Up bubbling
        // up from the per-pane header handlers — which deliberately leave those
        // keys unhandled — to walk focus between header stops, clamped to the
        // ends. It engages only with two or more panes (the collapsible case); a
        // lone pane has no sibling header to move to.
        final orderedIds = [for (final view in views) view.id];
        return FocusTraversalGroup(
          child: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) =>
                _handleContainerKey(orderedIds, collapsible, event),
            child: stack,
          ),
        );
      },
    );
  }
}


/// Parent-data carrier for a stacked child: its [collapsed] state, its
/// descriptor [viewId] (so the render object can report a pane's measured body
/// height back to a sash drag), and an optional [weight] (§spec:view-stack). The
/// weight is a proportional size, not an absolute pixel target: the render
/// object rescales every expanded pane's weight to fill the available body pool,
/// re-clamped to the minimum body height. An expanded pane with no weight shares
/// the pool with the others as if it carried the even-default weight; collapsed
/// children take only their header height and join no distribution.
class _ViewStackParentData extends ContainerBoxParentData<RenderBox> {
  bool collapsed = false;
  String? viewId;
  double? weight;

  /// Optional body-height cap for this pane (§spec:view-pane-max-body); null is
  /// unbounded. The render object clamps the apportioned body to this maximum
  /// with VS Code's argument order, so a cap below the minimum body height wins
  /// over the floor.
  double? maxBody;

  /// The measured body height (pane height minus its fixed header) from the last
  /// layout, cached so a sash drag can seed from the on-screen size.
  double bodyHeight = 0.0;
}

class _ViewStackChild extends ParentDataWidget<_ViewStackParentData> {
  /// True when this child is a collapsed pane (header height only).
  final bool collapsed;

  /// Descriptor id of the pane, used to report its body height to a sash drag.
  final String viewId;

  /// Proportional body weight for this expanded pane (§spec:view-stack
  /// sash-resize); null leaves the pane on the even-default weight. The render
  /// object rescales weights to fill the body pool, so this is never an absolute
  /// pixel target.
  final double? weight;

  /// Optional body-height cap for this pane (§spec:view-pane-max-body); null is
  /// unbounded.
  final double? maxBody;

  const _ViewStackChild({
    super.key,
    required this.collapsed,
    required this.viewId,
    required this.weight,
    required this.maxBody,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as _ViewStackParentData;
    var needsLayout = false;
    if (parentData.collapsed != collapsed) {
      parentData.collapsed = collapsed;
      needsLayout = true;
    }
    if (parentData.weight != weight) {
      parentData.weight = weight;
      needsLayout = true;
    }
    if (parentData.maxBody != maxBody) {
      parentData.maxBody = maxBody;
      needsLayout = true;
    }
    parentData.viewId = viewId;
    if (needsLayout) {
      final targetParent = renderObject.parent;
      if (targetParent is RenderObject) targetParent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ViewStack;
}

/// Lays a flush stack of view panes as a fixed-height splitview
/// (§spec:view-stack): each header is the canonical
/// [WorkbenchLayoutConstants.viewPaneHeaderHeight]; a collapsed pane takes only
/// that height; the remaining body height is apportioned across the expanded
/// panes **in proportion to their weights**, never below
/// [WorkbenchLayoutConstants.viewPaneMinBodyHeight]. Weights are proportional,
/// not absolute pixels — the body pool is always rescaled to fill, so collapsing
/// a pane or dragging a sash never leaves dead space (the survivors absorb freed
/// height in proportion to their weights). An expanded pane with no weight uses
/// the even-default weight, so a freshly built container divides the pool evenly.
/// Each expanded pane is forced to header + its apportioned body so its body
/// scroller bounds itself. The stack lays out at exactly [availableHeight] when
/// the panes fit at or above the minimum body height; it overflows that height
/// (so the enclosing [SingleChildScrollView] scrolls the whole stack) only as
/// the minimum-body fallback.
class _ViewStack extends MultiChildRenderObjectWidget {
  final double availableHeight;

  const _ViewStack({
    super.key,
    required this.availableHeight,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderViewStack(availableHeight: availableHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderViewStack renderObject) {
    renderObject.availableHeight = availableHeight;
  }
}

class _RenderViewStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ViewStackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ViewStackParentData> {
  _RenderViewStack({required double availableHeight})
    : _availableHeight = availableHeight;

  double _availableHeight;
  double get availableHeight => _availableHeight;
  set availableHeight(double value) {
    if (_availableHeight == value) return;
    _availableHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ViewStackParentData) {
      child.parentData = _ViewStackParentData();
    }
  }

  /// The body height (pane height minus its fixed header) laid out for the pane
  /// with descriptor id [viewId], or null if no such expanded pane exists. A
  /// sash drag reads this to seed the transfer from the on-screen sizes.
  double? bodyHeightOf(String viewId) {
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      if (!parentData.collapsed && parentData.viewId == viewId) {
        return parentData.bodyHeight;
      }
      child = parentData.nextSibling;
    }
    return null;
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    const header = WorkbenchLayoutConstants.viewPaneHeaderHeight;
    const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;

    // Count every pane (collapsed panes still take a header) and the expanded
    // subset. A collapsed pane takes only its header and joins no body
    // distribution; an expanded pane takes header + a proportional share of the
    // body pool (§spec:view-stack).
    var childCount = 0;
    final expanded = <_ViewStackParentData>[];
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      childCount++;
      if (!parentData.collapsed) expanded.add(parentData);
      child = parentData.nextSibling;
    }

    // Body height to apportion after every pane's fixed header.
    final bodyPool = _availableHeight - childCount * header;

    // Resolve each expanded pane's body height from its weight. Weights are
    // proportional, so an unsized pane uses the even-default weight (the pool
    // divided evenly) and the pool is always rescaled to fill — freed space is
    // never orphaned (§spec:view-stack). The min-body floor is enforced by
    // pinning panes that would fall below it and re-dividing the rest among the
    // unpinned by weight; if all panes pin at the floor the stack overflows
    // [_availableHeight] (the minimum-body fallback).
    final bodies = _resolveBodies(expanded, bodyPool, minBody);

    var y = 0.0;
    var i = 0;
    child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      final double body = parentData.collapsed ? 0.0 : bodies[i++];
      parentData.bodyHeight = body;
      final height = parentData.collapsed ? header : header + body;
      child.layout(
        BoxConstraints.tightFor(width: width, height: height),
        parentUsesSize: true,
      );
      parentData.offset = Offset(0, y);
      y += height;
      child = parentData.nextSibling;
    }

    size = constraints.constrain(Size(width, y));
  }

  /// Distribute [bodyPool] across the [expanded] panes in proportion to their
  /// weights, clamped so no body falls below [minBody] (§spec:view-stack). An
  /// unsized pane (`weight == null`) takes the even-default weight — the pool
  /// divided by the expanded count — so a fresh container divides evenly and a
  /// container with some sized panes treats the rest as equal peers. Returns the
  /// body heights in expanded-pane order.
  ///
  /// Each pane's body is clamped to `[floor, cap]` where `cap` is its
  /// [_ViewStackParentData.maxBody] (or unbounded) and `floor` is
  /// `min(minBody, cap)` — a cap below [minBody] collapses the interval to the
  /// cap, so the maximum wins over the floor, matching VS Code's
  /// `clamp(value, min, max)` argument order (§spec:view-pane-max-body). The
  /// clamp is a two-sided water-fill: first pin panes over their cap (returning
  /// the excess to the pool for uncapped panes), then pin panes under their
  /// floor. When every pane is pinned at a cap below the pool the heights sum
  /// short of [bodyPool] and the stack leaves a trailing gap; when every pane is
  /// pinned at the floor they sum past it and the stack overflows (the
  /// minimum-body fallback).
  static List<double> _resolveBodies(
    List<_ViewStackParentData> expanded,
    double bodyPool,
    double minBody,
  ) {
    final count = expanded.length;
    if (count == 0) return const [];

    // Even-default weight for unsized panes, in the same unit as a stored weight
    // (body-height pixels). A pane's effective weight is its stored value or this
    // default; weights only ever express ratios — the pool is rescaled to fill.
    final evenWeight = bodyPool > 0 ? bodyPool / count : minBody;
    final weights = [
      for (final pd in expanded) pd.weight ?? evenWeight,
    ];
    final caps = [
      for (final pd in expanded) pd.maxBody ?? double.infinity,
    ];
    // A cap below the floor wins (VS Code max-over-min); the effective floor is
    // never above the cap.
    final floors = [
      for (final cap in caps) cap < minBody ? cap : minBody,
    ];

    final bodies = List<double>.filled(count, 0.0);
    final pinned = List<bool>.filled(count, false);
    var remainingPool = bodyPool;

    double unpinnedWeightSum() {
      var sum = 0.0;
      for (var i = 0; i < count; i++) {
        if (!pinned[i]) sum += weights[i];
      }
      return sum;
    }

    // Phase 1 — pin panes whose proportional share exceeds their cap at the cap,
    // returning the excess to the pool. Pinning raises the per-weight rate for
    // the rest, which can push another pane over its cap, so iterate to a fixed
    // point. After this phase every unpinned pane's share is at or below its cap.
    while (true) {
      final weightSum = unpinnedWeightSum();
      if (weightSum <= 0) break;
      var pinnedThisPass = false;
      for (var i = 0; i < count; i++) {
        if (pinned[i]) continue;
        final share = remainingPool * weights[i] / weightSum;
        if (share > caps[i]) {
          bodies[i] = caps[i];
          pinned[i] = true;
          remainingPool -= caps[i];
          pinnedThisPass = true;
        }
      }
      if (!pinnedThisPass) break;
    }

    // Phase 2 — pin panes that underflow the floor, re-dividing the rest by
    // weight to a fixed point. Floor-pinning only shrinks survivor shares, so no
    // capped pane re-exceeds its cap.
    while (true) {
      final weightSum = unpinnedWeightSum();
      if (weightSum <= 0) break;
      var pinnedThisPass = false;
      for (var i = 0; i < count; i++) {
        if (pinned[i]) continue;
        final share = remainingPool * weights[i] / weightSum;
        if (share < floors[i]) {
          bodies[i] = floors[i];
          pinned[i] = true;
          remainingPool -= floors[i];
          pinnedThisPass = true;
        }
      }
      if (!pinnedThisPass) {
        // No pane underflows: every unpinned pane takes its proportional share.
        for (var i = 0; i < count; i++) {
          if (!pinned[i]) bodies[i] = remainingPool * weights[i] / weightSum;
        }
        break;
      }
    }
    return bodies;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _maxChildIntrinsic((c) => c.getMinIntrinsicWidth(height));

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _maxChildIntrinsic((c) => c.getMaxIntrinsicWidth(height));

  double _maxChildIntrinsic(double Function(RenderBox) measure) {
    var value = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      value = value > measure(child) ? value : measure(child);
      child = (child.parentData! as _ViewStackParentData).nextSibling;
    }
    return value;
  }
}

/// The floating drag image for a reorder drag (§spec:view-stack): the pane
/// header at reduced opacity, laid out at the source pane's [width] so its
/// `Expanded` title has a bound. [Material] supplies the text/icon baseline the
/// header expects once it floats above the tree.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.85,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(width: width, child: child),
      ),
    );
  }
}

/// The reorder drop indicator (§spec:view-stack): a translucent fill over the
/// target pane's top half ([before]) or bottom half, mirroring VS Code's
/// `ViewPaneDropOverlay` UP/DOWN split. [color] is the theme's
/// `sideBar.dropBackground`. It ignores pointer events so the drag continues to
/// hit-test the target beneath it.
class _DropIndicator extends StatelessWidget {
  const _DropIndicator({required this.before, required this.color});

  final bool before;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: before ? Alignment.topCenter : Alignment.bottomCenter,
        child: FractionallySizedBox(
          key: const ValueKey('workbench-view-drop-indicator'),
          heightFactor: 0.5,
          widthFactor: 1.0,
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  /// Reorders the container's views when the user drags a pane header onto
  /// another pane (§spec:view-stack). The host owns the view order and rebuilds
  /// the spec with the moved list, so the reorder persists. Null leaves the
  /// headers non-draggable and the order fixed.
  final void Function(int oldIndex, int newIndex)? onReorder;

  const WorkbenchViewContainerSpec({
    required this.views,
    this.mergeSingleView = false,
    this.onReorder,
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

  /// Reorders the panes when the user drags a pane header onto another pane
  /// (§spec:view-stack, VS Code `PaneView` header drag-and-drop). Called with
  /// the dragged view's current index and its target index; the host owns the
  /// descriptor order and rebuilds with the moved list, so the reorder
  /// persists. Null disables reorder — the headers are not draggable and order
  /// is fixed. Reorder needs distinct slots, so it only engages with two or
  /// more views (the collapsible case).
  final void Function(int oldIndex, int newIndex)? onReorder;

  const WorkbenchViewContainer({
    super.key,
    required this.views,
    this.mergeSingleView = false,
    this.onReorder,
  });

  @override
  State<WorkbenchViewContainer> createState() => _WorkbenchViewContainerState();
}

class _WorkbenchViewContainerState extends State<WorkbenchViewContainer> {
  /// Uncontrolled expansion seeds, keyed by descriptor id. Controlled
  /// descriptors read their value from [WorkbenchViewDescriptor.expanded]
  /// instead and never write here.
  final Map<String, bool> _uncontrolledExpanded = {};

  /// User-set body heights from sash drags, keyed by descriptor id
  /// (§spec:view-stack, sash-resize). An entry overrides the even default for
  /// that expanded pane; panes without an entry split the remaining body pool
  /// evenly. A sash drag writes both neighbors so their stored heights re-divide
  /// only the height between them, leaving other panes untouched. Entries persist
  /// across rebuilds until the layout changes (collapse/expand re-apportions the
  /// remainder), giving the manual proportions their "holds after release"
  /// behavior.
  final Map<String, double> _manualBody = {};

  /// The set of expanded descriptor ids in effect when [_manualBody] was last
  /// written. When the expanded set changes — a pane collapses or expands, by
  /// host control or by header toggle — the stored heights no longer sum to the
  /// new pool, so they are dropped and the new set re-apportions evenly.
  Set<String> _manualBasis = const {};

  /// Reads the live render geometry so a sash drag seeds from the actual
  /// on-screen body heights rather than recomputing the apportionment.
  final GlobalKey _stackKey = GlobalKey();

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
      if (newIndex != from) widget.onReorder!(from, newIndex);
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
  MouseCursor _sashCursor(String upperId, String lowerId) {
    const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;
    final upper = _manualBody[upperId];
    final lower = _manualBody[lowerId];
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
              final max = pair - minBody;
              return (
                value: upper,
                min: minBody,
                max: max < minBody ? minBody : max,
              );
            },
            onChanged: (newUpper) {
              final pair = _activeSashPair ?? newUpper;
              setState(() {
                _manualBody[upperId] = newUpper;
                _manualBody[lowerId] = pair - newUpper;
              });
            },
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  /// Drop manual sash sizing when the expanded set differs from the one in
  /// effect when it was last written ([_manualBasis]). The stored heights divide
  /// that set's body pool; once a pane collapses or expands the pool and
  /// membership change, so even apportionment is the sensible reset
  /// (§spec:view-stack). While no manual sizing is held the basis tracks the
  /// current set, so the first drag records the set it sizes.
  void _reconcileManualBasis(Set<String> expandedIds) {
    if (_manualBody.isEmpty) {
      _manualBasis = expandedIds;
      return;
    }
    if (!setEquals(_manualBasis, expandedIds)) {
      _manualBody.clear();
      _manualBasis = expandedIds;
    }
  }

  @override
  Widget build(BuildContext context) {
    final views = widget.views;

    // Merged single view: no pane, body fills the container.
    if (views.length == 1 && widget.mergeSingleView) {
      return Builder(builder: views.single.bodyBuilder);
    }

    // Collapsibility is derived from view count: 2+ → all collapsible; a lone
    // pane is non-collapsible (header stays visible).
    final collapsible = views.length > 1;

    // Reconcile manual sash sizing against the current expanded set before
    // rendering: if a pane collapsed or expanded since the last drag, the stored
    // heights are stale and get dropped here (§spec:view-stack).
    final expandedIds = <String>{
      for (final view in views)
        if (!collapsible || _isExpanded(view)) view.id,
    };
    _reconcileManualBasis(expandedIds);

    // Reorder engages only with two or more panes (the collapsible case): a
    // lone pane has no slot to move to (§spec:view-stack).
    final reorderable = widget.onReorder != null && collapsible;

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
              // The render object reads this to honor a user-set body height
              // for an expanded pane; null leaves it on the even default.
              manualBody: isExpandedPane ? _manualBody[view.id] : null,
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
        return SingleChildScrollView(
          key: const ValueKey('workbench-view-stack-scroll'),
          child: _ViewStack(
            key: _stackKey,
            availableHeight: constraints.maxHeight,
            children: children,
          ),
        );
      },
    );
  }
}


/// Parent-data carrier for a stacked child: its [collapsed] state, its
/// descriptor [viewId] (so the render object can report a pane's measured body
/// height back to a sash drag), and an optional user-set [manualBody] target
/// from a sash drag. Expanded children share the apportioned body height — those
/// with a [manualBody] take that height, the rest split the remainder evenly;
/// collapsed children take only their header height.
class _ViewStackParentData extends ContainerBoxParentData<RenderBox> {
  bool collapsed = false;
  String? viewId;
  double? manualBody;

  /// The measured body height (pane height minus its fixed header) from the last
  /// layout, cached so a sash drag can seed from the on-screen size.
  double bodyHeight = 0.0;
}

class _ViewStackChild extends ParentDataWidget<_ViewStackParentData> {
  /// True when this child is a collapsed pane (header height only).
  final bool collapsed;

  /// Descriptor id of the pane, used to report its body height to a sash drag.
  final String viewId;

  /// User-set body height for this expanded pane (§spec:view-stack sash-resize);
  /// null leaves the pane on the even default share.
  final double? manualBody;

  const _ViewStackChild({
    super.key,
    required this.collapsed,
    required this.viewId,
    required this.manualBody,
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
    if (parentData.manualBody != manualBody) {
      parentData.manualBody = manualBody;
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
/// that height; the remaining body height is apportioned evenly across the
/// expanded panes, never below
/// [WorkbenchLayoutConstants.viewPaneMinBodyHeight]. Each expanded pane is
/// forced to header + its apportioned body so its body scroller bounds itself.
/// The stack lays out at exactly [availableHeight] when the panes fit at or
/// above the minimum body height; it overflows that height (so the enclosing
/// [SingleChildScrollView] scrolls the whole stack) only as the minimum-body
/// fallback.
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

    // Count panes and the expanded subset; sum any user-set body heights. A
    // collapsed pane takes only its header; an expanded pane takes header + a
    // body. Expanded panes split into two groups: those with a sash-set
    // [manualBody] target, and the rest that share the remaining pool evenly.
    var childCount = 0;
    var expandedCount = 0;
    var manualCount = 0;
    var manualTotal = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      childCount++;
      if (!parentData.collapsed) {
        expandedCount++;
        if (parentData.manualBody != null) {
          manualCount++;
          manualTotal += parentData.manualBody!;
        }
      }
      child = parentData.nextSibling;
    }

    // Body height to apportion after every pane's fixed header. Sash-set panes
    // hold their target (clamped to the floor); the rest divide what remains
    // evenly — a freshly built container with no manual sizes divides it all
    // evenly (§spec:view-stack).
    final headersTotal = childCount * header;
    final bodyPool = _availableHeight - headersTotal;
    final autoCount = expandedCount - manualCount;
    final autoPool = bodyPool - manualTotal;
    final evenBody = autoCount > 0 ? autoPool / autoCount : 0.0;

    // Below the minimum body floor the auto panes cannot fit: each expanded body
    // sits at the minimum and the stack overflows [_availableHeight], so the
    // enclosing scroll view scrolls the whole stack (the overflow fallback).
    final autoShare = evenBody < minBody ? minBody : evenBody;

    var y = 0.0;
    child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      final double body;
      if (parentData.collapsed) {
        body = 0.0;
      } else if (parentData.manualBody != null) {
        // A sash-set body holds its target, never below the floor.
        body = parentData.manualBody! < minBody ? minBody : parentData.manualBody!;
      } else {
        body = autoShare;
      }
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

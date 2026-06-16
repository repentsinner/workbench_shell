import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'layout_constants.dart';
import 'workbench_content.dart';

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

  const WorkbenchViewContainerSpec({
    required this.views,
    this.mergeSingleView = false,
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

  const WorkbenchViewContainer({
    super.key,
    required this.views,
    this.mergeSingleView = false,
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

  /// Apply a sash drag on the boundary above [lowerId], whose nearest expanded
  /// neighbor above is [upperId]. [delta] is the pointer's vertical movement:
  /// positive grows the upper body and shrinks the lower. The transfer is
  /// clamped so neither body falls below
  /// [WorkbenchLayoutConstants.viewPaneMinBodyHeight] (§spec:view-stack).
  void _dragSash(String upperId, String lowerId, double delta) {
    final render = _stackKey.currentContext?.findRenderObject();
    if (render is! _RenderViewStack) return;
    final upperBody = render.bodyHeightOf(upperId);
    final lowerBody = render.bodyHeightOf(lowerId);
    if (upperBody == null || lowerBody == null) return;

    const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;
    final pair = upperBody + lowerBody;
    // The upper body absorbs the drag; clamp it within the pair so the lower
    // body keeps at least minBody on the other side.
    final newUpper = (upperBody + delta).clamp(minBody, pair - minBody);
    final newLower = pair - newUpper;
    if (newUpper == upperBody && newLower == lowerBody) return;
    setState(() {
      _manualBody[upperId] = newUpper;
      _manualBody[lowerId] = newLower;
      _manualBasis = render.expandedIds();
    });
  }

  /// Drop manual sash sizing when the expanded set differs from the one in
  /// effect when it was written ([_manualBasis]). The stored heights divide that
  /// set's body pool; once a pane collapses or expands the pool and membership
  /// change, so even apportionment is the sensible reset (§spec:view-stack).
  void _reconcileManualBasis(Set<String> expandedIds) {
    if (_manualBody.isEmpty) {
      _manualBasis = expandedIds;
      return;
    }
    if (!_setEquals(_manualBasis, expandedIds)) {
      _manualBody.clear();
      _manualBasis = expandedIds;
    }
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

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
          children.add(
            _ViewStackChild(
              key: ValueKey('workbench-view-pane-${view.id}'),
              viewId: view.id,
              collapsed: collapsible && !expanded,
              // The render object reads this to honor a user-set body height
              // for an expanded pane; null leaves it on the even default.
              manualBody: isExpandedPane ? _manualBody[view.id] : null,
              child: _SashedPane(
                sashKey: upperId == null
                    ? null
                    : ValueKey('workbench-view-sash-${view.id}'),
                onSashDrag: upperId == null
                    ? null
                    : (delta) => _dragSash(upperId, view.id, delta),
                child: WorkbenchViewPane.inContainer(
                  title: view.title,
                  infoTooltip: view.infoTooltip,
                  actions: view.actions,
                  actionsAlwaysVisible: view.actionsAlwaysVisible,
                  collapsible: collapsible,
                  // The rule separates adjacent panes; the first pane omits it
                  // (no divider above the first pane — §spec:view-stack).
                  showTopRule: i > 0,
                  // The splitview bounds each expanded body so it scrolls
                  // internally within its apportioned height (§spec:view-stack).
                  boundedBody: true,
                  expanded: expanded,
                  onExpandedChanged: (next) => _handleToggle(view, next),
                  child: Builder(builder: view.bodyBuilder),
                ),
              ),
            ),
          );
          if (isExpandedPane) prevExpandedId = view.id;
        }

        // The stack lays out at exactly the available height when the expanded
        // panes fit at or above their minimum body heights; the enclosing
        // scroll view then has nothing to scroll. It overflows (and the scroll
        // view scrolls the whole stack) only as the minimum-body fallback
        // (§spec:view-stack).
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

/// Overlays a thin draggable sash on the top edge of an expanded pane
/// (§spec:view-stack, sash-resize). The sash straddles the boundary the pane
/// shares with its nearest expanded neighbor above; dragging it transfers
/// apportioned body height between the two. A resize cursor marks the grab
/// target. Panes with no expanded neighbor above (the first expanded pane, or a
/// pane whose neighbor is collapsed) get [sashKey] null and render no sash.
class _SashedPane extends StatelessWidget {
  final Key? sashKey;
  final ValueChanged<double>? onSashDrag;
  final Widget child;

  const _SashedPane({
    required this.sashKey,
    required this.onSashDrag,
    required this.child,
  });

  /// Vertical grab band centered on the pane boundary. Wide enough to catch
  /// the pointer without overlapping the header's interactive controls.
  static const double _sashHitHeight = 6.0;

  @override
  Widget build(BuildContext context) {
    if (onSashDrag == null) return child;
    return Stack(
      children: [
        child,
        Positioned(
          key: sashKey,
          top: 0,
          left: 0,
          right: 0,
          height: _sashHitHeight,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragUpdate: (d) => onSashDrag!(d.delta.dy),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
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

  /// The descriptor ids of the currently expanded panes — the basis a sash drag
  /// records so a later collapse/expand can detect a stale manual sizing set.
  Set<String> expandedIds() {
    final ids = <String>{};
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      if (!parentData.collapsed && parentData.viewId != null) {
        ids.add(parentData.viewId!);
      }
      child = parentData.nextSibling;
    }
    return ids;
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

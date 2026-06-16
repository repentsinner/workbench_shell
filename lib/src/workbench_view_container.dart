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
/// **Flush stack, single scroll**: panes stack at
/// [WorkbenchLayoutConstants.viewPaneHeaderHeight] with no inter-pane gap —
/// the header band and 1px top rule already on each pane provide the
/// separation. Expanded panes share the available height; collapsing a pane
/// frees its body height to the remaining expanded siblings, which absorb it,
/// while the collapsed pane occupies only its header height. When expanded
/// bodies overflow the available height the whole stack scrolls as one region;
/// the scroll boundary is the container, not each pane.
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final children = <Widget>[];
        for (final view in views) {
          final expanded = _isExpanded(view);
          children.add(
            _ViewStackChild(
              key: ValueKey('workbench-view-pane-${view.id}'),
              collapsed: collapsible && !expanded,
              child: WorkbenchViewPane.inContainer(
                title: view.title,
                infoTooltip: view.infoTooltip,
                actions: view.actions,
                actionsAlwaysVisible: view.actionsAlwaysVisible,
                collapsible: collapsible,
                expanded: expanded,
                onExpandedChanged: (next) => _handleToggle(view, next),
                child: Builder(builder: view.bodyBuilder),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          child: _ViewStack(
            availableHeight: constraints.maxHeight,
            children: children,
          ),
        );
      },
    );
  }
}

/// Parent-data carrier marking whether a stacked child is collapsed (header
/// height only). Expanded children share leftover height; collapsed children
/// take their intrinsic header height.
class _ViewStackParentData extends ContainerBoxParentData<RenderBox> {
  bool collapsed = false;
}

class _ViewStackChild extends ParentDataWidget<_ViewStackParentData> {
  /// True when this child is a collapsed pane (header height only).
  final bool collapsed;

  const _ViewStackChild({
    super.key,
    required this.collapsed,
    required super.child,
  });

  @override
  void applyParentData(RenderObject renderObject) {
    final parentData = renderObject.parentData! as _ViewStackParentData;
    if (parentData.collapsed != collapsed) {
      parentData.collapsed = collapsed;
      final targetParent = renderObject.parent;
      if (targetParent is RenderObject) targetParent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _ViewStack;
}

/// Lays a flush stack of view panes: collapsed panes take their natural
/// (header) height; expanded panes share leftover space when the stack fits,
/// and take their natural body height when it overflows (the enclosing
/// [SingleChildScrollView] then scrolls the whole stack as one region).
class _ViewStack extends MultiChildRenderObjectWidget {
  final double availableHeight;

  const _ViewStack({
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

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    // First pass: lay each child out loosely at the available width to read its
    // natural height. Real layout (not dry) so host bodies need not implement
    // dry-layout support; expanded panes are re-laid out below with the shared
    // height.
    final probe = BoxConstraints(
      minWidth: width,
      maxWidth: width,
    );
    final natural = <RenderBox, double>{};
    var naturalTotal = 0.0;
    var expandedCount = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      child.layout(probe, parentUsesSize: true);
      natural[child] = child.size.height;
      naturalTotal += child.size.height;
      if (!parentData.collapsed) expandedCount++;
      child = parentData.nextSibling;
    }

    // Distribute leftover space to expanded panes only when the stack fits.
    // On overflow each pane keeps its natural height and the parent scroll
    // view scrolls the whole stack.
    final leftover = _availableHeight - naturalTotal;
    final share = (leftover > 0 && expandedCount > 0)
        ? leftover / expandedCount
        : 0.0;

    var y = 0.0;
    child = firstChild;
    while (child != null) {
      final parentData = child.parentData! as _ViewStackParentData;
      final height = natural[child]! + (parentData.collapsed ? 0.0 : share);
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

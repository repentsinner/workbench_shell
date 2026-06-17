import 'package:flutter/material.dart';

import 'activity_bar_item.dart';
import 'layout_constants.dart';
import 'workbench_sash.dart';
import 'workbench_theme.dart';
import 'workbench_view_container.dart';

/// VS Code-style workbench layout with activity bar, sidebar, editor
/// area, bottom panel, and status bar.
///
/// The shell provides layout chrome only. The consumer fills content
/// via builder callbacks. No dependency on GetIt or any application
/// package.
class WorkbenchLayout extends StatefulWidget {
  /// Activity bar items (icons in the left edge bar).
  final List<ActivityBarItem> activityBarItems;

  /// Main editor/visualizer content.
  final Widget editor;

  /// Maps the active view-container id to its typed
  /// [WorkbenchViewContainerSpec] (§spec:view-stack). The shell renders the
  /// spec's view descriptors through a [WorkbenchViewContainer]; the host
  /// supplies descriptors, not a sidebar-body widget
  /// (§spec:capability-boundary). An empty spec renders an empty sidebar body.
  final WorkbenchViewContainerSpec Function(String containerId) containerBuilder;

  /// Bottom panel content. Pass [SizedBox.shrink] to hide.
  final Widget bottomPanel;

  /// Status bar content.
  final Widget statusBar;

  /// Called when the panel toggle is requested (by double-clicking
  /// the panel border, for example). The consumer manages panel
  /// visibility state via [showBottomPanel].
  final VoidCallback? onTogglePanel;

  /// Whether the bottom panel is visible.
  final bool showBottomPanel;

  /// Initial active view-container ID. Defaults to the first item's ID.
  /// Ignored when [activeViewContainerId] is non-null (controlled mode).
  final String? initialViewContainerId;

  /// Externally controlled active view-container ID. When non-null, the
  /// shell renders this container and delegates container changes to
  /// [onViewContainerChanged]. The host owns the state.
  ///
  /// When null, the shell tracks the active container internally
  /// (uncontrolled mode) seeded from [initialViewContainerId].
  final String? activeViewContainerId;

  /// Called when the user requests a view-container change via the activity
  /// bar. The host shall update its [activeViewContainerId] in response.
  /// Required when [activeViewContainerId] is non-null.
  final ValueChanged<String>? onViewContainerChanged;

  const WorkbenchLayout({
    super.key,
    required this.activityBarItems,
    required this.editor,
    required this.containerBuilder,
    required this.bottomPanel,
    required this.statusBar,
    this.onTogglePanel,
    this.showBottomPanel = true,
    this.initialViewContainerId,
    this.activeViewContainerId,
    this.onViewContainerChanged,
  }) : assert(
         activeViewContainerId == null || onViewContainerChanged != null,
         'onViewContainerChanged is required when activeViewContainerId is '
         'provided',
       );

  @override
  State<WorkbenchLayout> createState() => _WorkbenchLayoutState();
}

class _WorkbenchLayoutState extends State<WorkbenchLayout> {
  String _internalActiveViewContainerId = '';
  bool _sidebarVisible = true;
  double _sidebarWidth = WorkbenchLayoutConstants.sidebarDefaultWidth;
  double _panelHeight = WorkbenchLayoutConstants.panelDefaultHeight;

  // Activity-bar items partitioned by zone and sorted by sortOrder.
  // Derived once from widget.activityBarItems (which is immutable for a
  // given widget) rather than on every rebuild — the layout rebuilds on
  // every sidebar/panel drag frame.
  List<ActivityBarItem> _mainActivityItems = const [];
  List<ActivityBarItem> _bottomActivityItems = const [];

  String get _activeViewContainerId =>
      widget.activeViewContainerId ?? _internalActiveViewContainerId;

  @override
  void initState() {
    super.initState();
    _internalActiveViewContainerId =
        widget.initialViewContainerId ??
        (widget.activityBarItems.isNotEmpty
            ? widget.activityBarItems.first.id
            : '');
    _partitionActivityItems();
  }

  @override
  void didUpdateWidget(covariant WorkbenchLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.activityBarItems, widget.activityBarItems)) {
      _partitionActivityItems();
    }
  }

  void _partitionActivityItems() {
    int byOrder(ActivityBarItem a, ActivityBarItem b) =>
        a.sortOrder.compareTo(b.sortOrder);
    _mainActivityItems =
        widget.activityBarItems
            .where((i) => i.zone == ActivityBarZone.main)
            .toList()
          ..sort(byOrder);
    _bottomActivityItems =
        widget.activityBarItems
            .where((i) => i.zone == ActivityBarZone.bottom)
            .toList()
          ..sort(byOrder);
  }

  void _setActiveViewContainer(String containerId) {
    final current = _activeViewContainerId;
    if (current == containerId) {
      setState(() {
        _sidebarVisible = !_sidebarVisible;
      });
      return;
    }
    setState(() {
      _sidebarVisible = true;
      if (widget.activeViewContainerId == null) {
        _internalActiveViewContainerId = containerId;
      }
    });
    widget.onViewContainerChanged?.call(containerId);
  }


  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;

    return Scaffold(
      backgroundColor: theme.editorBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Activity Bar
                  _ActivityBar(
                    mainItems: _mainActivityItems,
                    bottomItems: _bottomActivityItems,
                    activeViewContainerId: _activeViewContainerId,
                    sidebarVisible: _sidebarVisible,
                    onViewContainerSelected: _setActiveViewContainer,
                    theme: theme,
                  ),

                  // Sidebar (collapsible)
                  if (_sidebarVisible)
                    Stack(
                      children: [
                        _Sidebar(
                          width: _sidebarWidth,
                          activeLabel: _activeLabelFor(
                            _activeViewContainerId,
                          ),
                          spec: widget.containerBuilder(
                            _activeViewContainerId,
                          ),
                          theme: theme,
                        ),
                        // The sash overlays the sidebar's right edge rather than
                        // taking a strip of layout, so at rest it adds nothing
                        // (canon: the sash is transparent; the seam is the
                        // sidebar's own right border). Mirrors the panel and
                        // view-stack pane sashes.
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: _buildVerticalResizer(theme),
                        ),
                      ],
                    ),

                  // Editor + bottom panel. The panel is wrapped in a
                  // Visibility(maintainState: true) so its widget
                  // subtree (and any State it owns — timers, scroll
                  // positions, fetched data) survives hide/show
                  // cycles. Without this, toggling showBottomPanel
                  // disposes the entire panel tree and discards
                  // content state every cycle.
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: widget.editor),
                        Visibility(
                          visible: widget.showBottomPanel,
                          maintainState: true,
                          maintainAnimation: true,
                          child: SizedBox(
                            height: _panelHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  // Container (not bare DecoratedBox) so
                                  // the child is inset 1px from the top
                                  // by Container-added padding. Bare
                                  // DecoratedBox paints the border behind
                                  // the child and the panel's own opaque
                                  // background widget overdraws the 1px
                                  // border strip.
                                  //
                                  // Null panelBorder → theme explicitly
                                  // suppresses the seam; skip the
                                  // BorderSide entirely rather than
                                  // falling back to a neighboring color.
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: theme.panelBorder == null
                                          ? null
                                          : Border(
                                              top: BorderSide(
                                                color: theme.panelBorder!,
                                              ),
                                            ),
                                    ),
                                    child: widget.bottomPanel,
                                  ),
                                ),
                                Positioned(
                                  // Sit the sash fully inside the panel
                                  // (top: 0), like the view-stack pane sashes.
                                  // An overhang above the panel's top edge is
                                  // clipped by this Stack's hardEdge bound,
                                  // halving the painted highlight band; sitting
                                  // inside keeps every seam's sash the same
                                  // canonical width. Height owned by
                                  // WorkbenchSash (sashSize).
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildHorizontalResizer(theme),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            widget.statusBar,
          ],
        ),
      ),
    );
  }

  String _activeLabelFor(String containerId) {
    for (final item in widget.activityBarItems) {
      if (item.id == containerId) return item.label;
    }
    return '';
  }

  Widget _buildVerticalResizer(WorkbenchTheme theme) {
    // The sidebar sits on the left, so dragging the seam right grows its width
    // (growSign +1). The sash is transparent at rest like the panel/view-pane
    // sashes — the seam is the sidebar's own right border, which this overlays.
    // WorkbenchSash owns the canonical drag, directional cursor, and hover/drag
    // highlight (§spec:workbench-layout).
    return WorkbenchSash(
      axis: Axis.horizontal,
      value: _sidebarWidth,
      min: WorkbenchLayoutConstants.sidebarMinWidth,
      max: WorkbenchLayoutConstants.sidebarMaxWidth,
      growSign: 1,
      onChanged: (next) => setState(() => _sidebarWidth = next),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildHorizontalResizer(WorkbenchTheme theme) {
    // The panel sits at the bottom, so dragging the seam up grows its height
    // (growSign -1: moving the pointer down shrinks the panel). Same canonical
    // sash, highlight included (§spec:workbench-layout).
    return WorkbenchSash(
      axis: Axis.vertical,
      value: _panelHeight,
      min: WorkbenchLayoutConstants.panelMinHeight,
      max: WorkbenchLayoutConstants.panelMaxHeight,
      growSign: -1,
      onChanged: (next) => setState(() => _panelHeight = next),
      child: const SizedBox.expand(),
    );
  }
}

/// Activity bar — vertical icon strip on the left edge.
///
/// Receives items already partitioned by zone and sorted by sortOrder;
/// the owning state derives those once rather than on every rebuild.
class _ActivityBar extends StatelessWidget {
  final List<ActivityBarItem> mainItems;
  final List<ActivityBarItem> bottomItems;
  final String activeViewContainerId;
  final bool sidebarVisible;
  final ValueChanged<String> onViewContainerSelected;
  final WorkbenchTheme theme;

  const _ActivityBar({
    required this.mainItems,
    required this.bottomItems,
    required this.activeViewContainerId,
    required this.sidebarVisible,
    required this.onViewContainerSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // Null activityBarBorder → theme registry default (modern themes).
    // Skip the BorderSide entirely instead of flat-grey fallback.
    return Container(
      width: WorkbenchLayoutConstants.activityBarWidth,
      decoration: BoxDecoration(
        color: theme.activityBarBackground,
        border: theme.activityBarBorder == null
            ? null
            : Border(right: BorderSide(color: theme.activityBarBorder!)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [for (final item in mainItems) _buildIcon(item)],
            ),
          ),
          for (final item in bottomItems) _buildIcon(item),
        ],
      ),
    );
  }

  Widget _buildIcon(ActivityBarItem item) {
    final active = sidebarVisible && activeViewContainerId == item.id;
    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onViewContainerSelected(item.id),
        child: Container(
          width: WorkbenchLayoutConstants.activityBarWidth,
          height: WorkbenchLayoutConstants.activityBarWidth,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active
                    ? theme.activityBarForeground
                    : Colors.transparent,
                width: WorkbenchLayoutConstants.activityBarIndicatorWidth,
              ),
            ),
          ),
          child: Icon(
            item.icon,
            color: active
                ? theme.activityBarForeground
                : theme.activityBarInactiveForeground,
            size: WorkbenchLayoutConstants.iconActivityBar,
          ),
        ),
      ),
    );
  }
}

/// Sidebar — collapsible content area next to the activity bar. Its body is
/// the active view container's stack (§spec:view-stack), built from the host's
/// typed [WorkbenchViewContainerSpec].
class _Sidebar extends StatelessWidget {
  final double width;
  final String activeLabel;
  final WorkbenchViewContainerSpec spec;
  final WorkbenchTheme theme;

  const _Sidebar({
    required this.width,
    required this.activeLabel,
    required this.spec,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      // The right border is the canonical sideBar.border seam (VS Code), drawn
      // by the sidebar like the panel draws its top border; the resize sash
      // overlays it transparently. Container (not bare DecoratedBox) so the
      // border insets the body, keeping the view container's background from
      // overdrawing the 1px seam. Null sideBarBorder → theme suppresses the
      // seam; skip the BorderSide.
      decoration: BoxDecoration(
        color: theme.sideBarBackground,
        border: theme.sideBarBorder == null
            ? null
            : Border(right: BorderSide(color: theme.sideBarBorder!)),
      ),
      child: Column(
        children: [
          Container(
            height: WorkbenchLayoutConstants.sidebarHeadingHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchLayoutConstants.spacingLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    activeLabel.toUpperCase(),
                    style: theme.sidebarOrPanelHeading,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: WorkbenchViewContainer(
              views: spec.views,
              mergeSingleView: spec.mergeSingleView,
              order: spec.order,
              onReorder: spec.onReorder,
            ),
          ),
        ],
      ),
    );
  }
}

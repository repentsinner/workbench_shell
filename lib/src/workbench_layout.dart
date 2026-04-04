import 'package:flutter/material.dart';

import 'activity_bar_item.dart';
import 'layout_constants.dart';
import 'workbench_theme.dart';

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

  /// Builds sidebar content for the given active section [id].
  /// Returns null to show nothing.
  final Widget? Function(String sectionId) sidebarBuilder;

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

  /// Initial active section ID. Defaults to the first item's ID.
  final String? initialSectionId;

  const WorkbenchLayout({
    super.key,
    required this.activityBarItems,
    required this.editor,
    required this.sidebarBuilder,
    required this.bottomPanel,
    required this.statusBar,
    this.onTogglePanel,
    this.showBottomPanel = true,
    this.initialSectionId,
  });

  @override
  State<WorkbenchLayout> createState() => _WorkbenchLayoutState();
}

class _WorkbenchLayoutState extends State<WorkbenchLayout> {
  late String _activeSectionId;
  bool _sidebarVisible = true;
  double _sidebarWidth = WorkbenchLayoutConstants.sidebarDefaultWidth;
  bool _isDraggingSidebar = false;
  bool _isDraggingPanel = false;
  double _panelHeight = WorkbenchLayoutConstants.panelDefaultHeight;

  @override
  void initState() {
    super.initState();
    _activeSectionId =
        widget.initialSectionId ??
        (widget.activityBarItems.isNotEmpty
            ? widget.activityBarItems.first.id
            : '');
  }

  void _setActiveSection(String sectionId) {
    setState(() {
      if (_activeSectionId == sectionId) {
        _sidebarVisible = !_sidebarVisible;
      } else {
        _activeSectionId = sectionId;
        _sidebarVisible = true;
      }
    });
  }

  void _onSidebarResize(double delta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + delta).clamp(
        WorkbenchLayoutConstants.sidebarMinWidth,
        WorkbenchLayoutConstants.sidebarMaxWidth,
      );
    });
  }

  void _onPanelResize(double delta) {
    setState(() {
      _panelHeight = (_panelHeight - delta).clamp(
        WorkbenchLayoutConstants.panelMinHeight,
        WorkbenchLayoutConstants.panelMaxHeight,
      );
    });
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
                    items: widget.activityBarItems,
                    activeSectionId: _activeSectionId,
                    sidebarVisible: _sidebarVisible,
                    onSectionSelected: _setActiveSection,
                    theme: theme,
                  ),

                  // Sidebar (collapsible)
                  if (_sidebarVisible) ...[
                    _Sidebar(
                      width: _sidebarWidth,
                      activeSectionId: _activeSectionId,
                      activeLabel: _activeLabelFor(_activeSectionId),
                      contentBuilder: widget.sidebarBuilder,
                      theme: theme,
                    ),
                    _buildVerticalResizer(theme),
                  ],

                  // Editor + optional bottom panel
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: widget.editor),
                        if (widget.showBottomPanel)
                          SizedBox(
                            height: _panelHeight,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: theme.panelBorder,
                                        ),
                                      ),
                                    ),
                                    child: widget.bottomPanel,
                                  ),
                                ),
                                Positioned(
                                  top: -2,
                                  left: 0,
                                  right: 0,
                                  height: 4,
                                  child: _buildHorizontalResizer(theme),
                                ),
                              ],
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

  String _activeLabelFor(String sectionId) {
    for (final item in widget.activityBarItems) {
      if (item.id == sectionId) return item.label;
    }
    return '';
  }

  Widget _buildVerticalResizer(WorkbenchTheme theme) {
    return GestureDetector(
      onPanStart: (_) => setState(() => _isDraggingSidebar = true),
      onPanUpdate: (details) => _onSidebarResize(details.delta.dx),
      onPanEnd: (_) => setState(() => _isDraggingSidebar = false),
      onPanCancel: () => setState(() => _isDraggingSidebar = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 4.0,
          color: _isDraggingSidebar
              ? theme.sashHoverBackground
              : theme.sideBarBackground,
          child: _isDraggingSidebar
              ? null
              : Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 1.0,
                    color: theme.sideBarBorder,
                    child: const SizedBox.expand(),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHorizontalResizer(WorkbenchTheme theme) {
    return GestureDetector(
      onPanStart: (_) => setState(() => _isDraggingPanel = true),
      onPanUpdate: (details) => _onPanelResize(details.delta.dy),
      onPanEnd: (_) => setState(() => _isDraggingPanel = false),
      onPanCancel: () => setState(() => _isDraggingPanel = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        child: Container(
          color: _isDraggingPanel
              ? theme.sashHoverBackground
              : Colors.transparent,
        ),
      ),
    );
  }
}

/// Activity bar — vertical icon strip on the left edge.
class _ActivityBar extends StatelessWidget {
  final List<ActivityBarItem> items;
  final String activeSectionId;
  final bool sidebarVisible;
  final ValueChanged<String> onSectionSelected;
  final WorkbenchTheme theme;

  const _ActivityBar({
    required this.items,
    required this.activeSectionId,
    required this.sidebarVisible,
    required this.onSectionSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final mainItems =
        items.where((i) => i.zone == ActivityBarZone.main).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final bottomItems =
        items.where((i) => i.zone == ActivityBarZone.bottom).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Container(
      width: WorkbenchLayoutConstants.activityBarWidth,
      decoration: BoxDecoration(
        color: theme.activityBarBackground,
        border: Border(right: BorderSide(color: theme.activityBarBorder)),
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
    final active = sidebarVisible && activeSectionId == item.id;
    return Tooltip(
      message: item.label,
      preferBelow: false,
      child: GestureDetector(
        onTap: () => onSectionSelected(item.id),
        child: Container(
          width: WorkbenchLayoutConstants.activityBarWidth,
          height: WorkbenchLayoutConstants.activityBarWidth,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active
                    ? theme.activityBarForeground
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Icon(
            item.icon,
            color: active
                ? theme.activityBarForeground
                : theme.activityBarInactiveForeground,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Sidebar — collapsible content area next to the activity bar.
class _Sidebar extends StatelessWidget {
  final double width;
  final String activeSectionId;
  final String activeLabel;
  final Widget? Function(String sectionId) contentBuilder;
  final WorkbenchTheme theme;

  const _Sidebar({
    required this.width,
    required this.activeSectionId,
    required this.activeLabel,
    required this.contentBuilder,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: theme.sideBarBackground,
      child: Column(
        children: [
          Container(
            height: 35,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
            child: contentBuilder(activeSectionId) ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

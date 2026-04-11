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
  /// Ignored when [activeSectionId] is non-null (controlled mode).
  final String? initialSectionId;

  /// Externally controlled active section ID. When non-null, the
  /// shell renders this section and delegates section changes to
  /// [onSectionChanged]. The host owns the state.
  ///
  /// When null, the shell tracks active section internally
  /// (uncontrolled mode) seeded from [initialSectionId].
  final String? activeSectionId;

  /// Called when the user requests a section change via the activity
  /// bar. The host shall update its [activeSectionId] in response.
  /// Required when [activeSectionId] is non-null.
  final ValueChanged<String>? onSectionChanged;

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
    this.activeSectionId,
    this.onSectionChanged,
  }) : assert(
         activeSectionId == null || onSectionChanged != null,
         'onSectionChanged is required when activeSectionId is provided',
       );

  @override
  State<WorkbenchLayout> createState() => _WorkbenchLayoutState();
}

class _WorkbenchLayoutState extends State<WorkbenchLayout> {
  String _internalActiveSectionId = '';
  bool _sidebarVisible = true;
  double _sidebarWidth = WorkbenchLayoutConstants.sidebarDefaultWidth;
  bool _isDraggingSidebar = false;
  bool _isDraggingPanel = false;
  double _panelHeight = WorkbenchLayoutConstants.panelDefaultHeight;

  String get _activeSectionId =>
      widget.activeSectionId ?? _internalActiveSectionId;

  @override
  void initState() {
    super.initState();
    _internalActiveSectionId =
        widget.initialSectionId ??
        (widget.activityBarItems.isNotEmpty
            ? widget.activityBarItems.first.id
            : '');
  }

  void _setActiveSection(String sectionId) {
    final current = _activeSectionId;
    if (current == sectionId) {
      setState(() {
        _sidebarVisible = !_sidebarVisible;
      });
      return;
    }
    setState(() {
      _sidebarVisible = true;
      if (widget.activeSectionId == null) {
        _internalActiveSectionId = sectionId;
      }
    });
    widget.onSectionChanged?.call(sectionId);
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
                                  // Container (not bare DecoratedBox) so
                                  // the child is inset 1px from the top
                                  // by Container-added padding. Bare
                                  // DecoratedBox paints the border behind
                                  // the child and the panel's own opaque
                                  // background widget overdraws the 1px
                                  // border strip.
                                  child: Container(
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
                                  top: -WorkbenchLayoutConstants.splitterWidth,
                                  left: 0,
                                  right: 0,
                                  height: WorkbenchLayoutConstants
                                      .resizerHitTargetSize,
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
          width: WorkbenchLayoutConstants.resizerHitTargetSize,
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
            child: contentBuilder(activeSectionId) ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

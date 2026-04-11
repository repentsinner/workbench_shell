import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'layout_constants.dart';
import 'workbench_theme.dart';

/// Descriptor for one tab in a [WorkbenchTabbedPanel].
///
/// Apps build the descriptor list and pass it to the primitive. The
/// primitive owns the [TabController], the tab strip, the close
/// button, header spacing, and the tab content area; the descriptor
/// only carries identity, label widget, and content builder.
@immutable
class WorkbenchPanelTab {
  /// Stable id used by hosts to focus a tab via
  /// [WorkbenchTabbedPanel.onRegisterFocusTab].
  final String id;

  /// Widget rendered inside the [TabBar] strip. Most callers pass a
  /// [Tab] with text; supplying a custom widget allows badges,
  /// counters, etc.
  final Widget label;

  /// Builds the body for this tab. Called once per build cycle the
  /// tab is laid out — the primitive does not cache the result.
  final WidgetBuilder contentBuilder;

  const WorkbenchPanelTab({
    required this.id,
    required this.label,
    required this.contentBuilder,
  });
}

/// Tabbed bottom-panel chrome primitive.
///
/// Owns the [TabController] and renders:
///
/// 1. A scrollable [TabBar] of the tab labels.
/// 2. A trailing close button that fires [onTogglePanel].
/// 3. A [TabBarView] hosting each descriptor's content.
///
/// Tab strip colors and indicator come from [WorkbenchTheme]
/// (`tabBarLabelColor`, `tabBarUnselectedLabelColor`,
/// `tabBarIndicatorColor`, `tabBarDividerColor`); the panel
/// background uses `panelBackground`. The host installs the theme
/// extension on the surrounding [ThemeData] — the primitive does not
/// patch [Theme] locally.
class WorkbenchTabbedPanel extends StatefulWidget {
  /// Tabs in display order. Must be non-empty.
  final List<WorkbenchPanelTab> tabs;

  /// Tab id to focus on first frame. Falls back to the first tab if
  /// the id is null or unknown.
  final String? initialTabId;

  /// Invoked when the close button is pressed.
  final VoidCallback onTogglePanel;

  /// Notified whenever the active tab changes (and once after init,
  /// after the first frame, so hosts can mirror state — e.g. for the
  /// View menu).
  final ValueChanged<String>? onActiveTabChanged;

  /// Receives a callback the host can invoke to focus a tab by id.
  /// Useful for keyboard shortcuts and View menu items.
  final void Function(ValueChanged<String> focusById)? onRegisterFocusTab;

  /// Tooltip on the close button.
  final String closeButtonTooltip;

  const WorkbenchTabbedPanel({
    super.key,
    required this.tabs,
    required this.onTogglePanel,
    this.initialTabId,
    this.onActiveTabChanged,
    this.onRegisterFocusTab,
    this.closeButtonTooltip = 'Hide Panel',
  }) : assert(
         tabs.length > 0,
         'WorkbenchTabbedPanel requires at least one tab',
       );

  @override
  State<WorkbenchTabbedPanel> createState() => _WorkbenchTabbedPanelState();
}

class _WorkbenchTabbedPanelState extends State<WorkbenchTabbedPanel>
    with TickerProviderStateMixin {
  // ignore: avoid-late-keyword
  late TabController _tabController;

  int _initialIndex() {
    final id = widget.initialTabId;
    if (id == null) return 0;
    final index = widget.tabs.indexWhere((t) => t.id == id);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      initialIndex: _initialIndex(),
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);

    widget.onRegisterFocusTab?.call(_focusById);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onActiveTabChanged?.call(widget.tabs[_tabController.index].id);
    });
  }

  @override
  void didUpdateWidget(covariant WorkbenchTabbedPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      final oldIndex = _tabController.index;
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      _tabController = TabController(
        length: widget.tabs.length,
        initialIndex: oldIndex.clamp(0, widget.tabs.length - 1),
        vsync: this,
      );
      _tabController.addListener(_onTabChanged);
    }
  }

  void _onTabChanged() {
    widget.onActiveTabChanged?.call(widget.tabs[_tabController.index].id);
  }

  void _focusById(String id) {
    final index = widget.tabs.indexWhere((t) => t.id == id);
    if (index < 0) return;
    if (_tabController.index != index) {
      _tabController.animateTo(index);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return ColoredBox(
      color: theme.panelBackground,
      child: Column(
        children: [
          const SizedBox(
            height: WorkbenchLayoutConstants.panelTabStripPaddingY,
          ),
          SizedBox(
            height: WorkbenchLayoutConstants.panelTabStripHeight,
            child: Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: theme.tabBarLabelColor,
                    unselectedLabelColor: theme.tabBarUnselectedLabelColor,
                    labelStyle: theme.sidebarOrPanelHeading.copyWith(
                      color: theme.tabBarLabelColor,
                    ),
                    unselectedLabelStyle: theme.sidebarOrPanelHeading.copyWith(
                      color: theme.tabBarUnselectedLabelColor,
                    ),
                    dividerColor: theme.tabBarDividerColor,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(color: theme.tabBarIndicatorColor),
                    ),
                    tabs: [for (final t in widget.tabs) t.label],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Symbols.close_rounded,
                    size: WorkbenchLayoutConstants.iconMd,
                  ),
                  color: theme.descriptionForeground,
                  tooltip: widget.closeButtonTooltip,
                  onPressed: widget.onTogglePanel,
                  padding: const EdgeInsets.all(
                    WorkbenchLayoutConstants.spacingXs,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: WorkbenchLayoutConstants.iconXl,
                    minHeight: WorkbenchLayoutConstants.iconXl,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: WorkbenchLayoutConstants.panelTabStripPaddingY,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (final t in widget.tabs) Builder(builder: t.contentBuilder),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

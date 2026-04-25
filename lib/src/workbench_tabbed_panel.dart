import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'layout_constants.dart';
import 'workbench_panel.dart';
import 'workbench_theme.dart';

/// Descriptor for one tab in a [WorkbenchTabbedPanel].
///
/// Apps build the descriptor list and pass it to the primitive. The
/// primitive owns the [TabController], the tab strip, the close
/// button, header spacing, and the tab content area; the descriptor
/// only carries identity, label string, optional badge, and the
/// content builder.
///
/// **Canonical rendering**. Per §3 of the workbench_shell spec, tabs
/// render uppercase regardless of how the consumer cases the input.
/// Hosts pass natural-case labels (`'Output'`, `'Debug Console'`)
/// and the shell paints `'OUTPUT'` / `'DEBUG CONSOLE'`. Hosts that
/// want a count-style badge supply [badge] as a typed
/// [PanelTabBadge] carrying the count; the shell paints the inline
/// pill in the panel-active accent colour (matching the active-tab
/// underline) — VS Code does not vary the badge by severity.
/// Badges that don't fit the count-only shape belong in the panel
/// content, not the tab strip — there is no widget escape hatch.
@immutable
class WorkbenchPanelTab {
  /// Stable id used by hosts to focus a tab via
  /// [WorkbenchTabbedPanel.onRegisterFocusTab].
  final String id;

  /// Natural-case label rendered uppercase by the shell.
  final String label;

  /// Optional inline badge rendered next to the label.
  final PanelTabBadge? badge;

  /// Builds the body for this tab. Called once per build cycle the
  /// tab is laid out — the primitive does not cache the result.
  final WidgetBuilder contentBuilder;

  const WorkbenchPanelTab({
    required this.id,
    required this.label,
    required this.contentBuilder,
    this.badge,
  });
}

/// Tabbed bottom-panel chrome primitive.
///
/// Owns the [TabController] and renders:
///
/// 1. A scrollable [TabBar] of the tab labels (uppercase, with
///    optional inline badges).
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
                    tabs: [
                      for (final t in widget.tabs)
                        Tab(child: _buildTabLabel(theme, t)),
                    ],
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
                for (final t in widget.tabs)
                  _KeepAliveTabContent(builder: t.contentBuilder),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Canonical tab label: uppercased text plus an optional severity
  /// pill. The shell owns this rendering so consumers cannot diverge
  /// (§3 canon enforcement).
  Widget _buildTabLabel(WorkbenchTheme theme, WorkbenchPanelTab tab) {
    final upper = tab.label.toUpperCase();
    final badge = tab.badge;
    if (badge == null) {
      return Text(upper);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(upper),
        const SizedBox(width: WorkbenchLayoutConstants.spacingXs),
        _badgePill(theme, badge),
      ],
    );
  }

  Widget _badgePill(WorkbenchTheme theme, PanelTabBadge badge) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.tabBarIndicatorColor,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        '${badge.count}',
        style: theme.smallText.copyWith(
          color: theme.buttonForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Wraps each [TabBarView] child so its `State` survives tab switches.
/// Without this, switching tabs disposes the inactive tab's content
/// `State` and discards anything held there (timers, scroll positions,
/// fetched data). VS Code keeps panel content alive across tab
/// switches; the shell does the same so consumer content can rely on
/// `PanelLifecycle` for pause-on-blur instead of re-initializing every
/// switch.
class _KeepAliveTabContent extends StatefulWidget {
  const _KeepAliveTabContent({required this.builder});

  final WidgetBuilder builder;

  @override
  State<_KeepAliveTabContent> createState() => _KeepAliveTabContentState();
}

class _KeepAliveTabContentState extends State<_KeepAliveTabContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context);
  }
}

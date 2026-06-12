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
/// **Canonical rendering**. Per §spec:capability-boundary of the workbench_shell spec, tabs
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

  /// Controller index that should be active for the current tab list.
  ///
  /// Honors [WorkbenchTabbedPanel.initialTabId] — which the host
  /// re-passes as its preserved active id on every build — falling back
  /// to [fallback] (clamped) when the id is null or no longer present.
  int _resolvedIndex(int fallback) {
    final id = widget.initialTabId;
    if (id != null) {
      final index = widget.tabs.indexWhere((t) => t.id == id);
      if (index >= 0) return index;
    }
    return fallback.clamp(0, widget.tabs.length - 1);
  }

  static bool _sameTabIds(
    List<WorkbenchPanelTab> a,
    List<WorkbenchPanelTab> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.tabs.length,
      initialIndex: _resolvedIndex(0),
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
    if (_sameTabIds(oldWidget.tabs, widget.tabs)) return;

    // The tab set changed (length, reorder, or swap). Re-seed the active
    // index from the host's preserved id so the rendered tab stays aligned
    // with the host's active-tab / PanelLifecycle focus state.
    final desiredIndex = _resolvedIndex(_tabController.index);

    if (oldWidget.tabs.length != widget.tabs.length) {
      _tabController.removeListener(_onTabChanged);
      _tabController.dispose();
      _tabController = TabController(
        length: widget.tabs.length,
        initialIndex: desiredIndex,
        vsync: this,
      );
      _tabController.addListener(_onTabChanged);
      // Constructing a controller does not fire the listener; notify the
      // host after the frame so it learns the active id when the
      // previously active tab was removed.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onActiveTabChanged?.call(widget.tabs[_tabController.index].id);
      });
    } else if (_tabController.index != desiredIndex) {
      // Same length but the active id moved position (reorder/swap).
      // Realign the retained controller; this fires _onTabChanged, which
      // re-emits the active id to the host.
      _tabController.index = desiredIndex;
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
          SizedBox(
            // Single 35px container (VS Code's `.part > .title`); the Row
            // flex-centres its children vertically with no extra padding.
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
                    // Suppress Material's hover/focus/pressed overlay box;
                    // the §spec:tab-strip-canon canon is a label-colour transition with no
                    // background overlay.
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(color: theme.tabBarIndicatorColor),
                    ),
                    tabs: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        Tab(
                          child: _HoverableTabLabel(
                            controller: _tabController,
                            tabIndex: i,
                            activeColor: theme.tabBarLabelColor,
                            inactiveColor: theme.tabBarUnselectedLabelColor,
                            // Hover tints inactive labels toward the
                            // active-tab text colour (the
                            // panelTitle.activeForeground accent),
                            // not the selection underline. The selection
                            // underline is a "this is the active tab"
                            // signal, while hover is "if you click this
                            // tab will become active" — visually closer
                            // to the active text colour.
                            inactiveHoverColor: theme.tabBarLabelColor,
                            child: _buildTabLabel(theme, widget.tabs[i]),
                          ),
                        ),
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
  /// (§spec:capability-boundary canon enforcement).
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
        color: theme.badgeBackground,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        '${badge.count}',
        style: theme.smallText.copyWith(
          color: theme.badgeForeground,
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

/// Wraps a tab's label widget with hover-aware label colouring.
///
/// VS Code's panel tab strip tints an inactive tab's label to the
/// active-tab indicator colour on pointer hover. The active tab's
/// label is unchanged. Implemented as a per-tab [MouseRegion] —
/// pointer enter/exit drives the local `_hovering` flag without
/// disturbing the surrounding `TabBar` hover machinery (which is
/// otherwise suppressed via `overlayColor`).
class _HoverableTabLabel extends StatefulWidget {
  final TabController controller;
  final int tabIndex;
  final Color activeColor;
  final Color inactiveColor;
  final Color inactiveHoverColor;
  final Widget child;

  const _HoverableTabLabel({
    required this.controller,
    required this.tabIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.inactiveHoverColor,
    required this.child,
  });

  @override
  State<_HoverableTabLabel> createState() => _HoverableTabLabelState();
}

class _HoverableTabLabelState extends State<_HoverableTabLabel> {
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant _HoverableTabLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // Active-state changes flip the resolved label colour even
    // without a hover event; rebuild so the wrapper paints with the
    // right colour for the new active index.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.controller.index == widget.tabIndex;
    final color = isActive
        ? widget.activeColor
        : (_hovering ? widget.inactiveHoverColor : widget.inactiveColor);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: color),
        child: IconTheme.merge(
          data: IconThemeData(color: color),
          child: widget.child,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'activity_bar_item.dart';
import 'layout_constants.dart';
import 'workbench_sash.dart';
import 'workbench_theme.dart';
import 'workbench_view_container.dart';

/// Which editor edge the primary side bar (with its activity bar) occupies
/// (§spec:sidebar-position). Named rather than a boolean because the secondary
/// side bar (§spec:secondary-sidebar) derives its edge as "opposite the
/// primary", which reads where "opposite `false`" does not.
enum WorkbenchSidebarPosition { left, right }

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

  /// Initial status-bar visibility. Used only in uncontrolled mode
  /// (when [statusBarVisible] is null); ignored otherwise. Defaults to shown.
  final bool initialStatusBarVisible;

  /// Externally controlled status-bar visibility (§spec:layout-customization).
  /// When non-null, the shell shows or hides the status bar per this value and
  /// delegates toggles to [onStatusBarVisibilityChanged]; the host owns the
  /// state (VS Code's "Status Bar" toggle is a host command). When null, the
  /// shell tracks visibility internally, seeded from [initialStatusBarVisible].
  final bool? statusBarVisible;

  /// Called when the status bar's visibility is toggled. Required when
  /// [statusBarVisible] is non-null. See [onZenModeChanged] for why the callback
  /// exists even though the shell raises no toggle of its own today.
  final ValueChanged<bool>? onStatusBarVisibilityChanged;

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

  /// Initial primary side-bar visibility. Used only in uncontrolled mode
  /// (when [sidebarVisible] is null); ignored otherwise. Defaults to shown.
  final bool initialSidebarVisible;

  /// Externally controlled primary side-bar visibility
  /// (§spec:layout-customization). When non-null, the shell shows or hides the
  /// primary side bar per this value and delegates toggles to
  /// [onSidebarVisibilityChanged]; the host owns the state (VS Code's Cmd+B is a
  /// host command). When null, the shell tracks visibility internally, seeded
  /// from [initialSidebarVisible], and toggles it when the active activity-bar
  /// icon is tapped.
  final bool? sidebarVisible;

  /// Called when the primary side bar's visibility is toggled — including the
  /// shell's own toggle when the active activity-bar icon is tapped. Required
  /// when [sidebarVisible] is non-null. Unlike the other layout toggles, the
  /// shell does raise this itself, so a controlled host must honor it to keep
  /// the activity-bar affordance working.
  final ValueChanged<bool>? onSidebarVisibilityChanged;

  /// Seed for the sidebar width in pixels (§spec:resize-geometry). The shell
  /// owns the live width — there is no controlled width property — and seeds it
  /// once at startup from this value, falling back to
  /// [WorkbenchLayoutConstants.sidebarDefaultWidth] when null. A host restores a
  /// persisted width by seeding it here and records changes via
  /// [onSidebarWidthChangeEnd].
  final double? initialSidebarWidth;

  /// Notified once when a sidebar sash drag ends, with the final clamped width
  /// (§spec:resize-geometry). Fires on release only — never per frame — so a
  /// host persists one write per drag with no debounce of its own.
  final ValueChanged<double>? onSidebarWidthChangeEnd;

  /// Seed for the bottom-panel height in pixels (§spec:resize-geometry). The
  /// shell owns the live height and seeds it once at startup from this value,
  /// falling back to [WorkbenchLayoutConstants.panelDefaultHeight] when null.
  /// Mirrors [initialSidebarWidth].
  final double? initialPanelHeight;

  /// Notified once when a panel sash drag ends, with the final clamped height
  /// (§spec:resize-geometry). Fires on release only, like
  /// [onSidebarWidthChangeEnd].
  final ValueChanged<double>? onPanelHeightChangeEnd;

  /// Initial Zen-mode state. Used only in uncontrolled mode
  /// (when [zenMode] is null); ignored otherwise.
  final bool initialZenMode;

  /// Externally controlled Zen mode (§spec:editing-modes). When non-null, the
  /// shell renders Zen on/off per this value and delegates toggles to
  /// [onZenModeChanged]; the host owns the state. When null, the shell tracks
  /// Zen internally (uncontrolled), seeded from [initialZenMode].
  ///
  /// Zen hides all chrome — activity bar, side bar, bottom panel, status bar —
  /// leaving the editor alone. It composes with [centeredLayout]: a centered
  /// editor inside an otherwise-bare Zen workbench.
  final bool? zenMode;

  /// Called when Zen mode is toggled. Required when [zenMode] is non-null.
  /// The shell itself raises no Zen toggle today (the host drives it from a
  /// menu item); the callback exists so a future in-shell affordance reports
  /// through the same controlled/uncontrolled seam as the other properties.
  final ValueChanged<bool>? onZenModeChanged;

  /// Initial centered-layout state. Used only in uncontrolled mode
  /// (when [centeredLayout] is null); ignored otherwise.
  final bool initialCenteredLayout;

  /// Externally controlled centered layout (§spec:editing-modes). When
  /// non-null, the shell renders centered on/off per this value and delegates
  /// toggles to [onCenteredLayoutChanged]; the host owns the state. When null,
  /// the shell tracks it internally (uncontrolled), seeded from
  /// [initialCenteredLayout].
  ///
  /// Centered narrows the editor between two equal margins
  /// (golden-ratio default per [WorkbenchLayoutConstants.centeredLayoutMarginRatio])
  /// and centers it, with a hairline down each inner edge; chrome remains.
  /// Dragging either margin sash resizes the editor symmetrically (both edges
  /// move, the column stays centered); double-click resets.
  final bool? centeredLayout;

  /// Called when centered layout is toggled. Required when [centeredLayout]
  /// is non-null. See [onZenModeChanged] for why the callback exists even
  /// though the shell raises no toggle of its own today.
  final ValueChanged<bool>? onCenteredLayoutChanged;

  /// Initial side-bar position. Used only in uncontrolled mode
  /// (when [sidebarPosition] is null); ignored otherwise.
  final WorkbenchSidebarPosition initialSidebarPosition;

  /// Externally controlled side-bar position (§spec:sidebar-position). When
  /// non-null, the shell renders the primary side bar (with its activity bar),
  /// its sash, and its border on this edge and delegates changes to
  /// [onSidebarPositionChanged]; the host owns the state. When null, the shell
  /// tracks the position internally (uncontrolled), seeded from
  /// [initialSidebarPosition].
  final WorkbenchSidebarPosition? sidebarPosition;

  /// Called when the side-bar position changes. Required when
  /// [sidebarPosition] is non-null. See [onZenModeChanged] for why the callback
  /// exists even though the shell raises no change of its own today.
  final ValueChanged<WorkbenchSidebarPosition>? onSidebarPositionChanged;

  /// Initial active container id for the secondary side bar
  /// (§spec:secondary-sidebar). Used only in uncontrolled mode (when
  /// [secondaryViewContainerId] is null). Empty (the default) shows no
  /// container until the host assigns one.
  final String? initialSecondaryViewContainerId;

  /// Externally controlled active container for the secondary side bar
  /// (§spec:secondary-sidebar). When non-null, the shell renders this container
  /// and delegates changes to [onSecondaryViewContainerChanged]; the host owns
  /// the state. The secondary has no activity bar — the host assigns which
  /// container it shows, so the shell raises no change of its own today (see
  /// [onZenModeChanged]). Mirrors [activeViewContainerId] for the primary.
  final String? secondaryViewContainerId;

  /// Called when the secondary side bar's active container changes. Required
  /// when [secondaryViewContainerId] is non-null.
  final ValueChanged<String>? onSecondaryViewContainerChanged;

  /// Initial secondary side-bar visibility. Used only in uncontrolled mode
  /// (when [secondarySideBarVisible] is null). Defaults to hidden, matching VS
  /// Code — the secondary is off until the host shows it.
  final bool initialSecondarySideBarVisible;

  /// Externally controlled secondary side-bar visibility
  /// (§spec:secondary-sidebar). When non-null, the shell shows or hides the
  /// secondary per this value and delegates toggles to
  /// [onSecondarySideBarVisibilityChanged]; the host owns the state (VS Code's
  /// Cmd+Alt+B is a host command). When null, the shell tracks visibility
  /// internally, seeded from [initialSecondarySideBarVisible].
  final bool? secondarySideBarVisible;

  /// Called when the secondary side bar's visibility is toggled. Required when
  /// [secondarySideBarVisible] is non-null. See [onZenModeChanged] for why the
  /// callback exists even though the shell raises no toggle of its own today.
  final ValueChanged<bool>? onSecondarySideBarVisibilityChanged;

  /// Seed for the secondary side-bar width in pixels (§spec:resize-geometry).
  /// The shell owns the live width and seeds it once at startup, falling back to
  /// [WorkbenchLayoutConstants.sidebarDefaultWidth] when null. Mirrors
  /// [initialSidebarWidth].
  final double? initialSecondarySideBarWidth;

  /// Notified once when the secondary side-bar sash drag ends, with the final
  /// clamped width (§spec:resize-geometry). Fires on release only, like
  /// [onSidebarWidthChangeEnd].
  final ValueChanged<double>? onSecondarySideBarWidthChangeEnd;

  const WorkbenchLayout({
    super.key,
    required this.activityBarItems,
    required this.editor,
    required this.containerBuilder,
    required this.bottomPanel,
    required this.statusBar,
    this.initialStatusBarVisible = true,
    this.statusBarVisible,
    this.onStatusBarVisibilityChanged,
    this.onTogglePanel,
    this.showBottomPanel = true,
    this.initialViewContainerId,
    this.activeViewContainerId,
    this.onViewContainerChanged,
    this.initialSidebarVisible = true,
    this.sidebarVisible,
    this.onSidebarVisibilityChanged,
    this.initialSidebarWidth,
    this.onSidebarWidthChangeEnd,
    this.initialPanelHeight,
    this.onPanelHeightChangeEnd,
    this.initialZenMode = false,
    this.zenMode,
    this.onZenModeChanged,
    this.initialCenteredLayout = false,
    this.centeredLayout,
    this.onCenteredLayoutChanged,
    this.initialSidebarPosition = WorkbenchSidebarPosition.left,
    this.sidebarPosition,
    this.onSidebarPositionChanged,
    this.initialSecondaryViewContainerId,
    this.secondaryViewContainerId,
    this.onSecondaryViewContainerChanged,
    this.initialSecondarySideBarVisible = false,
    this.secondarySideBarVisible,
    this.onSecondarySideBarVisibilityChanged,
    this.initialSecondarySideBarWidth,
    this.onSecondarySideBarWidthChangeEnd,
  }) : assert(
         activeViewContainerId == null || onViewContainerChanged != null,
         'onViewContainerChanged is required when activeViewContainerId is '
         'provided',
       ),
       assert(
         sidebarVisible == null || onSidebarVisibilityChanged != null,
         'onSidebarVisibilityChanged is required when sidebarVisible is provided',
       ),
       assert(
         statusBarVisible == null || onStatusBarVisibilityChanged != null,
         'onStatusBarVisibilityChanged is required when statusBarVisible is '
         'provided',
       ),
       assert(
         zenMode == null || onZenModeChanged != null,
         'onZenModeChanged is required when zenMode is provided',
       ),
       assert(
         centeredLayout == null || onCenteredLayoutChanged != null,
         'onCenteredLayoutChanged is required when centeredLayout is provided',
       ),
       assert(
         sidebarPosition == null || onSidebarPositionChanged != null,
         'onSidebarPositionChanged is required when sidebarPosition is provided',
       ),
       assert(
         secondaryViewContainerId == null ||
             onSecondaryViewContainerChanged != null,
         'onSecondaryViewContainerChanged is required when '
         'secondaryViewContainerId is provided',
       ),
       assert(
         secondarySideBarVisible == null ||
             onSecondarySideBarVisibilityChanged != null,
         'onSecondarySideBarVisibilityChanged is required when '
         'secondarySideBarVisible is provided',
       );

  @override
  State<WorkbenchLayout> createState() => _WorkbenchLayoutState();
}

class _WorkbenchLayoutState extends State<WorkbenchLayout> {
  String _internalActiveViewContainerId = '';
  late bool _internalSidebarVisible;
  late bool _internalStatusBarVisible;
  double _sidebarWidth = WorkbenchLayoutConstants.sidebarDefaultWidth;
  double _panelHeight = WorkbenchLayoutConstants.panelDefaultHeight;

  /// Container ids opened at least once, in first-open order
  /// (§spec:view-container-state). The shell builds a [WorkbenchViewContainer]
  /// per id here and keeps each alive while another is active, so pane order,
  /// expansion, and sash sizes survive switches and return. Retention is lazy:
  /// an id never selected never enters this set, so its body builders never run
  /// (the alternative — eagerly mounting every container — is rejected). The set
  /// scopes each container's State to its id by construction, so two containers
  /// reusing a view id keep independent state.
  final List<String> _openedContainerIds = [];

  // Stable identities for the three row children. Moving the side bar to the
  // opposite edge reorders the layout Row (§spec:sidebar-position); without
  // keys, Flutter's positional reconciliation can't match the top and bottom
  // children across the swap, deactivates the whole unkeyed range, and rebuilds
  // every child — discarding the side bar's retained pane State
  // (§spec:view-container-state) and the panel's maintained State. GlobalKeys
  // make Flutter move each subtree's element to its new slot instead, so the
  // bar travels rather than rebuilds.
  final GlobalKey _activityBarKey = GlobalKey();
  final GlobalKey _sidebarKey = GlobalKey();
  final GlobalKey _editorAndPanelKey = GlobalKey();

  // The secondary side bar is a fourth Row child on the editor's opposite edge
  // from the primary (§spec:secondary-sidebar). Like the other three it carries
  // a stable GlobalKey: the secondary's edge is the opposite of the primary's,
  // so swapping sidebarPosition reorders the Row, and an unkeyed secondary
  // subtree would reset its retained pane State and width on every primary move.
  // The key makes Flutter relocate the subtree across the swap instead.
  final GlobalKey _secondarySidebarKey = GlobalKey();

  // Activity-bar items partitioned by zone and sorted by sortOrder.
  // Derived once from widget.activityBarItems (which is immutable for a
  // given widget) rather than on every rebuild — the layout rebuilds on
  // every sidebar/panel drag frame.
  List<ActivityBarItem> _mainActivityItems = const [];
  List<ActivityBarItem> _bottomActivityItems = const [];

  String get _activeViewContainerId =>
      widget.activeViewContainerId ?? _internalActiveViewContainerId;

  // Primary side-bar visibility follows the same controlled/uncontrolled seam:
  // a controlled value wins, else the internal value seeded from the initial
  // flag. Unlike the other seams the shell raises its own toggle here (tapping
  // the active activity icon), routed through [_setSidebarVisible].
  bool get _sidebarVisible =>
      widget.sidebarVisible ?? _internalSidebarVisible;

  // Status-bar visibility follows the same controlled/uncontrolled seam; the
  // shell raises no toggle of its own (the host drives it from a menu item).
  bool get _statusBarVisible =>
      widget.statusBarVisible ?? _internalStatusBarVisible;

  // Secondary side bar state (§spec:secondary-sidebar), each following the same
  // controlled/uncontrolled seam as the primary: a controlled value wins, else
  // the internal value seeded from the initial flag. The shell has no secondary
  // activity bar, so it raises no container change or visibility toggle of its
  // own today — the host drives both through the controlled values.
  String _internalSecondaryActiveId = '';
  late bool _internalSecondarySideBarVisible;
  double _secondarySideBarWidth = WorkbenchLayoutConstants.sidebarDefaultWidth;

  /// Secondary container ids opened at least once, in first-open order — the
  /// secondary's own retention set, scoped independently of the primary's
  /// [_openedContainerIds] (§spec:view-container-state). Lazy: a container the
  /// secondary never shows never enters here, so its body builders never run.
  final List<String> _openedSecondaryContainerIds = [];

  String get _secondaryActiveId =>
      widget.secondaryViewContainerId ?? _internalSecondaryActiveId;
  bool get _secondarySideBarVisible =>
      widget.secondarySideBarVisible ?? _internalSecondarySideBarVisible;

  // Zen and centered layout follow the same controlled/uncontrolled seam as
  // the active view container: a controlled value wins, else the internal
  // value seeded from the initial flag. The shell raises no toggle of its own
  // today, so the internal values are seeded once and only the host mutates
  // through the controlled value.
  late bool _internalZenMode;
  late bool _internalCenteredLayout;

  // Centered-layout margin as a fraction of the editor column, the same on both
  // sides so the editor stays centered (§spec:editing-modes). VS Code drags this
  // symmetrically (its centered SplitView sets `inverseAltBehavior`, so a plain
  // drag moves both edges); a single value captures it. Golden-ratio default,
  // draggable via either margin sash, double-click resets. Internal shell state
  // for the life of the layout — not host-persisted.
  double _centeredMarginFraction =
      WorkbenchLayoutConstants.centeredLayoutMarginRatio;

  bool get _zenMode => widget.zenMode ?? _internalZenMode;
  bool get _centeredLayout => widget.centeredLayout ?? _internalCenteredLayout;

  // Side-bar position follows the same controlled/uncontrolled seam: a
  // controlled value wins, else the internal value seeded from the initial flag.
  late WorkbenchSidebarPosition _internalSidebarPosition;
  WorkbenchSidebarPosition get _sidebarPosition =>
      widget.sidebarPosition ?? _internalSidebarPosition;

  @override
  void initState() {
    super.initState();
    _internalSidebarPosition = widget.initialSidebarPosition;
    _internalActiveViewContainerId =
        widget.initialViewContainerId ??
        (widget.activityBarItems.isNotEmpty
            ? widget.activityBarItems.first.id
            : '');
    _internalSidebarVisible = widget.initialSidebarVisible;
    _internalStatusBarVisible = widget.initialStatusBarVisible;
    _internalZenMode = widget.initialZenMode;
    _internalCenteredLayout = widget.initialCenteredLayout;
    // Seed the shell-owned resize geometry once at startup (§spec:resize-geometry).
    // The shell owns the live value thereafter; the host records changes via the
    // …ChangeEnd callbacks and reseeds from initial… on a fresh layout.
    _sidebarWidth =
        widget.initialSidebarWidth ??
        WorkbenchLayoutConstants.sidebarDefaultWidth;
    _panelHeight =
        widget.initialPanelHeight ??
        WorkbenchLayoutConstants.panelDefaultHeight;
    // Seed the secondary side bar (§spec:secondary-sidebar), mirroring the
    // primary's container/visibility/width seeding above.
    _internalSecondaryActiveId = widget.initialSecondaryViewContainerId ?? '';
    _internalSecondarySideBarVisible = widget.initialSecondarySideBarVisible;
    _secondarySideBarWidth =
        widget.initialSecondarySideBarWidth ??
        WorkbenchLayoutConstants.sidebarDefaultWidth;
    _partitionActivityItems();
  }

  /// Record [containerId] as opened in [opened] so the shell builds and retains
  /// it. Empty ids (no active container) contribute nothing. Shared by the
  /// primary and secondary side bars, each with its own retention set.
  void _markOpened(String containerId, List<String> opened) {
    if (containerId.isEmpty) return;
    if (!opened.contains(containerId)) opened.add(containerId);
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

  /// Show or hide the primary side bar through the controlled/uncontrolled
  /// seam: mutate internal state only in uncontrolled mode, and always notify
  /// the host so a controlled parent can drive the value. No-op when the
  /// visibility is unchanged, so revealing an already-open bar raises nothing.
  void _setSidebarVisible(bool visible) {
    if (_sidebarVisible == visible) return;
    setState(() {
      if (widget.sidebarVisible == null) {
        _internalSidebarVisible = visible;
      }
    });
    widget.onSidebarVisibilityChanged?.call(visible);
  }

  void _setActiveViewContainer(String containerId) {
    final current = _activeViewContainerId;
    if (current == containerId) {
      _setSidebarVisible(!_sidebarVisible);
      return;
    }
    setState(() {
      if (widget.activeViewContainerId == null) {
        _internalActiveViewContainerId = containerId;
      }
    });
    // Selecting a different container always reveals the side bar.
    _setSidebarVisible(true);
    widget.onViewContainerChanged?.call(containerId);
  }


  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;

    // Mark the active container opened on every build — the single point that
    // records retention. Idempotent and build-time, so it covers the initial
    // active container, shell-driven activity-bar taps, and host-driven
    // (controlled) container changes alike without a separate call at each.
    _markOpened(_activeViewContainerId, _openedContainerIds);
    // The secondary container is opened only while the secondary is visible, so
    // a hidden secondary builds nothing — its retention stays lazy
    // (§spec:secondary-sidebar). Once opened it survives a later hide/show.
    if (_secondarySideBarVisible) {
      _markOpened(_secondaryActiveId, _openedSecondaryContainerIds);
    }

    // Centered layout narrows the editor between two proportional margins and
    // centers it; chrome stays. Applied to the editor alone so the bottom panel
    // keeps spanning the editor column (§spec:editing-modes /
    // §spec:panel-alignment default).
    final editorContent = _centeredLayout
        ? _buildCenteredEditor(theme)
        : widget.editor;

    // Zen mode hides all chrome — activity bar, side bar, panel, status bar —
    // leaving the editor (centered when centered layout also applies). It is a
    // composition choice, not a separate layout: the same editorContent renders
    // bare, so the two modes compose without special-casing.
    if (_zenMode) {
      return Scaffold(
        backgroundColor: theme.editorBackground,
        body: SafeArea(child: editorContent),
      );
    }

    final onRight = _sidebarPosition == WorkbenchSidebarPosition.right;

    final activityBar = _ActivityBar(
      key: _activityBarKey,
      mainItems: _mainActivityItems,
      bottomItems: _bottomActivityItems,
      activeViewContainerId: _activeViewContainerId,
      sidebarVisible: _sidebarVisible,
      onViewContainerSelected: _setActiveViewContainer,
      position: _sidebarPosition,
      theme: theme,
    );

    // Primary side bar (collapsible), on the activity bar's edge.
    final sidebar = _buildSideBar(
      key: _sidebarKey,
      visible: _sidebarVisible,
      width: _sidebarWidth,
      activeId: _activeViewContainerId,
      openedContainerIds: _openedContainerIds,
      position: _sidebarPosition,
      onWidth: (next) => setState(() => _sidebarWidth = next),
      onChangeEnd: widget.onSidebarWidthChangeEnd,
      theme: theme,
    );

    // Secondary side bar (§spec:secondary-sidebar): a second collapsible bar on
    // the editor's opposite edge from the primary, hosting host-assigned
    // containers through the same containerBuilder path. Its position is the
    // opposite of the primary's, so its border and sash face the editor from the
    // other side. It has no activity bar — the host owns its active container
    // and visibility.
    final secondaryPosition = onRight
        ? WorkbenchSidebarPosition.left
        : WorkbenchSidebarPosition.right;
    final secondarySidebar = _buildSideBar(
      key: _secondarySidebarKey,
      visible: _secondarySideBarVisible,
      width: _secondarySideBarWidth,
      activeId: _secondaryActiveId,
      openedContainerIds: _openedSecondaryContainerIds,
      position: secondaryPosition,
      onWidth: (next) => setState(() => _secondarySideBarWidth = next),
      onChangeEnd: widget.onSecondarySideBarWidthChangeEnd,
      theme: theme,
    );

    // Editor + bottom panel. The panel is wrapped in a
    // Visibility(maintainState: true) so its widget subtree (and any State it
    // owns — timers, scroll positions, fetched data) survives hide/show cycles.
    // Without this, toggling showBottomPanel disposes the entire panel tree and
    // discards content state every cycle.
    final editorAndPanel = Expanded(
      key: _editorAndPanelKey,
      child: Column(
        children: [
          Expanded(child: editorContent),
          Visibility(
            visible: widget.showBottomPanel,
            maintainState: true,
            maintainAnimation: true,
            child: SizedBox(
              height: _panelHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    // Container (not bare DecoratedBox) so the child is inset
                    // 1px from the top by Container-added padding. Bare
                    // DecoratedBox paints the border behind the child and the
                    // panel's own opaque background widget overdraws the 1px
                    // border strip.
                    //
                    // Null panelBorder → theme explicitly suppresses the seam;
                    // skip the BorderSide entirely rather than falling back to a
                    // neighboring color.
                    child: Container(
                      decoration: BoxDecoration(
                        border: theme.panelBorder == null
                            ? null
                            : Border(
                                top: BorderSide(color: theme.panelBorder!),
                              ),
                      ),
                      child: widget.bottomPanel,
                    ),
                  ),
                  Positioned(
                    // Sit the sash fully inside the panel (top: 0), like the
                    // view-stack pane sashes. An overhang above the panel's top
                    // edge is clipped by this Stack's hardEdge bound, halving the
                    // painted highlight band; sitting inside keeps every seam's
                    // sash the same canonical width. Height owned by
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
    );

    // The activity bar and primary side bar travel together to the selected
    // edge; the editor takes the rest (§spec:sidebar-position). On the right the
    // order mirrors so the activity bar stays outermost against the window edge.
    // The secondary side bar (§spec:secondary-sidebar) sits outermost on the
    // editor's opposite edge — the now-free side — so it always faces the
    // primary across the editor. Each child is keyed, so flipping the primary
    // reorders the Row and relocates every subtree rather than rebuilding it.
    final rowChildren = onRight
        ? [secondarySidebar, editorAndPanel, sidebar, activityBar]
        : [activityBar, sidebar, editorAndPanel, secondarySidebar];

    return Scaffold(
      backgroundColor: theme.editorBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: Row(children: rowChildren)),
            // Hidden status bar yields its strip to the workbench above; Zen
            // mode (handled earlier) hides it wholesale alongside all chrome.
            if (_statusBarVisible) widget.statusBar,
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

  /// Build a collapsible side bar shared by the primary and secondary bars
  /// (§spec:secondary-sidebar). The bar is always kept in the tree — Offstage
  /// when hidden rather than removed — so its retained container subtrees (and
  /// their shell-owned pane State) survive a hide/show cycle, not only a
  /// container switch (§spec:view-container-state). Offstage takes no layout
  /// space when hidden, so the editor still fills the row. A resize sash overlays
  /// the bar's editor-facing edge — the right when on the left, the left when on
  /// the right (§spec:sidebar-position) — transparent at rest, mirroring the
  /// panel and view-stack pane sashes.
  Widget _buildSideBar({
    required GlobalKey key,
    required bool visible,
    required double width,
    required String activeId,
    required List<String> openedContainerIds,
    required WorkbenchSidebarPosition position,
    required ValueChanged<double> onWidth,
    required ValueChanged<double>? onChangeEnd,
    required WorkbenchTheme theme,
  }) {
    final onRight = position == WorkbenchSidebarPosition.right;
    return Offstage(
      key: key,
      offstage: !visible,
      child: TickerMode(
        enabled: visible,
        child: Stack(
          children: [
            _Sidebar(
              width: width,
              activeLabel: _activeLabelFor(activeId),
              activeContainerId: activeId,
              openedContainerIds: openedContainerIds,
              containerBuilder: widget.containerBuilder,
              position: position,
              theme: theme,
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: onRight ? 0 : null,
              right: onRight ? null : 0,
              child: _buildSidebarResizer(
                growSign: onRight ? -1 : 1,
                width: width,
                onWidth: onWidth,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a side-bar resize sash shared by the primary and secondary bars
  /// (§spec:secondary-sidebar). The seam grows its bar toward the editor:
  /// dragging right when the bar is on the left (growSign +1), dragging left
  /// when it is on the right (growSign -1) (§spec:sidebar-position). The sash is
  /// transparent at rest like the panel/view-pane sashes — the seam is the
  /// bar's own border, which this overlays. WorkbenchSash owns the canonical
  /// drag, directional cursor, and hover/drag highlight (§spec:workbench-layout).
  /// The shell owns the live [width]: [onWidth] permutes it each frame so the
  /// tree relayouts, and [onChangeEnd] commits the final value once on release
  /// for persistence (§spec:resize-geometry). No per-frame host callback.
  Widget _buildSidebarResizer({
    required double growSign,
    required double width,
    required ValueChanged<double> onWidth,
    required ValueChanged<double>? onChangeEnd,
  }) {
    return WorkbenchSash(
      axis: Axis.horizontal,
      value: width,
      min: WorkbenchLayoutConstants.sidebarMinWidth,
      max: WorkbenchLayoutConstants.sidebarMaxWidth,
      growSign: growSign,
      onChanged: onWidth,
      onChangeEnd: onChangeEnd,
      // Double-click resets the seam to its default and commits it through the
      // same change-end seam, so the host persists the reset (§spec:workbench-layout,
      // VS Code's `onDidSashReset` → part preferred size).
      onReset: () {
        const reset = WorkbenchLayoutConstants.sidebarDefaultWidth;
        onWidth(reset);
        onChangeEnd?.call(reset);
      },
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
      // Shell-owned, mirroring the sidebar resizer above (§spec:resize-geometry).
      onChanged: (next) => setState(() => _panelHeight = next),
      onChangeEnd: widget.onPanelHeightChangeEnd,
      // Reset to the default height on double-click, committed like the sidebar
      // (§spec:workbench-layout).
      onReset: () {
        const reset = WorkbenchLayoutConstants.panelDefaultHeight;
        setState(() => _panelHeight = reset);
        widget.onPanelHeightChangeEnd?.call(reset);
      },
      child: const SizedBox.expand(),
    );
  }

  /// Centered layout (§spec:editing-modes): the editor narrows between two equal
  /// margins and centers. A hairline (`editorGroup.border`) runs down each inner
  /// edge, and a draggable sash overlays each — dragging either resizes the
  /// editor symmetrically (both edges move, the column stays centered, matching
  /// VS Code's `inverseAltBehavior` SplitView), and double-click resets to the
  /// golden-ratio default. The margins are the bare editor background. Below
  /// [WorkbenchLayoutConstants.centeredLayoutMinEditorWidth] the column is too
  /// narrow to center, so the editor fills it (VS Code's auto-resize).
  Widget _buildCenteredEditor(WorkbenchTheme theme) {
    final border = theme.editorGroupBorder;
    const minEditor = WorkbenchLayoutConstants.centeredLayoutMinEditorWidth;
    const sashSize = WorkbenchLayoutConstants.sashSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (!w.isFinite || w <= minEditor) return widget.editor;

        // One margin width, equal on both sides (the editor stays centered),
        // clamped so the editor keeps its minimum width.
        final double maxMargin = (w - minEditor) / 2;
        final double margin = (_centeredMarginFraction * w)
            .clamp(0.0, maxMargin)
            .toDouble();
        final double editorWidth = w - 2 * margin;

        return Stack(
          children: [
            // Editor, narrowed and centered, with a hairline down each inner
            // edge. Container (not bare DecoratedBox) so its border padding
            // insets the editor 1px, keeping an opaque host editor from
            // overdrawing the seam — as the bottom panel does with its border.
            Positioned(
              left: margin,
              width: editorWidth,
              top: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  border: border == null
                      ? null
                      : Border.symmetric(vertical: BorderSide(color: border)),
                ),
                child: widget.editor,
              ),
            ),
            // Draggable margin sashes overlay the two hairlines (transparent at
            // rest like every seam), centered on each boundary. Both drive the
            // single margin, so either one resizes the editor symmetrically.
            Positioned(
              top: 0,
              bottom: 0,
              left: margin - sashSize / 2,
              child: _buildCenteredSash(
                isLeft: true,
                width: w,
                margin: margin,
                maxMargin: maxMargin,
              ),
            ),
            Positioned(
              top: 0,
              bottom: 0,
              left: (w - margin) - sashSize / 2,
              child: _buildCenteredSash(
                isLeft: false,
                width: w,
                margin: margin,
                maxMargin: maxMargin,
              ),
            ),
          ],
        );
      },
    );
  }

  /// One centered-layout margin sash. Both sashes drive the single shared
  /// margin, so dragging either resizes the editor symmetrically. The left edge
  /// follows the pointer when it moves right (growSign +1); the right edge
  /// follows when it moves right too, which shrinks the margin (growSign -1).
  /// Double-click resets to the golden-ratio default (§spec:editing-modes, VS
  /// Code `onDidSashReset`).
  Widget _buildCenteredSash({
    required bool isLeft,
    required double width,
    required double margin,
    required double maxMargin,
  }) {
    return WorkbenchSash(
      axis: Axis.horizontal,
      value: margin,
      max: maxMargin < 0 ? 0 : maxMargin,
      growSign: isLeft ? 1 : -1,
      onChanged: (next) => setState(
        () => _centeredMarginFraction = width == 0 ? 0.0 : next / width,
      ),
      onReset: () => setState(
        () => _centeredMarginFraction =
            WorkbenchLayoutConstants.centeredLayoutMarginRatio,
      ),
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
  final WorkbenchSidebarPosition position;
  final WorkbenchTheme theme;

  const _ActivityBar({
    super.key,
    required this.mainItems,
    required this.bottomItems,
    required this.activeViewContainerId,
    required this.sidebarVisible,
    required this.onViewContainerSelected,
    required this.position,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // The separator border faces the side bar — the activity bar's right edge
    // when the bar is on the left, its left edge when on the right
    // (§spec:sidebar-position). Null activityBarBorder → theme registry default
    // (modern themes); skip the BorderSide entirely instead of a flat-grey
    // fallback.
    final onRight = position == WorkbenchSidebarPosition.right;
    final borderSide = theme.activityBarBorder == null
        ? null
        : BorderSide(color: theme.activityBarBorder!);
    return Container(
      width: WorkbenchLayoutConstants.activityBarWidth,
      decoration: BoxDecoration(
        color: theme.activityBarBackground,
        border: borderSide == null
            ? null
            : Border(
                left: onRight ? borderSide : BorderSide.none,
                right: onRight ? BorderSide.none : borderSide,
              ),
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
    // The active indicator sits on the activity bar's outer edge, away from the
    // side bar — left edge on the left, right edge on the right
    // (§spec:sidebar-position, VS Code's mirrored `activeBorder`).
    final indicator = BorderSide(
      color: active ? theme.activityBarForeground : Colors.transparent,
      width: WorkbenchLayoutConstants.activityBarIndicatorWidth,
    );
    final onRight = position == WorkbenchSidebarPosition.right;
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
              left: onRight ? BorderSide.none : indicator,
              right: onRight ? indicator : BorderSide.none,
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

/// Sidebar — collapsible content area next to the activity bar. The heading
/// tracks the active view container; the body is a retained stack of every
/// opened container's view stack (§spec:view-container-state), only the active
/// one visible, the rest kept alive offstage so their pane order, expansion,
/// and sash sizes survive switches.
class _Sidebar extends StatelessWidget {
  final double width;
  final String activeLabel;
  final String activeContainerId;
  final List<String> openedContainerIds;
  final WorkbenchViewContainerSpec Function(String containerId) containerBuilder;
  final WorkbenchSidebarPosition position;
  final WorkbenchTheme theme;

  const _Sidebar({
    required this.width,
    required this.activeLabel,
    required this.activeContainerId,
    required this.openedContainerIds,
    required this.containerBuilder,
    required this.position,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    // The editor-facing border is the canonical sideBar.border seam (VS Code),
    // drawn by the sidebar like the panel draws its top border; the resize sash
    // overlays it transparently. It is the right edge when the bar is on the
    // left, the left edge when on the right (§spec:sidebar-position). Container
    // (not bare DecoratedBox) so the border insets the body, keeping the view
    // container's background from overdrawing the 1px seam. Null sideBarBorder →
    // theme suppresses the seam; skip the BorderSide.
    final onRight = position == WorkbenchSidebarPosition.right;
    final borderSide = theme.sideBarBorder == null
        ? null
        : BorderSide(color: theme.sideBarBorder!);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.sideBarBackground,
        border: borderSide == null
            ? null
            : Border(
                left: onRight ? borderSide : BorderSide.none,
                right: onRight ? BorderSide.none : borderSide,
              ),
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
            // One WorkbenchViewContainer per opened id, each in a stable Stack
            // slot keyed by container id so its element/State identity is per
            // container. Only the active id is onstage and ticking; the rest are
            // kept in the tree (so their pane State persists) but offstage and
            // with tickers disabled, mirroring VS Code detaching a hidden
            // viewlet's DOM. Un-opened ids contribute no child, so their body
            // builders never run — retention is lazy (§spec:view-container-state).
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final id in openedContainerIds)
                  _RetainedContainer(
                    key: ValueKey(id),
                    active: id == activeContainerId,
                    spec: containerBuilder(id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One retained view container in the sidebar's body stack
/// (§spec:view-container-state). Hidden containers stay in the tree — so the
/// [WorkbenchViewContainer]'s shell-owned State (pane order, expansion, sash
/// sizes) survives — but render offstage with tickers disabled so their bodies'
/// timers and animations pause while another container is active.
class _RetainedContainer extends StatelessWidget {
  final bool active;
  final WorkbenchViewContainerSpec spec;

  const _RetainedContainer({
    super.key,
    required this.active,
    required this.spec,
  });

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !active,
      child: TickerMode(
        enabled: active,
        child: WorkbenchViewContainer(
          views: spec.views,
          mergeSingleView: spec.mergeSingleView,
          order: spec.order,
          onReorder: spec.onReorder,
          initialSizes: spec.initialSizes,
          onSizesChangeEnd: spec.onSizesChangeEnd,
        ),
      ),
    );
  }
}

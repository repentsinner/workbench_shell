import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'activity_bar_item.dart';
import 'layout_constants.dart';
import 'workbench_sash.dart';
import 'workbench_theme.dart';
import 'workbench_view_container.dart';
import 'workbench_view_menu.dart';

/// Which editor edge the primary side bar (with its activity bar) occupies
/// (§spec:sidebar-position). Named rather than a boolean because the secondary
/// side bar (§spec:secondary-sidebar) derives its edge as "opposite the
/// primary", which reads where "opposite `false`" does not.
enum WorkbenchSidebarPosition { left, right }

/// How the bottom panel aligns across the workbench width (§spec:panel-alignment):
/// `center` spans the editor only (both side bars run full height past it — the
/// §spec:workbench-layout default), `justify` spans the full width (neither side
/// bar runs past it), `left` abuts the left edge's bar (which runs full height)
/// and spans the rest, and `right` mirrors `left`. Each value is two booleans —
/// does the left-edge bar group and the right-edge bar group run full height
/// (outside the panel's band) or stop at the panel's top (inside it) — realized
/// by *where the panel sits in the widget tree*, not a layout solver.
enum WorkbenchPanelAlignment { center, justify, left, right }

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

  /// Initial panel alignment. Used only in uncontrolled mode (when
  /// [panelAlignment] is null); ignored otherwise. Defaults to
  /// [WorkbenchPanelAlignment.center], the §spec:workbench-layout default.
  final WorkbenchPanelAlignment initialPanelAlignment;

  /// Externally controlled panel alignment (§spec:panel-alignment). When
  /// non-null, the shell re-parents the bottom panel between the editor column
  /// and the outer column per this value and delegates changes to
  /// [onPanelAlignmentChanged]; the host owns the state. When null, the shell
  /// tracks the alignment internally (uncontrolled), seeded from
  /// [initialPanelAlignment]. The four values reduce to two booleans — whether
  /// each side bar runs full height past the panel or stops at its top —
  /// realized by where the panel sits in the widget tree, not a layout solver.
  final WorkbenchPanelAlignment? panelAlignment;

  /// Called when the panel alignment changes. Required when [panelAlignment] is
  /// non-null. See [onZenModeChanged] for why the callback exists even though
  /// the shell raises no change of its own today.
  final ValueChanged<WorkbenchPanelAlignment>? onPanelAlignmentChanged;

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
    this.initialPanelAlignment = WorkbenchPanelAlignment.center,
    this.panelAlignment,
    this.onPanelAlignmentChanged,
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
         panelAlignment == null || onPanelAlignmentChanged != null,
         'onPanelAlignmentChanged is required when panelAlignment is provided',
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

  /// Per-view visibility, the shell's source of truth for the Views overflow
  /// (§spec:view-container-title) — the port of VS Code's `ViewContainerModel`
  /// (`isVisible`/`setVisible`, persisted per container id). Keyed by container
  /// id → the set of *hidden* uncontrolled view ids. Living here, above the
  /// retained `WorkbenchViewContainer`s, makes it independent of which container
  /// is active, so a hidden/shown view survives activity-bar switches like order
  /// and expansion (§spec:view-container-state). Absent id = not yet seeded;
  /// absent view = visible. Controlled views (a descriptor with
  /// `onVisibleChanged`) never enter this map — the host owns their visibility.
  final Map<String, Set<String>> _hiddenViewIds = {};

  /// The live hidden-id set for [containerId], seeded once from descriptors that
  /// start hidden (`visible == false`) and are shell-owned (no `onVisibleChanged`).
  Set<String> _hiddenStore(
    String containerId,
    List<WorkbenchViewDescriptor> views,
  ) {
    return _hiddenViewIds.putIfAbsent(containerId, () {
      return {
        for (final view in views)
          if (view.onVisibleChanged == null && !view.visible) view.id,
      };
    });
  }

  /// Whether [view] in [containerId] is currently visible. A controlled view
  /// reads its host-owned `visible`; an uncontrolled one is visible unless the
  /// shell store hides it.
  bool _isViewVisible(
    String containerId,
    WorkbenchViewDescriptor view,
    List<WorkbenchViewDescriptor> views,
  ) {
    if (view.onVisibleChanged != null) return view.visible;
    return !_hiddenStore(containerId, views).contains(view.id);
  }

  /// The resolved hidden-id set for [containerId]'s [views], combining the
  /// shell store (uncontrolled) with controlled views the host marks hidden.
  /// Passed to the container so it drops those panes from the stack.
  Set<String> _resolvedHidden(
    String containerId,
    List<WorkbenchViewDescriptor> views,
  ) {
    return {
      for (final view in views)
        if (!_isViewVisible(containerId, view, views)) view.id,
    };
  }

  /// Toggle [view]'s visibility from the Views overflow. A controlled view
  /// reports the requested state through its callback without self-mutating; an
  /// uncontrolled one flips the shell store and rebuilds. No-op for a
  /// non-hideable view (`canHide == false`).
  void _toggleViewVisible(
    String containerId,
    WorkbenchViewDescriptor view,
    List<WorkbenchViewDescriptor> views,
  ) {
    if (!view.canHide) return;
    final nowVisible = _isViewVisible(containerId, view, views);
    if (view.onVisibleChanged != null) {
      view.onVisibleChanged!(!nowVisible);
      return;
    }
    setState(() {
      final hidden = _hiddenStore(containerId, views);
      if (nowVisible) {
        hidden.add(view.id);
      } else {
        hidden.remove(view.id);
      }
    });
  }

  // Stable identities for the workbench's structural children. Two composition
  // choices reorder or re-parent them: moving the side bar to the opposite edge
  // reorders the layout Row (§spec:sidebar-position), and changing the panel
  // alignment re-parents a bar between the outer row and the panel's band column
  // (§spec:panel-alignment). Without keys, Flutter's positional reconciliation
  // can't match a child across the move, deactivates the unkeyed range, and
  // rebuilds every child — discarding the side bar's retained pane State
  // (§spec:view-container-state) and the panel's maintained State. GlobalKeys
  // make Flutter move each subtree's element to its new slot instead, so the
  // bar travels rather than rebuilds. The band key keeps the editor and panel
  // identity stable as bars re-parent into and out of the band.
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

  // Panel alignment follows the same controlled/uncontrolled seam: a controlled
  // value wins, else the internal value seeded from the initial flag. The shell
  // raises no change of its own today (the host drives it from a menu item).
  late WorkbenchPanelAlignment _internalPanelAlignment;
  WorkbenchPanelAlignment get _panelAlignment =>
      widget.panelAlignment ?? _internalPanelAlignment;

  @override
  void initState() {
    super.initState();
    _internalSidebarPosition = widget.initialSidebarPosition;
    _internalPanelAlignment = widget.initialPanelAlignment;
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

    // Editor area, filling the inner row's free space beside any side bars the
    // panel runs beneath.
    final editorArea = Expanded(child: editorContent);

    // Bottom panel, wrapped in a Visibility(maintainState: true) so its widget
    // subtree (and any State it owns — timers, scroll positions, fetched data)
    // survives hide/show cycles. Without this, toggling showBottomPanel disposes
    // the entire panel tree and discards content state every cycle.
    final panel = Visibility(
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
                      : Border(top: BorderSide(color: theme.panelBorder!)),
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
    );

    // The activity bar and primary side bar travel together to the selected
    // edge; the secondary side bar sits on the editor's opposite edge
    // (§spec:sidebar-position, §spec:secondary-sidebar). On the right the order
    // mirrors so the activity bar stays outermost against the window edge.
    // Grouped by screen edge so panel alignment can place each group inside or
    // outside the panel's horizontal band.
    final leftGroup = onRight ? [secondarySidebar] : [activityBar, sidebar];
    final rightGroup = onRight ? [sidebar, activityBar] : [secondarySidebar];

    // Panel alignment reduces to one question per screen edge: does that edge's
    // bar group run full height (outside the panel's band) or stop at the
    // panel's top (inside it)? Center = both outside; justify = both inside;
    // left/right = one of each. Two booleans, realized by where the panel sits
    // in the widget tree — not a layout solver (§spec:panel-alignment).
    final (leftInside, rightInside) = switch (_panelAlignment) {
      WorkbenchPanelAlignment.center => (false, false),
      WorkbenchPanelAlignment.justify => (true, true),
      WorkbenchPanelAlignment.left => (false, true),
      WorkbenchPanelAlignment.right => (true, false),
    };

    // The band column holds the editor (beside any "inside" bars) above the
    // panel, so the panel spans the band's width. "Outside" bars are siblings of
    // the band in the outer row, running full height past the panel. The band
    // and every bar carry stable keys, so changing the alignment re-parents bars
    // between the inner and outer rows by relocating their subtrees rather than
    // rebuilding them — the retained pane and panel State survives the move
    // (§spec:view-container-state, mirroring §spec:sidebar-position).
    final bandColumn = Expanded(
      key: _editorAndPanelKey,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (leftInside) ...leftGroup,
                editorArea,
                if (rightInside) ...rightGroup,
              ],
            ),
          ),
          panel,
        ],
      ),
    );

    final rowChildren = [
      if (!leftInside) ...leftGroup,
      bandColumn,
      if (!rightInside) ...rightGroup,
    ];

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
              resolvedHidden: _resolvedHidden,
              toggleViewVisible: _toggleViewVisible,
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

  /// Resolved hidden-id set for a container, from the shell visibility store
  /// (§spec:view-container-title). Drives both the title's Views checkboxes and
  /// the dropped panes in each container.
  final Set<String> Function(String containerId, List<WorkbenchViewDescriptor>)
  resolvedHidden;

  /// Toggle a view's visibility from the Views overflow.
  final void Function(
    String containerId,
    WorkbenchViewDescriptor,
    List<WorkbenchViewDescriptor>,
  )
  toggleViewVisible;

  final WorkbenchSidebarPosition position;
  final WorkbenchTheme theme;

  const _Sidebar({
    required this.width,
    required this.activeLabel,
    required this.activeContainerId,
    required this.openedContainerIds,
    required this.containerBuilder,
    required this.resolvedHidden,
    required this.toggleViewVisible,
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
          _buildTitle(context),
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
                for (final id in openedContainerIds) _retainedContainer(id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One retained container slot. Computes the spec once so the spec and its
  /// resolved hidden set come from a single `containerBuilder` call.
  Widget _retainedContainer(String id) {
    final spec = containerBuilder(id);
    return _RetainedContainer(
      key: ValueKey(id),
      active: id == activeContainerId,
      spec: spec,
      hiddenViewIds: resolvedHidden(id, spec.views),
    );
  }

  /// The shared composite-title chrome (§spec:view-container-title), the port of
  /// VS Code's single `CompositePart` title area re-rendered for the active
  /// container — not per-container DOM. It carries the active container's label,
  /// any host inline title actions, and a right-aligned `⋯` overflow whose first
  /// group is the shell-built Views toggles. Persistent chrome: the `⋯` shows
  /// whenever the active container has a hideable view or host overflow entries.
  Widget _buildTitle(BuildContext context) {
    final spec = containerBuilder(activeContainerId);
    final showOverflow =
        spec.views.any((v) => v.canHide) || spec.titleOverflowEntries.isNotEmpty;
    return Container(
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
          // Host inline title actions, persistent (the composite title is
          // always-shown chrome), placed left of the overflow button.
          ...spec.titleActions,
          if (showOverflow) _buildOverflowButton(context, spec),
        ],
      ),
    );
  }

  /// The `⋯` overflow button and its in-window Material popup
  /// (§spec:view-container-title). The popup is never the macOS system menu bar,
  /// so the Views checkboxes draw real check marks on every platform — the
  /// `PlatformMenuItem` degradation (§spec:menu-model) does not apply. Themed
  /// through the same [workbenchMenuThemeData] the View menu bar uses.
  Widget _buildOverflowButton(
    BuildContext context,
    WorkbenchViewContainerSpec spec,
  ) {
    final hidden = resolvedHidden(activeContainerId, spec.views);
    final viewItems = <Widget>[
      for (final view in spec.views)
        CheckboxMenuButton(
          value: !hidden.contains(view.id),
          // Keep the popup open after a toggle so the user can hide several
          // views and watch each check update live (VS Code's Views submenu).
          closeOnActivate: false,
          onChanged: view.canHide
              ? (_) => toggleViewVisible(activeContainerId, view, spec.views)
              : null,
          child: Text(view.title),
        ),
    ];
    // VS Code dissolves the `Views` submenu and inlines the toggles when it is
    // the container title's only secondary action, keeping a nested `Views ▸`
    // submenu only when host overflow entries share the popup (panecomposite.ts
    // getSecondaryActions, the `length === 1` branch).
    final menuChildren = spec.titleOverflowEntries.isEmpty
        ? viewItems
        : <Widget>[
            SubmenuButton(menuChildren: viewItems, child: const Text('Views')),
            const Divider(height: 1),
            ...buildMaterialMenuChildren(context, spec.titleOverflowEntries),
          ];
    return Theme(
      data: workbenchMenuThemeData(context),
      child: MenuAnchor(
        menuChildren: menuChildren,
        builder: (context, controller, child) => IconButton(
          icon: const Icon(
            Symbols.more_horiz,
            size: WorkbenchLayoutConstants.iconMd,
          ),
          color: theme.descriptionForeground,
          tooltip: 'Views and More Actions…',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
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

  /// Views resolved hidden by the shell store (§spec:view-container-title);
  /// dropped from the stack while keeping their order slot.
  final Set<String> hiddenViewIds;

  const _RetainedContainer({
    super.key,
    required this.active,
    required this.spec,
    required this.hiddenViewIds,
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
          hiddenViewIds: hiddenViewIds,
        ),
      ),
    );
  }
}

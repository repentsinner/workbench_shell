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
  }) : assert(
         activeViewContainerId == null || onViewContainerChanged != null,
         'onViewContainerChanged is required when activeViewContainerId is '
         'provided',
       ),
       assert(
         zenMode == null || onZenModeChanged != null,
         'onZenModeChanged is required when zenMode is provided',
       ),
       assert(
         centeredLayout == null || onCenteredLayoutChanged != null,
         'onCenteredLayoutChanged is required when centeredLayout is provided',
       );

  @override
  State<WorkbenchLayout> createState() => _WorkbenchLayoutState();
}

class _WorkbenchLayoutState extends State<WorkbenchLayout> {
  String _internalActiveViewContainerId = '';
  bool _sidebarVisible = true;
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

  // Activity-bar items partitioned by zone and sorted by sortOrder.
  // Derived once from widget.activityBarItems (which is immutable for a
  // given widget) rather than on every rebuild — the layout rebuilds on
  // every sidebar/panel drag frame.
  List<ActivityBarItem> _mainActivityItems = const [];
  List<ActivityBarItem> _bottomActivityItems = const [];

  String get _activeViewContainerId =>
      widget.activeViewContainerId ?? _internalActiveViewContainerId;

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

  @override
  void initState() {
    super.initState();
    _internalActiveViewContainerId =
        widget.initialViewContainerId ??
        (widget.activityBarItems.isNotEmpty
            ? widget.activityBarItems.first.id
            : '');
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
    _partitionActivityItems();
  }

  /// Record [containerId] as opened so the shell builds and retains it. Empty
  /// ids (no activity-bar items) contribute nothing.
  void _markOpened(String containerId) {
    if (containerId.isEmpty) return;
    if (!_openedContainerIds.contains(containerId)) {
      _openedContainerIds.add(containerId);
    }
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

    // Mark the active container opened on every build — the single point that
    // records retention. Idempotent and build-time, so it covers the initial
    // active container, shell-driven activity-bar taps, and host-driven
    // (controlled) container changes alike without a separate call at each.
    _markOpened(_activeViewContainerId);

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

                  // Sidebar (collapsible). Always kept in the tree — Offstage
                  // when hidden rather than removed — so the retained container
                  // subtrees (and their shell-owned pane State) survive a
                  // hide/show cycle, not only a container switch
                  // (§spec:view-container-state: retained "for the life of the
                  // layout"). Offstage takes no layout space when hidden, so the
                  // editor still fills the row exactly as before; the visible
                  // hide/show behavior is unchanged.
                  Offstage(
                    offstage: !_sidebarVisible,
                    child: TickerMode(
                      enabled: _sidebarVisible,
                      child: Stack(
                        children: [
                          _Sidebar(
                            width: _sidebarWidth,
                            activeLabel: _activeLabelFor(
                              _activeViewContainerId,
                            ),
                            activeContainerId: _activeViewContainerId,
                            openedContainerIds: _openedContainerIds,
                            containerBuilder: widget.containerBuilder,
                            theme: theme,
                          ),
                          // The sash overlays the sidebar's right edge rather
                          // than taking a strip of layout, so at rest it adds
                          // nothing (canon: the sash is transparent; the seam is
                          // the sidebar's own right border). Mirrors the panel
                          // and view-stack pane sashes.
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            child: _buildVerticalResizer(theme),
                          ),
                        ],
                      ),
                    ),
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
      // The shell owns the width: permute it live each frame so the tree
      // relayouts, and commit the final value once on release for persistence
      // (§spec:resize-geometry). No per-frame host callback.
      onChanged: (next) => setState(() => _sidebarWidth = next),
      onChangeEnd: (next) => widget.onSidebarWidthChangeEnd?.call(next),
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
      onChangeEnd: (next) => widget.onPanelHeightChangeEnd?.call(next),
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
  final WorkbenchTheme theme;

  const _Sidebar({
    required this.width,
    required this.activeLabel,
    required this.activeContainerId,
    required this.openedContainerIds,
    required this.containerBuilder,
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

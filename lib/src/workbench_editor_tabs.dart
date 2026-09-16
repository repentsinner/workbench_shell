import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show FlexParentData, RenderFlex;
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:meta/meta.dart';

import 'layout_constants.dart';
import 'workbench_intents.dart';
import 'workbench_layout_state.dart';
import 'workbench_surface_treatment.dart';
import 'workbench_theme.dart';

/// One editor the host offers as a tab in the editor area
/// (§spec:editor-tabs).
///
/// The host owns which tabs exist and what each shows; the shell renders the
/// strip, owns which tab is active, and builds [contentBuilder] beneath it.
/// The label is a `String` and the icon an [IconData] so the shell keeps its
/// hold on type, size and colour (§spec:capability-boundary).
@immutable
class WorkbenchEditorTab {
  /// Stable identity. The shell keys the active tab, the tab order and each
  /// tab's retained content by it, so it shall be unique within a layout and
  /// survive rebuilds.
  final String id;

  /// The tab's label, rendered in the casing the host supplies.
  final String label;

  /// Optional icon rendered before the label, VS Code's
  /// `workbench.editor.showIcons`.
  final IconData? icon;

  /// Whether the editor has unsaved changes. A dirty tab shows a filled dot in
  /// place of its close button and exposes the state to assistive technology
  /// (§spec:editor-tab-rendering).
  final bool isDirty;

  /// Builds the editor shown while the tab is active. Called only once the
  /// tab has first become active; the result is retained offstage while
  /// another tab is active (§spec:editor-tab-interaction). While the host
  /// passes this same descriptor instance, the shell reuses the content it
  /// built rather than calling the builder on every layout rebuild; a new
  /// descriptor rebuilds it.
  final WidgetBuilder contentBuilder;

  const WorkbenchEditorTab({
    required this.id,
    required this.label,
    required this.contentBuilder,
    this.icon,
    this.isDirty = false,
  });
}

/// VS Code's default editor-tab chords for [platform]
/// (§spec:editor-tab-interaction), from `editorCommands.ts` and
/// `editorActions.ts`. Apple platforms take the macOS set; every other
/// platform takes the Windows / Linux set, with Ctrl+F4 on Windows alone.
///
/// The map is built once per platform and shared. Every chord stays bound
/// whether or not the layout can serve it: an action that reports itself
/// disabled, as the close action does without a handler, lets its chord fall
/// through to bindings above.
@internal
Map<ShortcutActivator, Intent> editorTabShortcuts(TargetPlatform platform) =>
    _editorTabShortcuts[platform] ??= Map.unmodifiable(
      _buildEditorTabShortcuts(platform),
    );

final _editorTabShortcuts = <TargetPlatform, Map<ShortcutActivator, Intent>>{};

Map<ShortcutActivator, Intent> _buildEditorTabShortcuts(
  TargetPlatform platform,
) {
  final apple =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  // Editor positions 1–9 in order; 0 selects the last editor.
  const digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
  SingleActivator position(LogicalKeyboardKey key) => apple
      ? SingleActivator(key, control: true)
      : SingleActivator(key, alt: true);
  return {
    if (apple) ...{
      const SingleActivator(
        LogicalKeyboardKey.arrowRight,
        meta: true,
        alt: true,
      ): const ActivateNextEditorTabIntent(),
      const SingleActivator(
        LogicalKeyboardKey.bracketRight,
        meta: true,
        shift: true,
      ): const ActivateNextEditorTabIntent(),
      const SingleActivator(
        LogicalKeyboardKey.arrowLeft,
        meta: true,
        alt: true,
      ): const ActivatePreviousEditorTabIntent(),
      const SingleActivator(
        LogicalKeyboardKey.bracketLeft,
        meta: true,
        shift: true,
      ): const ActivatePreviousEditorTabIntent(),
      const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
          const CloseActiveEditorTabIntent(),
    } else ...{
      const SingleActivator(LogicalKeyboardKey.pageDown, control: true):
          const ActivateNextEditorTabIntent(),
      const SingleActivator(LogicalKeyboardKey.pageUp, control: true):
          const ActivatePreviousEditorTabIntent(),
      const SingleActivator(LogicalKeyboardKey.keyW, control: true):
          const CloseActiveEditorTabIntent(),
      if (platform == TargetPlatform.windows)
        const SingleActivator(LogicalKeyboardKey.f4, control: true):
            const CloseActiveEditorTabIntent(),
    },
    for (final (index, key) in digits.indexed)
      position(key): ActivateEditorTabAtIndexIntent(index),
    position(LogicalKeyboardKey.digit0): const ActivateLastEditorTabIntent(),
  };
}

/// Owns the editor tab state (§spec:editor-tab-state) and the editor-tab key
/// bindings (§spec:editor-tab-interaction), and builds the workbench around
/// the editor part through [builder].
///
/// Internal: `WorkbenchLayout` passes its editor-tab properties through, and
/// their docs there are the host-facing contract. The bindings wrap everything
/// [builder] returns, because VS Code's editor-tab chords are workbench-wide
/// rather than scoped to the editor.
@internal
class EditorTabsScope extends StatefulWidget {
  /// The host's tabs, in the host's list order.
  final List<WorkbenchEditorTab> tabs;

  /// The empty-editor surface, the editor part while [tabs] is empty.
  final Widget editor;

  /// The active tab on first build when [activeId] is null.
  final String? initialActiveId;

  /// The controlled active tab. Null leaves the active tab to the scope.
  final String? activeId;

  /// Notified of every activation the scope originates or applies.
  final ValueChanged<String>? onActiveChanged;

  /// Notified with the full id order whenever the scope changes it.
  final ValueChanged<List<String>>? onOrderChanged;

  /// Requests a tab's close. Null renders no close buttons and leaves the
  /// close chord to bindings above.
  final ValueChanged<String>? onCloseRequested;

  /// Builds the workbench around the editor part: the strip over tab content
  /// while there are tabs, else [editor].
  final Widget Function(BuildContext context, Widget editorPart) builder;

  const EditorTabsScope({
    super.key,
    required this.tabs,
    required this.editor,
    required this.initialActiveId,
    required this.activeId,
    required this.onActiveChanged,
    required this.onOrderChanged,
    required this.onCloseRequested,
    required this.builder,
  });

  @override
  State<EditorTabsScope> createState() => _EditorTabsScopeState();
}

class _EditorTabsScopeState extends State<EditorTabsScope> {
  // The active tab follows the controlled/uncontrolled seam as the secondary
  // side bar's member does, and the scope raises its own change when a tab is
  // clicked.
  String? _internalActiveId;

  /// The shell-owned tab order (§spec:editor-tab-state): list order on first
  /// build, then maintained by [_reconcile] as the host adds and removes tabs.
  final List<String> _order = [];

  /// Tab ids by recency of activation, most recent last. The next tab to take
  /// over when the active one leaves, matching VS Code's
  /// `workbench.editor.focusRecentEditorAfterClose` default.
  ///
  /// It is also the retained set (§spec:editor-tab-interaction): only a tab
  /// that has been active has built content, so a tab never shown costs
  /// nothing.
  final List<String> _recency = [];

  /// Each retained tab's built content, with the descriptor it was built
  /// from. While the host hands back the same descriptor the scope hands the
  /// part the same widget, so Flutter skips rebuilding content that a switch
  /// or an unrelated rebuild does not touch.
  final Map<String, (WorkbenchEditorTab, Widget)> _content = {};

  /// The active tab, resolved against the live order. A controlled or
  /// internal id that names no tab falls back to the most recently active
  /// remaining tab, then to the first in order. Null only when there are no
  /// tabs.
  String? get _activeId {
    if (_order.isEmpty) return null;
    final id = widget.activeId ?? _internalActiveId;
    if (id != null && _order.contains(id)) return id;
    return _recency.lastOrNull ?? _order.first;
  }

  @override
  void initState() {
    super.initState();
    _internalActiveId = widget.initialActiveId;
    _order.addAll(widget.tabs.map((tab) => tab.id));
    _recordActive();
    _adoptKeyFocusAfterFrame();
  }

  @override
  void didUpdateWidget(covariant EditorTabsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadTabs = _order.isNotEmpty;
    // Always reconcile: a host that edits its list in place passes the same
    // instance back, and skipping would leave the order naming a removed id.
    _reconcile();
    // Covers a controlled host's change as well as the reconcile's own.
    _recordActive();
    if (!hadTabs) _adoptKeyFocusAfterFrame();
  }

  @override
  void dispose() {
    _keysFocusNode.dispose();
    super.dispose();
  }

  /// Move the active tab to the recent end of [_recency], which also retains
  /// its content.
  void _recordActive() {
    final id = _activeId;
    if (id == null || _recency.lastOrNull == id) return;
    _recency
      ..remove(id)
      ..add(id);
  }

  /// Fold the host's tab list into the shell-owned order
  /// (§spec:editor-tab-state). A removed id leaves the order and its retained
  /// content; an added id opens to the right of the active tab — VS Code's
  /// `workbench.editor.openPositioning` default — and becomes active, several
  /// opening left to right in list order. When the active tab leaves without
  /// an addition, the most recently active remaining tab takes over.
  ///
  /// The scope originates these changes, so it reports them, after the frame:
  /// this runs during the host's build, where a host `setState` would throw.
  void _reconcile() {
    final ids = {for (final tab in widget.tabs) tab.id};
    final previousActive = _activeId;
    _order.removeWhere((id) => !ids.contains(id));
    _recency.removeWhere((id) => !ids.contains(id));
    _content.removeWhere((id, _) => !ids.contains(id));
    final added = [
      for (final id in ids)
        if (!_order.contains(id)) id,
    ];

    String? nextActive;
    if (added.isNotEmpty) {
      var anchor = _activeId;
      for (final id in added) {
        final at = anchor == null ? _order.length : _order.indexOf(anchor) + 1;
        _order.insert(at, id);
        anchor = id;
      }
      nextActive = added.last;
    } else if (previousActive != null && !_order.contains(previousActive)) {
      nextActive = _activeId;
    }
    if (nextActive == null) return;

    if (widget.activeId == null) _internalActiveId = nextActive;
    final order = List<String>.unmodifiable(_order);
    final reportOrder = added.isNotEmpty;
    final activated = nextActive;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reportOrder) widget.onOrderChanged?.call(order);
      widget.onActiveChanged?.call(activated);
    });
  }

  /// Activate a tab (§spec:editor-tab-state), mirroring the layout's
  /// secondary side-bar activation: mutate internal state only in
  /// uncontrolled mode, and always report so a controlled host can honor the
  /// shell-originated change. No-op when the tab is already active.
  void _setActive(String id) {
    if (_activeId == id) return;
    setState(() {
      if (widget.activeId == null) _internalActiveId = id;
      _recordActive();
    });
    widget.onActiveChanged?.call(id);
  }

  /// Activate a tab the user clicked, and take key focus as a click into the
  /// workbench does.
  void _selectFromStrip(String id) {
    _adoptKeyFocus();
    _setActive(id);
  }

  /// Adopt the order a drag produced (§spec:editor-tab-state) and report it
  /// in full. The shell owns the order, so a controlled active tab does not
  /// hold it back, and the strip only calls this when the order changed.
  void _reorderFromStrip(List<String> order) {
    setState(() {
      _order
        ..clear()
        ..addAll(order);
    });
    widget.onOrderChanged?.call(List.unmodifiable(order));
  }

  /// Receives key events for the editor-tab bindings. `Shortcuts` sees only
  /// events that bubble up from the primary focus, so this node takes focus
  /// when nothing inside the workbench holds it (see [_adoptKeyFocus]).
  final FocusNode _keysFocusNode = FocusNode(
    debugLabel: 'WorkbenchLayout editor tab keys',
  );

  /// Gaining tabs gains the bindings, which need focus to hear keys. The
  /// adoption waits for the frame, once the node is attached and a wrapper's
  /// autofocus has settled.
  void _adoptKeyFocusAfterFrame() {
    if (_order.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _adoptKeyFocus());
  }

  /// Take primary focus when it rests above the workbench — on a wrapper such
  /// as `WorkbenchShortcuts`, a route scope, or nowhere — so the editor-tab
  /// chords reach the bindings without the user first clicking into the
  /// workbench. The scope adopts only when tabs first appear and when the user
  /// clicks a tab, so a host that moves focus elsewhere keeps it there. Focus
  /// inside the workbench, or in another route, is left alone, and bindings
  /// above still see every event because it bubbles through them.
  void _adoptKeyFocus() {
    if (!mounted || _order.isEmpty) return;
    final node = _keysFocusNode;
    final primary = FocusManager.instance.primaryFocus;
    if (primary == node || node.context == null) return;
    if (primary == null || node.ancestors.contains(primary)) {
      node.requestFocus();
    }
  }

  /// The editor-tab command handlers (§spec:action-dispatch). Built once so a
  /// listener's subscription outlives rebuilds; each reads live state when it
  /// runs.
  late final Map<Type, Action<Intent>> _actions = {
    ActivateNextEditorTabIntent: _EditorTabAction<ActivateNextEditorTabIntent>(
      this,
      onInvoke: (_) => _activateAdjacent(1),
    ),
    ActivatePreviousEditorTabIntent:
        _EditorTabAction<ActivatePreviousEditorTabIntent>(
          this,
          onInvoke: (_) => _activateAdjacent(-1),
        ),
    ActivateEditorTabAtIndexIntent:
        _EditorTabAction<ActivateEditorTabAtIndexIntent>(
          this,
          onInvoke: (intent) {
            if (intent.index < 0 || intent.index >= _order.length) return;
            _setActive(_order[intent.index]);
          },
        ),
    ActivateLastEditorTabIntent: _EditorTabAction<ActivateLastEditorTabIntent>(
      this,
      onInvoke: (_) => _setActive(_order.last),
    ),
    // Disabled without a close handler, so the chord passes to any binding
    // above rather than closing nothing (§spec:editor-tab-rendering).
    CloseActiveEditorTabIntent: _EditorTabAction<CloseActiveEditorTabIntent>(
      this,
      enabled: () => widget.onCloseRequested != null,
      onInvoke: (_) => widget.onCloseRequested!(_activeId!),
    ),
  };

  /// Step the active tab [step] places along the strip, wrapping at either
  /// end as VS Code's `nextEditor` / `previousEditor` do within a single
  /// group.
  void _activateAdjacent(int step) {
    final at = _order.indexOf(_activeId!) + step;
    _setActive(_order[at % _order.length]);
  }

  /// The content widget for [tab], reused while its descriptor is unchanged.
  Widget _contentFor(WorkbenchEditorTab tab) {
    final cached = _content[tab.id];
    if (cached != null && identical(cached.$1, tab)) return cached.$2;
    final child = Builder(builder: tab.contentBuilder);
    _content[tab.id] = (tab, child);
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final activeId = _activeId;
    final Widget editorPart;
    if (activeId == null) {
      editorPart = widget.editor;
    } else {
      final byId = {for (final tab in widget.tabs) tab.id: tab};
      editorPart = EditorTabsPart(
        tabs: [for (final id in _order) byId[id]!],
        activeId: activeId,
        content: {for (final id in _recency) id: _contentFor(byId[id]!)},
        onSelected: _selectFromStrip,
        onReordered: _reorderFromStrip,
        onCloseRequested: widget.onCloseRequested,
        theme: context.workbenchTheme,
      );
    }
    // The wrappers stay in the tree whether or not there are tabs, so gaining
    // or losing tabs never re-parents the workbench. With no tabs every action
    // is disabled, so each chord reaches the bindings above, and the node
    // takes no focus.
    return Actions(
      actions: _actions,
      child: Shortcuts(
        shortcuts: editorTabShortcuts(defaultTargetPlatform),
        child: Focus(
          focusNode: _keysFocusNode,
          canRequestFocus: activeId != null,
          skipTraversal: true,
          child: widget.builder(context, editorPart),
        ),
      ),
    );
  }
}

/// One editor-tab command handler (§spec:action-dispatch). `CallbackAction`
/// reports itself always enabled, and a disabled action is what lets a chord
/// the scope cannot serve fall through to a host binding above it.
///
/// Every handler is disabled while [scope] has no tabs, so [onInvoke] always
/// runs with an active tab.
class _EditorTabAction<T extends Intent> extends Action<T> {
  final _EditorTabsScopeState scope;

  /// A further condition beyond having tabs. Null adds none.
  final bool Function()? enabled;
  final void Function(T intent) onInvoke;

  _EditorTabAction(this.scope, {this.enabled, required this.onInvoke});

  @override
  bool isEnabled(T intent) =>
      scope._order.isNotEmpty && (enabled?.call() ?? true);

  @override
  Object? invoke(T intent) {
    onInvoke(intent);
    return null;
  }
}

/// The editor part with tabs: the strip over a retained stack of tab content
/// (§spec:editor-tab-rendering, §spec:editor-tab-interaction).
///
/// Internal: [EditorTabsScope] owns the state this widget renders.
@internal
class EditorTabsPart extends StatelessWidget {
  /// Tabs in display order.
  final List<WorkbenchEditorTab> tabs;

  /// The active tab's id; one of [tabs].
  final String activeId;

  /// Built content by tab id, for the retained tabs alone, so a tab never
  /// shown costs nothing.
  final Map<String, Widget> content;

  /// Activates a tab from a click or the start of a drag.
  final ValueChanged<String> onSelected;

  /// Adopts the full id order a drag produced.
  final ValueChanged<List<String>> onReordered;

  /// Requests a tab's close. Null renders no close buttons.
  final ValueChanged<String>? onCloseRequested;

  final WorkbenchTheme theme;

  const EditorTabsPart({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.content,
    required this.onSelected,
    required this.onReordered,
    required this.onCloseRequested,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorTabStrip(
          tabs: tabs,
          activeId: activeId,
          onSelected: onSelected,
          onReordered: onReordered,
          onCloseRequested: onCloseRequested,
          theme: theme,
        ),
        Expanded(
          // One slot per retained tab, keyed by id so each keeps its element
          // and State whatever order the slots stand in. Inactive slots stay
          // in the tree offstage with tickers disabled, as retained view
          // containers do (§spec:view-container-state).
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final tab in tabs)
                if (content[tab.id] case final child?)
                  Offstage(
                    key: ValueKey(tab.id),
                    offstage: tab.id != activeId,
                    child: TickerMode(
                      enabled: tab.id == activeId,
                      // A hidden editor cannot keep focus, so keys never land
                      // in content the user cannot see.
                      child: ExcludeFocus(
                        excluding: tab.id != activeId,
                        child: child,
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The editor tab strip (§spec:editor-tab-rendering), in the treatment the
/// Modern UI flag selects.
///
/// - **Base:** VS Code's classic multi-tab strip, a
///   [WorkbenchLayoutConstants.editorTabHeight] row in
///   `editorGroupHeader.tabsBackground` with one `fit`-sized tab per editor.
/// - **Modern UI:** upstream's `connected` style, a
///   [WorkbenchLayoutConstants.connectedEditorTabStripHeight] row whose active
///   tab joins the editor below it (see [ConnectedEditorTabPainter]).
///
/// Dragging a tab reorders it (§spec:editor-tab-interaction). The whole strip
/// is the drop target, so a drop past the last tab lands at the end, as a drop
/// on upstream's tabs container does.
///
/// Tabs past the strip's width are clipped at its trailing edge until
/// overflow scrolling lands (§spec:editor-tab-interaction).
@internal
class EditorTabStrip extends StatefulWidget {
  final List<WorkbenchEditorTab> tabs;
  final String activeId;

  /// Activates a tab from a click or the start of a drag.
  final ValueChanged<String> onSelected;

  /// Adopts the full id order a drop produced. Called only when the order
  /// changed.
  final ValueChanged<List<String>> onReordered;
  final ValueChanged<String>? onCloseRequested;
  final WorkbenchTheme theme;

  const EditorTabStrip({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelected,
    required this.onReordered,
    required this.onCloseRequested,
    required this.theme,
  });

  @override
  State<EditorTabStrip> createState() => _EditorTabStripState();
}

class _EditorTabStripState extends State<EditorTabStrip> {
  /// Where a dragged tab would drop, and the row-local x of the bar that
  /// marks it. Null while no tab is dragged over the strip.
  ///
  /// Only the bar listens, so a moving pointer rebuilds the bar and leaves
  /// the tabs alone.
  final ValueNotifier<_DropSlot?> _dropSlot = ValueNotifier(null);

  /// The row of tabs. A drag reads each tab's box from the row's children to
  /// find the one under the pointer, and the bar is positioned in the row's
  /// space.
  final GlobalKey _rowKey = GlobalKey();

  @override
  void dispose() {
    _dropSlot.dispose();
    super.dispose();
  }

  /// Record the slot under global [pointer], per VS Code's
  /// `computeDropTarget`: the pointer's half of the tab beneath it picks the
  /// slot before or after that tab, and a pointer past every tab picks the
  /// slot after the last.
  ///
  /// Upstream marks both tabs beside the slot and draws both bars on the same
  /// boundary, so one bar on the leading edge of the tab after the slot, or
  /// on the last tab's trailing edge, paints the same pixels.
  void _updateDropSlot(Offset pointer) {
    final row = _rowKey.currentContext?.findRenderObject();
    if (row is! RenderFlex || !row.hasSize) return;
    final x = row.globalToLocal(pointer).dx;
    // One row child per tab, in tab order.
    var index = 0;
    var end = 0.0;
    for (RenderBox? child = row.firstChild; child != null; index++) {
      final data = child.parentData! as FlexParentData;
      final start = data.offset.dx;
      final width = child.size.width;
      end = start + width;
      if (x - start < width) {
        // `getTabDragOverLocation` counts the midpoint as the leading half.
        _dropSlot.value = x - start <= width / 2
            ? (index: index, left: start)
            : (index: index + 1, left: end);
        return;
      }
      child = data.nextSibling;
    }
    _dropSlot.value = (index: index, left: end);
  }

  void _clearDropSlot() => _dropSlot.value = null;

  /// Move the tab with [id] into the recorded slot and report the new order,
  /// unless it lands where it already stands.
  void _drop(String id) {
    final slot = _dropSlot.value?.index;
    _clearDropSlot();
    if (slot == null) return;
    final order = [for (final tab in widget.tabs) tab.id];
    final from = order.indexOf(id);
    // Taking the tab out first shifts every later slot down by one.
    final to = slot > from ? slot - 1 : slot;
    if (to == from) return;
    widget.onReordered(
      WorkbenchLayoutState.applyReorder(order, const {}, from, to),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tabs = widget.tabs;
    final activeId = widget.activeId;
    final connected = WorkbenchSurfaceTreatment.of(context);
    final metrics = connected
        ? _EditorTabMetrics.modern
        : _EditorTabMetrics.base;
    final onClose = widget.onCloseRequested;

    Widget tabFor(int index, WorkbenchEditorTab tab, {Key? key}) => _EditorTab(
      key: key,
      tab: tab,
      active: tab.id == activeId,
      metrics: metrics,
      first: index == 0,
      last: index == tabs.length - 1,
      followsActive: index > 0 && tabs[index - 1].id == activeId,
      onSelected: () => widget.onSelected(tab.id),
      onClose: onClose == null ? null : () => onClose(tab.id),
      theme: theme,
    );

    final row = Row(
      key: _rowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, tab) in tabs.indexed)
          Draggable<String>(
            key: ValueKey('editor-tab-drag-${tab.id}'),
            data: tab.id,
            // Upstream pins the drag image's top-left corner to the pointer,
            // and the drop slot reads the pointer from the feedback offset.
            dragAnchorStrategy: pointerDragAnchorStrategy,
            // Pressing a tab activates it upstream, so a drag carries the tab
            // it moves into view.
            onDragStarted: () => widget.onSelected(tab.id),
            onDragEnd: (_) => _clearDropSlot(),
            onDraggableCanceled: (_, _) => _clearDropSlot(),
            feedback: Material(
              type: MaterialType.transparency,
              child: UnconstrainedBox(
                alignment: AlignmentDirectional.topStart,
                child: SizedBox(
                  height: metrics.stripHeight,
                  child: _EditorTab(
                    tab: tab,
                    active: true,
                    metrics: metrics,
                    // A drag image carries no shoulders into its neighbours.
                    first: true,
                    last: false,
                    followsActive: false,
                    onSelected: () {},
                    onClose: onClose == null ? null : () {},
                    theme: theme,
                  ),
                ),
              ),
            ),
            child: tabFor(index, tab, key: ValueKey('editor-tab-${tab.id}')),
          ),
      ],
    );
    final Widget content = DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        if (!tabs.any((tab) => tab.id == details.data)) return false;
        _updateDropSlot(details.offset);
        return true;
      },
      onMove: (details) {
        if (tabs.any((tab) => tab.id == details.data)) {
          _updateDropSlot(details.offset);
        }
      },
      onLeave: (_) => _clearDropSlot(),
      onAcceptWithDetails: (details) => _drop(details.data),
      builder: (context, candidates, rejected) => Semantics(
        role: SemanticsRole.tabBar,
        container: true,
        child: ClipRect(
          // Lets the row keep its natural width without an overflow warning;
          // the clip hides whatever runs past the strip.
          child: OverflowBox(
            alignment: AlignmentDirectional.centerStart,
            maxWidth: double.infinity,
            child: Stack(
              // The bar past the last tab stands just outside the row.
              clipBehavior: Clip.none,
              children: [row, _dropBar(metrics)],
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: metrics.stripHeight,
      child: DecoratedBox(
        key: const ValueKey('editor-tab-strip-background'),
        decoration: BoxDecoration(
          color: connected
              ? ConnectedEditorTabPainter.stripBackground(theme)
              : theme.editorGroupHeaderTabsBackground,
          // Under Modern UI, the separator along the strip's foot, in the
          // editor surface so the active tab and the editor read as one well.
          // Inactive fills repaint it over themselves; the active tab covers
          // it.
          border: connected
              ? Border(
                  bottom: BorderSide(
                    color: theme.editorBackground,
                    // Stated so the separator tracks `strokeThickness` if
                    // upstream moves it, rather than silently keeping
                    // Flutter's 1px default.
                    // ignore: avoid_redundant_argument_values
                    width: WorkbenchLayoutConstants.strokeThickness,
                  ),
                )
              : null,
        ),
        child: content,
      ),
    );
  }

  /// The drop bar, positioned over the row while a dragged tab would land in
  /// a slot.
  ///
  /// `multieditortabscontrol.css` draws a 2px `tab.dragAndDropBorder` bar the
  /// height of the tab's padding box: at `left: 0` for the slot before a tab,
  /// and at `right: -2px` for the slot after the last one, just past its
  /// edge. Under Modern UI the padding box is the 24px row between the tab's
  /// transparent bands.
  Widget _dropBar(_EditorTabMetrics metrics) {
    return ValueListenableBuilder<_DropSlot?>(
      valueListenable: _dropSlot,
      builder: (context, slot, _) {
        if (slot == null) return const SizedBox.shrink();
        return Positioned(
          top: metrics.rowInsetTop,
          bottom: metrics.rowInsetBottom,
          left: slot.left,
          width: WorkbenchLayoutConstants.editorTabDropIndicatorWidth,
          child: IgnorePointer(
            child: ColoredBox(
              key: const ValueKey('editor-tab-drop-indicator'),
              color: widget.theme.tabDragAndDropBorder,
            ),
          ),
        );
      },
    );
  }
}

/// A slot a dragged tab would drop into, 0 before the first tab through
/// `tabs.length` after the last, with the row-local x of the bar marking it.
typedef _DropSlot = ({int index, double left});

/// The sizes and hover rules that differ between the base and Modern UI tab
/// treatments (§spec:editor-tab-rendering), resolved once per strip build.
@immutable
class _EditorTabMetrics {
  /// Renders the Modern UI `connected` treatment rather than the base one.
  final bool connected;

  /// The strip's height.
  final double stripHeight;

  /// A tab's leading inset without an icon, and with one.
  final double paddingStart;
  final double paddingStartWithIcon;

  /// A tab's trailing inset when it reserves no action column, and when it
  /// does. The action column supplies the trailing room when it shows.
  final double paddingEnd;
  final double paddingEndWithActions;

  /// Insets above and below a tab's content row, which the drop bar shares.
  final double rowInsetTop;
  final double rowInsetBottom;

  /// The action column's width, and its margin either side.
  final double actionsWidth;
  final double actionsMargin;

  /// Hovering anywhere on a tab recolours an inactive label and reveals a
  /// dirty tab's close glyph, rather than the pointer having to be over the
  /// action column itself.
  final bool tabHoverReveals;

  const _EditorTabMetrics._({
    required this.connected,
    required this.stripHeight,
    required this.paddingStart,
    required this.paddingStartWithIcon,
    required this.paddingEnd,
    required this.paddingEndWithActions,
    required this.rowInsetTop,
    required this.rowInsetBottom,
    required this.actionsWidth,
    required this.actionsMargin,
    required this.tabHoverReveals,
  });

  /// `multieditortabscontrol.css`: a full-height row; `.tab { padding-left:
  /// 10px }`, with `.close-action-off` padding the trailing edge only when
  /// no action column shows.
  static const base = _EditorTabMetrics._(
    connected: false,
    stripHeight: WorkbenchLayoutConstants.editorTabHeight,
    paddingStart: WorkbenchLayoutConstants.editorTabPaddingStart,
    paddingStartWithIcon: WorkbenchLayoutConstants.editorTabPaddingStart,
    paddingEnd: WorkbenchLayoutConstants.editorTabPaddingEnd,
    paddingEndWithActions: 0,
    rowInsetTop: 0,
    rowInsetBottom: 0,
    actionsWidth: WorkbenchLayoutConstants.editorTabActionsWidth,
    actionsMargin: 0,
    tabHoverReveals: false,
  );

  /// `tabs.css` with `connectedEditorTabs.css`: the label on the 24px row
  /// between the transparent bands, and the action column a shoulder's width
  /// in from the trailing edge (`.tab-actions { right: shoulder-radius }`),
  /// its margins making up the rest of `--modern-ui-tab-action-padding`.
  static const modern = _EditorTabMetrics._(
    connected: true,
    stripHeight: WorkbenchLayoutConstants.connectedEditorTabStripHeight,
    paddingStart: WorkbenchLayoutConstants.modernEditorTabPadding,
    paddingStartWithIcon: WorkbenchLayoutConstants.modernEditorTabPaddingStart,
    paddingEnd: WorkbenchLayoutConstants.modernEditorTabPadding,
    paddingEndWithActions: WorkbenchLayoutConstants.connectedEditorTabCapRadius,
    rowInsetTop: WorkbenchLayoutConstants.modernEditorTabRowInset,
    rowInsetBottom: WorkbenchLayoutConstants.modernEditorTabRowInsetBottom,
    actionsWidth: WorkbenchLayoutConstants.modernEditorTabActionsWidth,
    actionsMargin: WorkbenchLayoutConstants.modernEditorTabActionsMargin,
    tabHoverReveals: true,
  );
}

/// One tab, per `multieditortabscontrol.css` in the base treatment and
/// `tabs.css` with `connectedEditorTabs.css` under Modern UI.
class _EditorTab extends StatefulWidget {
  final WorkbenchEditorTab tab;
  final bool active;

  /// The treatment's sizes and hover rules.
  final _EditorTabMetrics metrics;

  /// The tab stands first in the strip, so a connected active tab keeps a
  /// straight leading edge.
  final bool first;

  /// The tab stands last, so a connected active tab turns its trailing
  /// shoulder inside its own slot.
  final bool last;

  /// The tab directly before this one is active, so this tab paints that
  /// tab's trailing shoulder over its own fill.
  final bool followsActive;

  final VoidCallback onSelected;

  /// Requests this tab's close. Null renders no close button.
  final VoidCallback? onClose;
  final WorkbenchTheme theme;

  const _EditorTab({
    super.key,
    required this.tab,
    required this.active,
    required this.metrics,
    required this.first,
    required this.last,
    required this.followsActive,
    required this.onSelected,
    required this.onClose,
    required this.theme,
  });

  @override
  State<_EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<_EditorTab> {
  /// The pointer is over the tab, which reveals its close button.
  bool _tabHovered = false;

  /// The pointer is over the action column itself, which swaps a dirty tab's
  /// dot back to the close glyph in the base treatment
  /// (`.action-label:not(:hover)::before`).
  bool _actionHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tab = widget.tab;
    final active = widget.active;
    final metrics = widget.metrics;
    // `tabs.css` recolours a hovered inactive label through
    // `modernEditorTab.hoverForeground`, which defaults to
    // `modernTab.hoverForeground`; the base strip keeps its inactive colour.
    final foreground = active
        ? theme.tabActiveForeground
        : metrics.tabHoverReveals && _tabHovered
        ? theme.panelTabHoverForeground
        : theme.tabInactiveForeground;
    // `.tab-actions` shows for a closable tab and for a dirty one: the
    // unsaved dot is state, so it stays even with no close affordance.
    final showsActions = widget.onClose != null || tab.isDirty;
    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: tab.icon == null
            ? metrics.paddingStart
            : metrics.paddingStartWithIcon,
        end: showsActions ? metrics.paddingEndWithActions : metrics.paddingEnd,
        top: metrics.rowInsetTop,
        bottom: metrics.rowInsetBottom,
      ),
      child: Row(
        // `.tab-label { flex: 1 }` pushes the actions to the trailing edge of a
        // tab wider than its content. The strip lays tabs out at their natural
        // width, so the free space is distributed rather than flexed into.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tab.icon case final icon?) ...[
                Icon(
                  icon,
                  size: WorkbenchLayoutConstants.iconMd,
                  color: foreground,
                ),
                const SizedBox(
                  width: WorkbenchLayoutConstants.editorTabIconGap,
                ),
              ],
              Text(
                tab.label,
                maxLines: 1,
                softWrap: false,
                style: theme.editorTabLabel.copyWith(color: foreground),
              ),
            ],
          ),
          if (showsActions) _buildActions(foreground),
        ],
      ),
    );
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      selected: active,
      value: tab.isDirty ? 'unsaved changes' : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _tabHovered = true),
        onExit: (_) => setState(() => _tabHovered = false),
        child: GestureDetector(
          onTap: widget.onSelected,
          child: metrics.connected
              ? _buildConnected(content)
              : _buildBase(content),
        ),
      ),
    );
  }

  /// The base tab: a `fit`-sized box in `tab.*Background` with a `tab.border`
  /// divider on its trailing edge.
  Widget _buildBase(Widget content) {
    final theme = widget.theme;
    return Container(
      constraints: const BoxConstraints(
        minWidth: WorkbenchLayoutConstants.editorTabMinWidth,
      ),
      decoration: BoxDecoration(
        color: widget.active
            ? theme.tabActiveBackground
            : theme.tabInactiveBackground,
        border: Border(right: BorderSide(color: theme.tabBorder)),
      ),
      child: _activeRules(content),
    );
  }

  /// The connected tab: content-sized (`.sizing-fit { min-width: 0 }`), its
  /// label on the 24px row between the transparent 4px bands, with the fill
  /// and shoulders painted beneath it.
  Widget _buildConnected(Widget content) {
    final theme = widget.theme;
    final active = widget.active;
    return CustomPaint(
      key: const ValueKey('editor-tab-connected-fill'),
      painter: ConnectedEditorTabPainter(
        active: active,
        fill: !active && _tabHovered
            ? ConnectedEditorTabPainter.hoverBackground(theme)
            : null,
        surface: theme.editorBackground,
        leadingShoulder: active && !widget.first,
        trailingShoulderInside: active && widget.last,
        continuesShoulder: widget.followsActive,
      ),
      child: content,
    );
  }

  /// The trailing action column: the close button, or a dirty tab's dot.
  ///
  /// Upstream's `.tab-actions` rules show it on the active tab, on hover, and
  /// on a dirty tab, and hide it (opacity 0) otherwise. A hidden button takes
  /// no pointer, so a tap there activates the tab instead of closing an
  /// editor the user cannot see a button for.
  ///
  /// A dirty tab shows its dot until the pointer reveals the close glyph: in
  /// the base treatment the pointer has to be over the column itself; under
  /// Modern UI, `tabs.css` swaps the glyph on `.tab.dirty:hover`, anywhere on
  /// the tab.
  Widget _buildActions(Color foreground) {
    final tab = widget.tab;
    final onClose = widget.onClose;
    final metrics = widget.metrics;
    final visible = widget.active || _tabHovered || tab.isDirty;
    final revealsClose = metrics.tabHoverReveals ? _tabHovered : _actionHovered;
    final showsDot = tab.isDirty && (onClose == null || !revealsClose);
    final glyph = Icon(
      showsDot ? Symbols.fiber_manual_record : Symbols.close_rounded,
      fill: showsDot ? 1 : 0,
      size: WorkbenchLayoutConstants.iconMd,
      color: foreground,
    );
    final column = Opacity(
      key: const ValueKey('editor-tab-actions'),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: SizedBox(
          width: metrics.actionsWidth,
          child: onClose == null
              ? Center(child: glyph)
              : Semantics(
                  container: true,
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  onTap: onClose,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _actionHovered = true),
                    onExit: (_) => setState(() => _actionHovered = false),
                    child: GestureDetector(
                      onTap: onClose,
                      child: Center(child: glyph),
                    ),
                  ),
                ),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.actionsMargin),
      child: column,
    );
  }

  /// The active tab's 1px top and bottom rules, drawn over its content
  /// inside the divider, each only when the theme sets its token.
  Widget _activeRules(Widget child) {
    if (!widget.active) return child;
    final theme = widget.theme;
    BorderSide rule(Color? color) => color == null
        ? BorderSide.none
        : BorderSide(
            color: color,
            // Stated so the rule tracks `strokeThickness` if upstream moves
            // it, rather than silently keeping Flutter's 1px default.
            // ignore: avoid_redundant_argument_values
            width: WorkbenchLayoutConstants.strokeThickness,
          );
    return DecoratedBox(
      key: const ValueKey('editor-tab-active-rules'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: rule(theme.tabActiveBorderTop),
          bottom: rule(theme.tabActiveBorder),
        ),
      ),
      child: child,
    );
  }
}

/// Paints a connected editor tab's fill (§spec:editor-tab-rendering), per
/// `connectedEditorTabs.css`.
///
/// The active tab is one shape in the editor surface: a cap rounded at its top
/// corners, running the strip's full height so it covers the separator, with
/// a concave shoulder at each foot curving it out into the editor. The first
/// tab keeps a straight leading edge; the last turns its trailing shoulder
/// inside its own slot. An inactive tab paints nothing until hovered, then a
/// fill rounded at the controls tier, over which the separator is repainted.
///
/// Upstream draws a stroke around the cap and shoulders in
/// `--modern-ui-connected-tab-border`, which outside high contrast is the
/// surface itself, so painting the surface alone is the same pixels. High
/// contrast recolours that stroke; the shell renders no high-contrast variant
/// of it.
///
/// A shoulder that curves past the tab's edge would be overdrawn by the
/// neighbour Flutter paints after it, so the tab that follows the active one
/// paints that trailing shoulder itself ([continuesShoulder]). The leading
/// shoulder overdraws the tab before, which has already painted, and upstream
/// stacks the active fill above its neighbours in the same way.
@internal
class ConnectedEditorTabPainter extends CustomPainter {
  /// Share of `foreground` mixed into the strip for a hovered tab.
  /// `connectedEditorTabs.css` sets `--modern-ui-editor-tab-hover-background`
  /// to `color-mix(in srgb, var(--vscode-foreground) 6%, ...)` over the strip.
  static const double hoverForegroundOpacity = 0.06;

  /// The strip's fill: `editorGroupHeader.tabsBackground` made opaque over
  /// `editor.background`, as `connectedEditorTabs.ts` flattens it.
  static Color stripBackground(WorkbenchTheme theme) => Color.alphaBlend(
    theme.editorGroupHeaderTabsBackground,
    theme.editorBackground,
  );

  /// A hovered inactive tab's fill, derived from `foreground` over the strip.
  static Color hoverBackground(WorkbenchTheme theme) => Color.alphaBlend(
    theme.foreground.withValues(alpha: hoverForegroundOpacity),
    stripBackground(theme),
  );

  /// Paints the active shape rather than an inactive fill.
  final bool active;

  /// An inactive tab's fill; null paints none. Ignored while [active].
  final Color? fill;

  /// The editor surface: the active shape, its shoulders and the separator.
  final Color surface;

  /// The active tab curves out past its leading edge.
  final bool leadingShoulder;

  /// The active tab is last, so its trailing shoulder turns inside its slot.
  final bool trailingShoulderInside;

  /// The tab before this one is active; paint its trailing shoulder here.
  final bool continuesShoulder;

  const ConnectedEditorTabPainter({
    required this.active,
    required this.fill,
    required this.surface,
    required this.leadingShoulder,
    required this.trailingShoulderInside,
    required this.continuesShoulder,
  });

  static const double _radius =
      WorkbenchLayoutConstants.connectedEditorTabCapRadius;
  static const _corner = Radius.circular(_radius);

  @override
  void paint(Canvas canvas, Size size) {
    final surfacePaint = Paint()..color = surface;
    final foot = size.height;
    if (active) {
      canvas.drawPath(_activeShape(size), surfacePaint);
      return;
    }
    if (fill case final color?) {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Offset.zero & size,
            const Radius.circular(WorkbenchLayoutConstants.cornerRadiusSmall),
          ),
          Paint()..color = color,
        )
        ..drawRect(
          Rect.fromLTRB(
            0,
            foot - WorkbenchLayoutConstants.strokeThickness,
            size.width,
            foot,
          ),
          surfacePaint,
        );
    }
    if (continuesShoulder) {
      final shoulder = Path()
        ..moveTo(0, foot - _radius)
        ..arcTo(
          Rect.fromCircle(
            center: Offset(_radius, foot - _radius),
            radius: _radius,
          ),
          math.pi,
          -math.pi / 2,
          false,
        )
        ..lineTo(0, foot)
        ..close();
      canvas.drawPath(shoulder, surfacePaint);
    }
  }

  /// The cap with its shoulders, traced clockwise from the leading foot.
  Path _activeShape(Size size) {
    final foot = size.height;
    final right = trailingShoulderInside ? size.width - _radius : size.width;
    final path = Path()..moveTo(leadingShoulder ? -_radius : 0, foot);
    if (leadingShoulder) {
      // A concave quarter turn from the foot up to the leading edge.
      path.arcTo(
        Rect.fromCircle(
          center: Offset(-_radius, foot - _radius),
          radius: _radius,
        ),
        math.pi / 2,
        -math.pi / 2,
        false,
      );
    }
    path
      ..lineTo(0, _radius)
      ..arcToPoint(const Offset(_radius, 0), radius: _corner)
      ..lineTo(right - _radius, 0)
      ..arcToPoint(Offset(right, _radius), radius: _corner);
    if (trailingShoulderInside) {
      path
        ..lineTo(right, foot - _radius)
        ..arcTo(
          Rect.fromCircle(
            center: Offset(size.width, foot - _radius),
            radius: _radius,
          ),
          math.pi,
          -math.pi / 2,
          false,
        );
    } else {
      path.lineTo(right, foot);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(ConnectedEditorTabPainter oldDelegate) =>
      oldDelegate.active != active ||
      oldDelegate.fill != fill ||
      oldDelegate.surface != surface ||
      oldDelegate.leadingShoulder != leadingShoulder ||
      oldDelegate.trailingShoulderInside != trailingShoulderInside ||
      oldDelegate.continuesShoulder != continuesShoulder;
}

import 'dart:async' show Timer;
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart'
    show clampDouble, defaultTargetPlatform;
import 'package:flutter/gestures.dart'
    show
        GestureBinding,
        PointerPanZoomUpdateEvent,
        PointerScrollEvent,
        PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show FlexParentData, RenderFlex;
import 'package:flutter/scheduler.dart' show Ticker;
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
/// - **Modern UI:** the pill tabs of VS Code 1.138.0's `tabs.css`, a
///   transparent [WorkbenchLayoutConstants.modernEditorTabStripHeight] row of
///   content-sized tabs, each with an inset rounded fill.
///
/// Dragging a tab reorders it (§spec:editor-tab-interaction). The whole strip
/// is the drop target, so a drop past the last tab lands at the end, as a drop
/// on upstream's tabs container does.
///
/// Tabs that outgrow the strip scroll horizontally under an overlay
/// scrollbar, and the strip reveals the active tab (§spec:editor-tab-overflow),
/// per `multiEditorTabsControl.ts`.
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

class _EditorTabStripState extends State<EditorTabStrip>
    with SingleTickerProviderStateMixin {
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

  /// The strip's horizontal scroll (§spec:editor-tab-overflow).
  final ScrollController _scroll = ScrollController();

  /// The scroll viewport, whose ends a dragged tab scrolls the strip from.
  final GlobalKey _viewportKey = GlobalKey();

  /// Scrolls the strip while a dragged tab rests near either end.
  late final Ticker _dragScrollTicker = createTicker(_onDragScrollTick);

  /// The last global pointer position of a drag over the strip, and the
  /// direction the drag scrolls it: -1 toward the start, 1 toward the end, 0
  /// not at all.
  Offset? _dragPointer;
  int _dragScrollDirection = 0;
  Duration _lastDragScrollTick = Duration.zero;

  /// The viewport extent, scroll range and active tab the last reveal check
  /// saw. The strip reveals the active tab when any of them changes, as
  /// upstream does when the active tab or its tab dimensions change.
  (double, double)? _revealedDimensions;
  String? _revealedActiveId;

  /// The next reveal check is skipped: upstream's `blockRevealActiveTabOnce`,
  /// set when a tab's close button requests its close so a run of closes does
  /// not scroll the strip under the pointer.
  bool _blockRevealOnce = false;

  bool _revealCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleRevealCheck();
  }

  @override
  void didUpdateWidget(covariant EditorTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A change of dimensions reaches the check through the metrics
    // notification.
    if (widget.activeId != _revealedActiveId) _scheduleRevealCheck();
  }

  @override
  void dispose() {
    _dragScrollTicker.dispose();
    _scroll.dispose();
    _dropSlot.dispose();
    super.dispose();
  }

  /// Check for a reveal once this frame has laid the tabs out.
  void _scheduleRevealCheck() {
    if (_revealCheckScheduled) return;
    _revealCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealCheckScheduled = false;
      _checkReveal();
    });
  }

  /// Reveal the active tab if the active tab or the strip's dimensions
  /// changed since the last check, unless a close button blocked it once.
  void _checkReveal() {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return;
    }
    final dimensions = (position.viewportDimension, position.maxScrollExtent);
    final changed =
        dimensions != _revealedDimensions ||
        widget.activeId != _revealedActiveId;
    _revealedDimensions = dimensions;
    _revealedActiveId = widget.activeId;
    if (_blockRevealOnce) {
      _blockRevealOnce = false;
      return;
    }
    if (changed) _revealActive();
  }

  /// The laid-out row of tabs, or null before its first layout.
  RenderFlex? get _row => switch (_rowKey.currentContext?.findRenderObject()) {
    final RenderFlex row when row.hasSize => row,
    _ => null,
  };

  /// Each tab's row-local leading edge and width, in tab order: the row has
  /// one child per tab.
  static Iterable<({double left, double width})> _tabBoxes(
    RenderFlex row,
  ) sync* {
    for (var child = row.firstChild; child != null;) {
      final data = child.parentData! as FlexParentData;
      yield (left: data.offset.dx, width: child.size.width);
      child = data.nextSibling;
    }
  }

  /// Scroll the active tab into view with the least movement, per upstream's
  /// `layout`: a tab that fits but runs past the trailing edge scrolls until
  /// its trailing edge meets the strip's; a tab past the leading edge, or
  /// wider than the strip, scrolls until its leading edge meets the strip's.
  void _revealActive() {
    final row = _row;
    if (row == null) return;
    final index = widget.tabs.indexWhere((tab) => tab.id == widget.activeId);
    if (index < 0) return;
    final box = _tabBoxes(row).elementAtOrNull(index);
    if (box == null) return;
    final (:left, :width) = box;
    final position = _scroll.position;
    final viewport = position.viewportDimension;
    final scrollX = position.pixels;
    final fits = width <= viewport;
    double? target;
    if (fits && scrollX + viewport < left + width) {
      target = left + width - viewport;
    } else if (scrollX > left || !fits) {
      target = left;
    }
    if (target != null) position.jumpToClamped(target);
  }

  /// Scroll the strip by [delta] logical pixels, clamped to its range.
  void _scrollBy(double delta) {
    final position = _scroll.position;
    position.jumpToClamped(position.pixels + delta);
  }

  /// Whether the tabs overflow the strip, so it has somewhere to scroll.
  bool get _overflows =>
      _scroll.hasClients && _scroll.position.maxScrollExtent > 0;

  /// The dominant axis of a gesture's [delta], per upstream's
  /// `scrollPredominantAxis` with `scrollYToX`: a vertical gesture scrolls
  /// the strip sideways, and a tie in opposite directions scrolls nothing.
  static double _predominant(Offset delta) {
    if (delta.dx + delta.dy == 0 && delta.dx.abs() == delta.dy.abs()) return 0;
    return delta.dy.abs() >= delta.dx.abs() ? delta.dy : delta.dx;
  }

  /// A wheel over an overflowing strip scrolls it. Registering with the
  /// signal resolver lets a strip that fits pass the wheel to a scrollable
  /// above.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_overflows) return;
    final delta = _predominant(event.scrollDelta);
    if (delta == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (_) => _scrollBy(delta),
    );
  }

  /// A trackpad gesture over an overflowing strip scrolls it, the content
  /// following the fingers.
  void _onPointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (!_overflows) return;
    final delta = _predominant(event.panDelta);
    if (delta != 0) _scrollBy(-delta);
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
    final row = _row;
    if (row == null) return;
    final x = row.globalToLocal(pointer).dx;
    var index = 0;
    var end = 0.0;
    for (final (left: start, :width) in _tabBoxes(row)) {
      end = start + width;
      if (x - start < width) {
        // `getTabDragOverLocation` counts the midpoint as the leading half.
        _dropSlot.value = x - start <= width / 2
            ? (index: index, left: start)
            : (index: index + 1, left: end);
        return;
      }
      index++;
    }
    _dropSlot.value = (index: index, left: end);
  }

  /// Record the drop slot for a drag of one of this strip's tabs, and report
  /// whether the drag is one.
  bool _trackDrag(DragTargetDetails<String> details) {
    if (!widget.tabs.any((tab) => tab.id == details.data)) return false;
    _dragPointer = details.offset;
    _updateDropSlot(details.offset);
    _updateDragScroll();
    return true;
  }

  /// Start or stop scrolling the strip by where the dragged tab rests: within
  /// [WorkbenchLayoutConstants.editorTabDragScrollEdge] of an end the strip
  /// can still scroll toward (§spec:editor-tab-overflow).
  void _updateDragScroll() {
    var direction = 0;
    final pointer = _dragPointer;
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (pointer != null && viewport is RenderBox && _overflows) {
      final x = viewport.globalToLocal(pointer).dx;
      final position = _scroll.position;
      const edge = WorkbenchLayoutConstants.editorTabDragScrollEdge;
      if (x < edge && position.pixels > position.minScrollExtent) {
        direction = -1;
      } else if (x > viewport.size.width - edge &&
          position.pixels < position.maxScrollExtent) {
        direction = 1;
      }
    }
    _dragScrollDirection = direction;
    if (direction == 0) {
      if (_dragScrollTicker.isActive) _dragScrollTicker.stop();
    } else if (!_dragScrollTicker.isActive) {
      _lastDragScrollTick = Duration.zero;
      _dragScrollTicker.start();
    }
  }

  void _onDragScrollTick(Duration elapsed) {
    final seconds =
        (elapsed - _lastDragScrollTick).inMicroseconds /
        Duration.microsecondsPerSecond;
    _lastDragScrollTick = elapsed;
    _scrollBy(
      _dragScrollDirection *
          WorkbenchLayoutConstants.editorTabDragScrollSpeed *
          seconds,
    );
    // The tabs moved under a still pointer, so the slot and the zone follow.
    if (_dragPointer case final pointer?) _updateDropSlot(pointer);
    _updateDragScroll();
  }

  void _clearDropSlot() {
    _dropSlot.value = null;
    _dragPointer = null;
    _updateDragScroll();
  }

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
    final pills = WorkbenchSurfaceTreatment.of(context);
    final metrics = pills ? _EditorTabMetrics.modern : _EditorTabMetrics.base;
    final onClose = widget.onCloseRequested;

    /// The tab for [tab], or its drag image. The drag image renders as the
    /// active tab and, like any drag image, takes no pointer.
    Widget tabFor(WorkbenchEditorTab tab, {bool dragImage = false}) =>
        _EditorTab(
          key: dragImage ? null : ValueKey('editor-tab-${tab.id}'),
          tab: tab,
          active: dragImage || tab.id == activeId,
          metrics: metrics,
          onSelected: () => widget.onSelected(tab.id),
          onClose: onClose == null
              ? null
              : () {
                  _blockRevealOnce = true;
                  onClose(tab.id);
                },
          theme: theme,
        );

    final row = Row(
      key: _rowKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tab in tabs)
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
                  child: tabFor(tab, dragImage: true),
                ),
              ),
            ),
            child: tabFor(tab),
          ),
      ],
    );
    // Upstream's `ScrollableElement` over the tabs container: horizontal,
    // without shadows, and driven by the strip's own wheel mapping, so the
    // scroll view takes no gesture of its own and draws no scrollbar.
    final viewport = Listener(
      key: _viewportKey,
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomUpdate: _onPointerPanZoomUpdate,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(scrollbars: false, overscroll: false),
        child: SingleChildScrollView(
          key: const ValueKey('editor-tab-viewport'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Stack(
            // The bar past the last tab stands just outside the row.
            clipBehavior: Clip.none,
            children: [
              // Inside the scroll view, so the tabs are the tab bar's
              // direct semantic children.
              Semantics(
                role: SemanticsRole.tabBar,
                container: true,
                child: row,
              ),
              _dropBar(metrics),
            ],
          ),
        ),
      ),
    );
    final Widget content = DragTarget<String>(
      onWillAcceptWithDetails: _trackDrag,
      onMove: _trackDrag,
      onLeave: (_) => _clearDropSlot(),
      onAcceptWithDetails: (details) => _drop(details.data),
      builder: (context, candidates, rejected) => Padding(
        padding: EdgeInsetsDirectional.only(start: metrics.stripInset),
        child: _EditorTabScrollbar(
          controller: _scroll,
          onMetricsChanged: _checkReveal,
          theme: theme,
          rounded: pills,
          child: viewport,
        ),
      ),
    );
    // Hover fills and the drop bar repaint the strip alone, not the editor
    // content beneath it.
    return RepaintBoundary(
      child: SizedBox(
        height: metrics.stripHeight,
        child: DecoratedBox(
          key: const ValueKey('editor-tab-strip-background'),
          // Under Modern UI the strip is transparent over the editor card,
          // with no border (`tabs.css` `.title.tabs { background-color:
          // transparent }`).
          decoration: BoxDecoration(
            color: pills ? null : theme.editorGroupHeaderTabsBackground,
          ),
          child: content,
        ),
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
          top: metrics.rowInset,
          bottom: metrics.rowInset,
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

/// The editor tab strip's scrollbar (§spec:editor-tab-overflow): a
/// [WorkbenchLayoutConstants.editorTabScrollbarSize] bar overlaying the foot
/// of [child], per upstream's `ScrollableElement` with
/// `titleScrollbarVisibility: auto`.
///
/// It shows only while the tabs overflow and the pointer is over the strip,
/// a scroll is under way, or the slider is dragged, and hides
/// [WorkbenchLayoutConstants.editorTabScrollbarHideDelay] after a scroll the
/// pointer is not over (`scrollableElement.ts`,
/// `scrollbarVisibilityController.ts`).
class _EditorTabScrollbar extends StatefulWidget {
  /// The strip's scroll, which the strip owns for its lifetime, so the bar
  /// listens to one controller throughout.
  final ScrollController controller;

  /// Called after the bar follows a change in the scroll extent or the
  /// viewport, the one place the strip hears of either.
  final VoidCallback onMetricsChanged;

  final WorkbenchTheme theme;

  /// Rounds the slider to the controls tier, as Modern UI's
  /// `roundedCorners.css` does.
  final bool rounded;

  final Widget child;

  const _EditorTabScrollbar({
    required this.controller,
    required this.onMetricsChanged,
    required this.theme,
    required this.rounded,
    required this.child,
  });

  @override
  State<_EditorTabScrollbar> createState() => _EditorTabScrollbarState();
}

class _EditorTabScrollbarState extends State<_EditorTabScrollbar> {
  bool _pointerOver = false;
  bool _sliderHovered = false;

  /// The slider is dragged, from the scroll offset it started at and the
  /// global x it started from.
  ({double pixels, double pointerX})? _drag;

  /// Where the bar stands between reveals and hides, which also picks the
  /// fade.
  _ScrollbarVisibility _visibility = _ScrollbarVisibility.hidden;

  /// One timer serves a run of reveals: when it fires, it waits out the rest
  /// of the delay since the last reveal rather than restarting on each one.
  Timer? _hideTimer;

  /// Time since the last reveal. The gesture binding's sampling clock keeps
  /// it in step with the fake time of widget tests.
  final Stopwatch _sinceReveal = GestureBinding.instance.samplingClock
      .stopwatch();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_reveal);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.controller.removeListener(_reveal);
    super.dispose();
  }

  bool get _held => _pointerOver || _drag != null;

  /// Show the bar, and schedule its hide unless the pointer or a drag holds
  /// it (`ScrollableElement._reveal`). Every scroll reveals, so the bar
  /// rebuilds only when it was hidden.
  void _reveal() {
    if (_visibility != _ScrollbarVisibility.shown) {
      setState(() => _visibility = _ScrollbarVisibility.shown);
    }
    _sinceReveal
      ..reset()
      ..start();
    if (_held) {
      _hideTimer?.cancel();
    } else if (!(_hideTimer?.isActive ?? false)) {
      _hideTimer = Timer(
        WorkbenchLayoutConstants.editorTabScrollbarHideDelay,
        _onHideTimer,
      );
    }
  }

  /// Hide once the delay has passed since the last reveal, else wait out the
  /// rest of it.
  void _onHideTimer() {
    final remaining =
        WorkbenchLayoutConstants.editorTabScrollbarHideDelay -
        _sinceReveal.elapsed;
    if (remaining > Duration.zero) {
      _hideTimer = Timer(remaining, _onHideTimer);
    } else {
      _hide();
    }
  }

  /// Fade the bar out unless the pointer or a drag holds it
  /// (`ScrollableElement._hide`).
  void _hide() {
    if (!mounted || _held) return;
    _hideTimer?.cancel();
    if (_visibility != _ScrollbarVisibility.fadingOut) {
      setState(() => _visibility = _ScrollbarVisibility.fadingOut);
    }
  }

  /// Slider geometry per `scrollbarState.ts`: the slider takes the visible
  /// share of the track, never less than the minimum, and travels in
  /// proportion to the scroll. Null while the tabs fit.
  ({double size, double left, double ratio})? _slider() {
    final controller = widget.controller;
    if (!controller.hasClients) return null;
    final position = controller.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      return null;
    }
    final visible = position.viewportDimension;
    final scrollSize = position.maxScrollExtent + visible;
    if (scrollSize <= visible) return null;
    final size = math
        .max(
          WorkbenchLayoutConstants.editorTabScrollbarMinSliderSize,
          (visible * visible / scrollSize).floorToDouble(),
        )
        .roundToDouble();
    final ratio = (visible - size) / (scrollSize - visible);
    return (
      size: size,
      left: (position.pixels * ratio).roundToDouble(),
      ratio: ratio,
    );
  }

  /// A press on the track centres the slider under the pointer, then drags
  /// it (`AbstractScrollbar._onPointerDown`); a press on the slider drags it
  /// from where it stands.
  void _onPointerDown(PointerDownEvent event) {
    final slider = _slider();
    if (slider == null) return;
    final position = widget.controller.position;
    final x = event.localPosition.dx;
    if (x < slider.left || x > slider.left + slider.size) {
      position.jumpToClamped((x - slider.size / 2) / slider.ratio);
    }
    setState(() {
      _drag = (pixels: position.pixels, pointerX: event.position.dx);
    });
    _reveal();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final drag = _drag;
    final slider = _slider();
    if (drag == null || slider == null) return;
    final delta = event.position.dx - drag.pointerX;
    widget.controller.position.jumpToClamped(
      drag.pixels + delta / slider.ratio,
    );
  }

  void _onPointerEnd(PointerEvent event) {
    if (_drag == null) return;
    setState(() => _drag = null);
    _hide();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final overflows = _slider() != null;
    final visible = overflows && _visibility == _ScrollbarVisibility.shown;
    final Color sliderColor;
    if (_drag != null) {
      sliderColor = theme.scrollbarSliderActiveBackground;
    } else if (_sliderHovered) {
      sliderColor = theme.scrollbarSliderHoverBackground;
    } else {
      sliderColor = theme.scrollbarSliderBackground;
    }
    final duration = switch (_visibility) {
      // A bar the tabs no longer need goes without a fade.
      _ when !overflows => Duration.zero,
      _ScrollbarVisibility.hidden => Duration.zero,
      _ScrollbarVisibility.shown =>
        WorkbenchLayoutConstants.editorTabScrollbarFadeInDuration,
      _ScrollbarVisibility.fadingOut =>
        WorkbenchLayoutConstants.editorTabScrollbarFadeOutDuration,
    };
    return MouseRegion(
      onEnter: (_) {
        _pointerOver = true;
        _reveal();
      },
      onExit: (_) {
        _pointerOver = false;
        _hide();
      },
      child: NotificationListener<ScrollMetricsNotification>(
        // The slider follows the extent as tabs open and close.
        onNotification: (_) {
          setState(() {});
          widget.onMetricsChanged();
          return false;
        },
        child: Stack(
          children: [
            widget.child,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: WorkbenchLayoutConstants.editorTabScrollbarSize,
              child: AnimatedOpacity(
                key: const ValueKey('editor-tab-scrollbar'),
                opacity: visible ? 1 : 0,
                duration: duration,
                // An invisible bar takes no pointer, so the tabs beneath it
                // stay reachable (`.invisible { pointer-events: none }`).
                child: IgnorePointer(
                  ignoring: !visible,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerEnd,
                    onPointerCancel: _onPointerEnd,
                    // A scroll moves the slider alone: it rebuilds from the
                    // offset and repaints apart from the tabs.
                    child: RepaintBoundary(
                      child: ListenableBuilder(
                        listenable: widget.controller,
                        builder: (context, _) => Stack(
                          children: [
                            if (_slider() case final slider?)
                              Positioned(
                                left: slider.left,
                                width: slider.size,
                                top: 0,
                                bottom: 0,
                                child: MouseRegion(
                                  onEnter: (_) =>
                                      setState(() => _sliderHovered = true),
                                  onExit: (_) =>
                                      setState(() => _sliderHovered = false),
                                  child: DecoratedBox(
                                    key: const ValueKey(
                                      'editor-tab-scrollbar-slider',
                                    ),
                                    decoration: BoxDecoration(
                                      color: sliderColor,
                                      borderRadius: widget.rounded
                                          ? BorderRadius.circular(
                                              WorkbenchLayoutConstants
                                                  .cornerRadiusSmall,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether the editor tab scrollbar shows, before the tabs' overflow gates
/// it.
enum _ScrollbarVisibility {
  /// Never revealed.
  hidden,

  /// Revealed by a scroll or the pointer; shows over the fade-in.
  shown,

  /// Hidden after a reveal; fades out rather than cutting.
  fadingOut,
}

extension on ScrollPosition {
  /// Jump to [pixels] clamped to the scroll range, unless already there.
  void jumpToClamped(double pixels) {
    final target = clampDouble(pixels, minScrollExtent, maxScrollExtent);
    if (target != this.pixels) jumpTo(target);
  }
}

/// A slot a dragged tab would drop into, 0 before the first tab through
/// `tabs.length` after the last, with the row-local x of the bar marking it.
typedef _DropSlot = ({int index, double left});

/// The sizes and rules that differ between the base and Modern UI tab
/// treatments (§spec:editor-tab-rendering), resolved once per strip build.
@immutable
class _EditorTabMetrics {
  /// Renders the Modern UI pills rather than the base tabs.
  final bool pills;

  /// The strip's height.
  final double stripHeight;

  /// Inset from the strip's leading edge to the first tab.
  final double stripInset;

  /// A tab's leading inset without an icon, and with one.
  final double paddingStart;
  final double paddingStartWithIcon;

  /// A tab's trailing inset when it reserves no action column, and when it
  /// does. The action column supplies the trailing room when it shows.
  final double paddingEnd;
  final double paddingEndWithActions;

  /// Inset above and below a tab's content row, which the drop bar shares.
  final double rowInset;

  /// The action column's width, and its margin either side.
  final double actionsWidth;
  final double actionsMargin;

  /// Hovering anywhere on a tab recolours an inactive label and reveals a
  /// dirty tab's close glyph, rather than the pointer having to be over the
  /// action column itself.
  final bool tabHoverReveals;

  /// Every closable tab shows its close button, not only the active or
  /// hovered one.
  final bool actionsAlwaysVisible;

  const _EditorTabMetrics._({
    required this.pills,
    required this.stripHeight,
    required this.stripInset,
    required this.paddingStart,
    required this.paddingStartWithIcon,
    required this.paddingEnd,
    required this.paddingEndWithActions,
    required this.rowInset,
    required this.actionsWidth,
    required this.actionsMargin,
    required this.tabHoverReveals,
    required this.actionsAlwaysVisible,
  });

  /// `multieditortabscontrol.css`: a full-height row; `.tab { padding-left:
  /// 10px }`, with `.close-action-off` padding the trailing edge only when
  /// no action column shows.
  static const base = _EditorTabMetrics._(
    pills: false,
    stripHeight: WorkbenchLayoutConstants.editorTabHeight,
    stripInset: 0,
    paddingStart: WorkbenchLayoutConstants.editorTabPaddingStart,
    paddingStartWithIcon: WorkbenchLayoutConstants.editorTabPaddingStart,
    paddingEnd: WorkbenchLayoutConstants.editorTabPaddingEnd,
    paddingEndWithActions: 0,
    rowInset: 0,
    actionsWidth: WorkbenchLayoutConstants.editorTabActionsWidth,
    actionsMargin: 0,
    tabHoverReveals: false,
    actionsAlwaysVisible: false,
  );

  /// VS Code 1.138.0's `tabs.css`: the label on the 24px row between the
  /// transparent bands, and the 24px action column with its 2px margins
  /// filling the 28px a tab reserves at its trailing edge. Upstream overlays
  /// the column on that reserved padding; laying it out in the row gives the
  /// same geometry. `workbench.editor.tabActionReserveSpace` defaults to
  /// `true`, which keeps the close button on every tab of the active group.
  static const modern = _EditorTabMetrics._(
    pills: true,
    stripHeight: WorkbenchLayoutConstants.modernEditorTabStripHeight,
    stripInset: WorkbenchLayoutConstants.modernEditorTabStripInset,
    paddingStart: WorkbenchLayoutConstants.modernEditorTabPadding,
    paddingStartWithIcon: WorkbenchLayoutConstants.modernEditorTabPaddingStart,
    paddingEnd: WorkbenchLayoutConstants.modernEditorTabPadding,
    paddingEndWithActions: 0,
    rowInset: WorkbenchLayoutConstants.modernEditorTabRowInset,
    actionsWidth: WorkbenchLayoutConstants.modernEditorTabActionsWidth,
    actionsMargin: WorkbenchLayoutConstants.modernEditorTabActionsMargin,
    tabHoverReveals: true,
    actionsAlwaysVisible: true,
  );
}

/// One tab, per `multieditortabscontrol.css` in the base treatment and
/// `tabs.css` under Modern UI.
class _EditorTab extends StatefulWidget {
  final WorkbenchEditorTab tab;
  final bool active;

  /// The treatment's sizes and hover rules.
  final _EditorTabMetrics metrics;

  final VoidCallback onSelected;

  /// Requests this tab's close. Null renders no close button.
  final VoidCallback? onClose;
  final WorkbenchTheme theme;

  const _EditorTab({
    super.key,
    required this.tab,
    required this.active,
    required this.metrics,
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
    final Color foreground;
    if (!metrics.pills) {
      foreground = active
          ? theme.tabActiveForeground
          : theme.tabInactiveForeground;
    } else if (active) {
      foreground = theme.modernEditorTabActiveForeground;
    } else if (_tabHovered) {
      foreground = theme.modernEditorTabHoverForeground;
    } else {
      foreground = theme.modernEditorTabInactiveForeground;
    }
    // `.tab-actions` shows for a closable tab and for a dirty one: the
    // unsaved dot is state, so it stays even with no close affordance.
    final showsActions = widget.onClose != null || tab.isDirty;
    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: tab.icon == null
            ? metrics.paddingStart
            : metrics.paddingStartWithIcon,
        end: showsActions ? metrics.paddingEndWithActions : metrics.paddingEnd,
        top: metrics.rowInset,
        bottom: metrics.rowInset,
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
          child: metrics.pills ? _buildPill(content) : _buildBase(content),
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

  /// The pill tab: content-sized (`.sizing-fit { width: auto; min-width: 0
  /// }`) over its `.tab-fill`, a 24px rounded fill inset from the tab's edges.
  /// The active pill fills, a hovered one takes the hover fill, and an
  /// inactive one stays clear (`modernEditorTab.inactiveBackground` registers
  /// as transparent).
  Widget _buildPill(Widget content) {
    final theme = widget.theme;
    final Color? fill;
    if (widget.active) {
      fill = _tabHovered
          ? theme.modernEditorTabActiveHoverBackground
          : theme.modernEditorTabActiveBackground;
    } else {
      fill = _tabHovered ? theme.modernEditorTabHoverBackground : null;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: WorkbenchLayoutConstants.modernEditorTabFillInset,
              vertical: WorkbenchLayoutConstants.modernEditorTabRowInset,
            ),
            child: DecoratedBox(
              key: const ValueKey('editor-tab-pill-fill'),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(
                  WorkbenchLayoutConstants.cornerRadiusSmall,
                ),
              ),
            ),
          ),
        ),
        content,
      ],
    );
  }

  /// The trailing action column: the close button, or a dirty tab's dot.
  ///
  /// Upstream's base `.tab-actions` rules show it on the active tab, on hover,
  /// and on a dirty tab, and hide it (opacity 0) otherwise; under Modern UI
  /// the reserved column shows on every tab. A hidden button takes no
  /// pointer, so a tap there activates the tab instead of closing an editor
  /// the user cannot see a button for.
  ///
  /// A dirty tab shows its dot until the pointer reveals the close glyph: in
  /// the base treatment the pointer has to be over the column itself; under
  /// Modern UI, `tabs.css` swaps the glyph on `.tab.dirty:hover`, anywhere on
  /// the tab.
  Widget _buildActions(Color foreground) {
    final tab = widget.tab;
    final onClose = widget.onClose;
    final metrics = widget.metrics;
    final visible =
        widget.active ||
        _tabHovered ||
        tab.isDirty ||
        metrics.actionsAlwaysVisible;
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

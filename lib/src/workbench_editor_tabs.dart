import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:meta/meta.dart';

import 'layout_constants.dart';
import 'workbench_intents.dart';
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
    FocusManager.instance.addListener(_adoptKeyFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _adoptKeyFocus());
    _internalActiveId = widget.initialActiveId;
    _order.addAll(widget.tabs.map((tab) => tab.id));
    _recordActive();
  }

  @override
  void didUpdateWidget(covariant EditorTabsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadTabs = _order.isNotEmpty;
    if (!identical(oldWidget.tabs, widget.tabs)) _reconcile();
    // Covers a controlled host's change as well as the reconcile's own.
    _recordActive();
    // Gaining tabs gains the bindings, which need focus to hear keys.
    if (!hadTabs && _order.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _adoptKeyFocus());
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_adoptKeyFocus);
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

  /// Receives key events for the editor-tab bindings. `Shortcuts` sees only
  /// events that bubble up from the primary focus, so this node holds focus
  /// whenever nothing inside the workbench does (see [_adoptKeyFocus]).
  final FocusNode _keysFocusNode = FocusNode(
    debugLabel: 'WorkbenchLayout editor tab keys',
  );

  /// Take primary focus when it rests above the workbench — on a wrapper such
  /// as `WorkbenchShortcuts`, a route scope, or nowhere — so the editor-tab
  /// chords reach the bindings without the user first clicking into the
  /// workbench. Focus inside the workbench, or in another route, is left
  /// alone, and bindings above still see every event because it bubbles
  /// through them.
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
        onSelected: _setActive,
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

  /// Activates a tab from a click.
  final ValueChanged<String> onSelected;

  /// Requests a tab's close. Null renders no close buttons.
  final ValueChanged<String>? onCloseRequested;

  final WorkbenchTheme theme;

  const EditorTabsPart({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.content,
    required this.onSelected,
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

/// VS Code's classic multi-tab strip (§spec:editor-tab-rendering): a
/// [WorkbenchLayoutConstants.editorTabHeight] row in
/// `editorGroupHeader.tabsBackground`, one `fit`-sized tab per editor.
///
/// Tabs past the strip's width are clipped at its trailing edge until
/// overflow scrolling lands (§spec:editor-tab-interaction).
@internal
class EditorTabStrip extends StatelessWidget {
  final List<WorkbenchEditorTab> tabs;
  final String activeId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onCloseRequested;
  final WorkbenchTheme theme;

  const EditorTabStrip({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelected,
    required this.onCloseRequested,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final onClose = onCloseRequested;
    return SizedBox(
      height: WorkbenchLayoutConstants.editorTabHeight,
      child: ColoredBox(
        color: theme.editorGroupHeaderTabsBackground,
        child: Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          child: ClipRect(
            // Lets the row keep its natural width without an overflow
            // warning; the clip hides whatever runs past the strip.
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              maxWidth: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in tabs)
                    _EditorTab(
                      key: ValueKey('editor-tab-${tab.id}'),
                      tab: tab,
                      active: tab.id == activeId,
                      onSelected: () => onSelected(tab.id),
                      onClose: onClose == null ? null : () => onClose(tab.id),
                      theme: theme,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab in the base treatment, per `multieditortabscontrol.css`.
class _EditorTab extends StatefulWidget {
  final WorkbenchEditorTab tab;
  final bool active;
  final VoidCallback onSelected;

  /// Requests this tab's close. Null renders no close button.
  final VoidCallback? onClose;
  final WorkbenchTheme theme;

  const _EditorTab({
    super.key,
    required this.tab,
    required this.active,
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
  /// dot back to the close glyph (`.action-label:not(:hover)::before`).
  bool _actionHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tab = widget.tab;
    final active = widget.active;
    final foreground = active
        ? theme.tabActiveForeground
        : theme.tabInactiveForeground;
    // `.tab-actions` shows for a closable tab and for a dirty one: the
    // unsaved dot is state, so it stays even with no close affordance.
    final showsActions = widget.onClose != null || tab.isDirty;
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
          child: Container(
            constraints: const BoxConstraints(
              minWidth: WorkbenchLayoutConstants.editorTabMinWidth,
            ),
            decoration: BoxDecoration(
              color: active
                  ? theme.tabActiveBackground
                  : theme.tabInactiveBackground,
              border: Border(right: BorderSide(color: theme.tabBorder)),
            ),
            child: _activeRules(
              Padding(
                // The action column supplies the trailing room when it shows
                // (`.close-action-off` pads only when it does not).
                padding: EdgeInsetsDirectional.only(
                  start: WorkbenchLayoutConstants.editorTabPaddingStart,
                  end: showsActions
                      ? 0
                      : WorkbenchLayoutConstants.editorTabPaddingEnd,
                ),
                child: Row(
                  // `.tab-label { flex: 1 }` pushes the actions to the
                  // trailing edge of a tab wider than its content. The strip
                  // lays tabs out at their natural width, so the free space
                  // is distributed rather than flexed into.
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
                          style: theme.editorTabLabel.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                    if (showsActions) _buildActions(foreground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The trailing action column: the close button, or a dirty tab's dot.
  ///
  /// Upstream's `.tab-actions` rules show it on the active tab, on hover, and
  /// on a dirty tab, and hide it (opacity 0) otherwise. A hidden button takes
  /// no pointer, so a tap there activates the tab instead of closing an
  /// editor the user cannot see a button for.
  Widget _buildActions(Color foreground) {
    final tab = widget.tab;
    final onClose = widget.onClose;
    final visible = widget.active || _tabHovered || tab.isDirty;
    final showsDot = tab.isDirty && (onClose == null || !_actionHovered);
    final glyph = Icon(
      showsDot ? Symbols.fiber_manual_record : Symbols.close_rounded,
      fill: showsDot ? 1 : 0,
      size: WorkbenchLayoutConstants.iconMd,
      color: foreground,
    );
    return Opacity(
      key: const ValueKey('editor-tab-actions'),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: SizedBox(
          width: WorkbenchLayoutConstants.editorTabActionsWidth,
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

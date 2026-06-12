import 'package:flutter/material.dart';

import 'workbench_panel.dart';
import 'workbench_tabbed_panel.dart';
import 'workbench_view_menu.dart';

/// Scope handed to [WorkbenchPanelHost.builder]: pre-composed pieces
/// the consumer wires into the surrounding chrome.
///
/// The host owns active-tab persistence, lifecycle signaling, and
/// tab-id ↔ panel resolution; the consumer keeps placement control
/// and decides where the menu, shortcut wrapping, and tab strip go in
/// its widget tree.
@immutable
class WorkbenchPanelScope {
  /// View-menu descriptors derived from the panel list (one entry per
  /// panel that supplies a `focusIntent`). Pass to [WorkbenchMenuBar].
  final List<WorkbenchViewMenuTab> viewMenuTabs;

  /// Pre-built tabbed bottom panel — drop into
  /// [WorkbenchLayout.bottomPanel].
  final Widget tabbedPanel;

  /// Shortcut activator → intent map derived from each panel's
  /// optional `shortcut` and `focusIntent`. Wrap the tree in a
  /// `Shortcuts` widget with this map so the host's `Action`
  /// registrations fire on key activation.
  final Map<ShortcutActivator, Intent> shortcuts;

  const WorkbenchPanelScope({
    required this.viewMenuTabs,
    required this.tabbedPanel,
    required this.shortcuts,
  });
}

/// Builder signature for [WorkbenchPanelHost.builder].
typedef WorkbenchPanelScopeBuilder =
    Widget Function(BuildContext context, WorkbenchPanelScope scope);

/// Composes a list of [WorkbenchPanel] descriptors into the View menu,
/// tab strip, keyboard-shortcut map, and per-panel [PanelLifecycle]
/// signaling — the four surfaces consumers used to maintain in
/// parallel.
///
/// **Lifecycle ownership**. The host owns one
/// [PanelLifecycleController] per panel, keyed by `panel.id`.
/// `isFocused` evaluates as `panelVisible && activeId == panel.id`
/// and re-publishes whenever either input changes. Controllers
/// outlive panel-list reshape diffs that retain the same id; new
/// ids get fresh controllers, dropped ids dispose theirs.
///
/// **Active-tab persistence**. The active panel id survives a
/// `panelVisible` toggle — hide the panel, show it again, and the
/// previously focused tab returns. The host clamps the persisted id
/// to the current panel set on every rebuild, falling back to the
/// first panel if the previous id has been removed.
///
/// **Menu derivation**. Panels with a non-null `focusIntent` produce
/// View-menu entries; panels without one are omitted (the host has
/// no intent to dispatch on selection). Consumers that need the
/// menu entry must supply the intent and register a matching
/// `Action<Intent>` in a surrounding `Actions` widget — the existing
/// §spec:action-dispatch contract.
///
/// **Builder pattern**. The widget exposes its derived scope through
/// [builder] rather than rendering chrome itself, so consumers stay
/// in control of placement (menu position, shortcut wrapping,
/// surrounding `WorkbenchLayout` parameters).
class WorkbenchPanelHost extends StatefulWidget {
  /// Ordered panel descriptors. Must be non-empty.
  final List<WorkbenchPanel> panels;

  /// Whether the bottom panel is currently visible. Drives the
  /// per-panel `PanelLifecycle.isFocused` value alongside the
  /// active-tab notifier.
  final bool panelVisible;

  /// Invoked when the tab strip's close button fires.
  final VoidCallback onTogglePanel;

  /// Optional initial active tab id. Defaults to the first panel.
  /// Ignored on subsequent rebuilds — the host owns active-tab state
  /// after the first frame.
  final Object? initialActiveId;

  /// Optional registration callback. The host invokes this once with
  /// a closure that focuses any panel by id; consumers store the
  /// closure and call it from `Action<Intent>` handlers (typical
  /// pattern: a focus-panel intent dispatches into this callback so
  /// menu and shortcut activation both route through the host's
  /// active-tab notifier).
  final void Function(void Function(Object id) focusById)? onRegisterFocus;

  /// Notified whenever the active panel id changes — fires once after
  /// the first frame and then on every tab change. Useful for hosts
  /// that mirror the active panel for focus-or-hide selection
  /// semantics in the View menu.
  final ValueChanged<Object>? onActiveTabChanged;

  /// Builds the surrounding tree using the derived scope.
  final WorkbenchPanelScopeBuilder builder;

  const WorkbenchPanelHost({
    super.key,
    required this.panels,
    required this.panelVisible,
    required this.onTogglePanel,
    required this.builder,
    this.initialActiveId,
    this.onRegisterFocus,
    this.onActiveTabChanged,
  }) : assert(
         panels.length > 0,
         'WorkbenchPanelHost requires at least one panel',
       );

  @override
  State<WorkbenchPanelHost> createState() => _WorkbenchPanelHostState();
}

class _WorkbenchPanelHostState extends State<WorkbenchPanelHost> {
  /// Currently active panel id. Persists across `panelVisible`
  /// toggles. Clamped to the current panel set on each build.
  // ignore: avoid-late-keyword
  late final ValueNotifier<Object?> _activeId;

  /// One controller per panel id. Kept across rebuilds for stable
  /// `PanelLifecycle` identities.
  final Map<Object, PanelLifecycleController> _lifecycles = {};

  /// Captured from the inner [WorkbenchTabbedPanel] so the host can
  /// drive tab focus from menu/shortcut intents.
  ValueChanged<String>? _focusTabById;

  @override
  void initState() {
    super.initState();
    final first = widget.panels.first.id;
    _activeId = ValueNotifier<Object?>(widget.initialActiveId ?? first);
    _syncLifecycleControllers();
    _refreshLifecycles();
    _activeId.addListener(_refreshLifecycles);
  }

  @override
  void didUpdateWidget(covariant WorkbenchPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final visibilityChanged = oldWidget.panelVisible != widget.panelVisible;
    final panelsChanged = !_panelIdsEqual(oldWidget.panels, widget.panels);
    if (panelsChanged) {
      _syncLifecycleControllers();
      _clampActiveId();
    }
    if (visibilityChanged || panelsChanged) {
      _refreshLifecycles();
    }
  }

  @override
  void dispose() {
    _activeId.removeListener(_refreshLifecycles);
    _activeId.dispose();
    for (final controller in _lifecycles.values) {
      controller.dispose();
    }
    _lifecycles.clear();
    super.dispose();
  }

  bool _panelIdsEqual(List<WorkbenchPanel> a, List<WorkbenchPanel> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  void _syncLifecycleControllers() {
    final currentIds = widget.panels.map((p) => p.id).toSet();
    // Drop controllers whose panel id is no longer in the list.
    final removed = _lifecycles.keys
        .where((id) => !currentIds.contains(id))
        .toList(growable: false);
    for (final id in removed) {
      _lifecycles.remove(id)?.dispose();
    }
    // Create controllers for newly-introduced ids.
    for (final panel in widget.panels) {
      _lifecycles.putIfAbsent(panel.id, PanelLifecycleController.new);
    }
  }

  void _clampActiveId() {
    final currentIds = widget.panels.map((p) => p.id).toSet();
    if (!currentIds.contains(_activeId.value)) {
      _activeId.value = widget.panels.first.id;
    }
  }

  void _refreshLifecycles() {
    final activeId = _activeId.value;
    for (final entry in _lifecycles.entries) {
      entry.value.focused = widget.panelVisible && entry.key == activeId;
    }
  }

  /// Translate the shell-facing String tab id back to the host-facing
  /// Object id.
  Object? _resolveObjectId(String stringId) {
    for (final panel in widget.panels) {
      if (panel.id.toString() == stringId) return panel.id;
    }
    return null;
  }

  void _onActiveTabChanged(String stringId) {
    final resolved = _resolveObjectId(stringId);
    if (resolved == null) return;
    if (_activeId.value != resolved) {
      _activeId.value = resolved;
    }
    widget.onActiveTabChanged?.call(resolved);
  }

  void _onRegisterFocusTab(ValueChanged<String> focusById) {
    _focusTabById = focusById;
    widget.onRegisterFocus?.call(_focus);
  }

  /// Routes to the inner tabbed panel so the active tab updates.
  void _focus(Object id) {
    _focusTabById?.call(id.toString());
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the initial tab id for the inner WorkbenchTabbedPanel —
    // it accepts only a String id. The host's _activeId is the source
    // of truth; the inner widget's notifier is rebuilt fresh on each
    // visible cycle.
    final activeStringId = _activeId.value?.toString();

    final tabbedPanel = WorkbenchTabbedPanel(
      tabs: [
        for (final panel in widget.panels)
          WorkbenchPanelTab(
            id: panel.id.toString(),
            label: panel.label,
            badge: panel.badge,
            contentBuilder: (ctx) =>
                panel.contentBuilder(ctx, _lifecycles[panel.id]!),
          ),
      ],
      initialTabId: activeStringId,
      onTogglePanel: widget.onTogglePanel,
      onActiveTabChanged: _onActiveTabChanged,
      onRegisterFocusTab: _onRegisterFocusTab,
    );

    final viewMenuTabs = <WorkbenchViewMenuTab>[
      for (final panel in widget.panels)
        if (panel.focusIntent != null)
          WorkbenchViewMenuTab(
            intent: panel.focusIntent!,
            label: panel.label,
            shortcut: panel.shortcut,
          ),
    ];

    final shortcuts = <ShortcutActivator, Intent>{
      for (final panel in widget.panels)
        if (panel.shortcut is ShortcutActivator && panel.focusIntent != null)
          panel.shortcut! as ShortcutActivator: panel.focusIntent!,
    };

    final scope = WorkbenchPanelScope(
      viewMenuTabs: viewMenuTabs,
      tabbedPanel: tabbedPanel,
      shortcuts: shortcuts,
    );

    return widget.builder(context, scope);
  }
}

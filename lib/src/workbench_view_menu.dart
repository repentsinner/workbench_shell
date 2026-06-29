import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'workbench_intents.dart';
import 'workbench_theme.dart';

/// A node in the View menu's descriptor tree (§spec:menu-model). The
/// shell renders the tree platform-agnostically: a [PlatformMenu] tree
/// on macOS, a Material [SubmenuButton] tree in-window. Hosts build the
/// tree; the shell owns only the rendering.
///
/// An entry is one of:
///
/// - [WorkbenchViewMenuTab] — a command leaf (label + intent).
/// - [WorkbenchMenuCheckbox] — a command carrying a checked state.
/// - [WorkbenchMenuRadio] — a command carrying a selected state; radio
///   entries sharing a submenu read as a mutually-exclusive set.
/// - [WorkbenchMenuSubmenu] — a nested submenu (label + children).
/// - [WorkbenchMenuSeparator] — a divider between adjacent groups.
sealed class WorkbenchMenuEntry {
  const WorkbenchMenuEntry();
}

/// Base for entries that dispatch an [Intent] when selected. The host
/// registers an `Action<Intent>` for the intent's runtime type at the
/// widget that owns the target state; the shell does not constrain the
/// intent shape — each entry carries its own.
sealed class WorkbenchMenuActionEntry extends WorkbenchMenuEntry {
  const WorkbenchMenuActionEntry();

  /// Intent dispatched via `Actions.maybeInvoke` on selection.
  Intent get intent;

  /// Label shown in the menu.
  String get label;

  /// Optional keyboard shortcut, displayed next to the label. The
  /// glyph is cosmetic — hosts bind the activator themselves via a
  /// surrounding `Shortcuts` widget. `WorkbenchShortcuts` only installs
  /// the Cmd/Ctrl+J bottom-panel toggle.
  MenuSerializableShortcut? get shortcut;
}

/// A command leaf the View menu can select. The shell does not own tab
/// content (see package SPEC §spec:tabbed-panel); it only owns the menu
/// chrome.
///
/// The menu item label is static. Selection semantics — focus the
/// tab, or hide the panel if the tab is already focused — are
/// decided by the host's registered `Action<Intent>` handler for
/// [intent].
class WorkbenchViewMenuTab extends WorkbenchMenuActionEntry {
  @override
  final Intent intent;

  @override
  final String label;

  @override
  final MenuSerializableShortcut? shortcut;

  const WorkbenchViewMenuTab({
    required this.intent,
    required this.label,
    this.shortcut,
  });
}

/// A checkable command. [checked] is the host's value, owned through
/// the same controlled/uncontrolled seam as every other property
/// (§spec:layout-customization): the entry reports the current state and
/// the host updates it via the [intent]'s `Action`. Renders a real
/// `CheckboxMenuButton` mark in-window; degrades to a leading "✓ " glyph
/// on the macOS native menu, which carries no checked field.
class WorkbenchMenuCheckbox extends WorkbenchMenuActionEntry {
  @override
  final Intent intent;

  @override
  final String label;

  @override
  final MenuSerializableShortcut? shortcut;

  /// Whether the item shows as checked.
  final bool checked;

  const WorkbenchMenuCheckbox({
    required this.intent,
    required this.label,
    required this.checked,
    this.shortcut,
  });
}

/// A radio command. Radio entries listed together in one submenu read
/// as a mutually-exclusive set: exactly one carries [selected] `true`.
/// Renders a real `RadioMenuButton` mark in-window; degrades to a
/// leading "✓ " glyph on the macOS native menu, as [WorkbenchMenuCheckbox]
/// does.
class WorkbenchMenuRadio extends WorkbenchMenuActionEntry {
  @override
  final Intent intent;

  @override
  final String label;

  @override
  final MenuSerializableShortcut? shortcut;

  /// Whether this item is the selected member of its group.
  final bool selected;

  const WorkbenchMenuRadio({
    required this.intent,
    required this.label,
    required this.selected,
    this.shortcut,
  });
}

/// A nested submenu — a label plus its own [children] tree. Nests
/// natively on every platform (`PlatformMenu` on macOS, `SubmenuButton`
/// in-window), so it needs no degradation.
class WorkbenchMenuSubmenu extends WorkbenchMenuEntry {
  /// Label shown on the parent menu, opening [children] on hover.
  final String label;

  /// Entries rendered inside the submenu.
  final List<WorkbenchMenuEntry> children;

  const WorkbenchMenuSubmenu({required this.label, required this.children});
}

/// A divider between adjacent menu groups. Leading and trailing
/// separators, and runs of consecutive separators, collapse to nothing.
class WorkbenchMenuSeparator extends WorkbenchMenuEntry {
  const WorkbenchMenuSeparator();
}

bool _isMacOS() => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Platform-aware workbench menu bar.
///
/// On macOS, installs a [PlatformMenuBar] so the menu surfaces in
/// the system menu bar (with standard app/window/help defaults and
/// native keyboard-shortcut rendering). On other platforms, renders
/// an in-window Material [MenuBar] above [child].
///
/// The View menu is modeled on VS Code: the shell renders the
/// host-supplied [entries] tree (§spec:menu-model) — commands, submenus,
/// separators, and checkable/radio items. Each command dispatches its
/// own [Intent] via `Actions.invoke`; hosts register the matching
/// `Action<Intent>` at the widget that owns the target state. The shell
/// publishes one default intent, [ToggleBottomPanelIntent], bound to
/// Cmd/Ctrl+J by `WorkbenchShortcuts`; hosts add a Panel entry to the
/// tree if they want a menu affordance for it.
class WorkbenchMenuBar extends StatelessWidget {
  /// The View menu's entry tree (§spec:menu-model). Each command-bearing
  /// node dispatches its [WorkbenchMenuActionEntry.intent] on selection.
  final List<WorkbenchMenuEntry> entries;

  /// Child widget tree to wrap. On macOS, [PlatformMenuBar] passes
  /// this through unchanged while attaching menus to the system
  /// menu bar. On other platforms, a Material [MenuBar] is stacked
  /// above [child].
  final Widget child;

  /// When set, forces the native (macOS system menu bar) vs
  /// in-window rendering path. Intended for tests; production
  /// code should leave this null to use the platform default.
  final bool? useNativeMenuBar;

  /// Label for the macOS application menu (the leftmost system-menu
  /// entry, bold by convention). The shell carries no host identity,
  /// so this defaults to the neutral [defaultApplicationMenuLabel];
  /// hosts pass their own application name. macOS shows the bundle's
  /// `CFBundleName` for the app-menu *title* regardless, but
  /// `PlatformMenu.label` must still be non-empty.
  ///
  /// Only the macOS path consumes this; the in-window Material menu
  /// bar renders no application menu.
  final String applicationMenuLabel;

  /// Neutral, host-agnostic default for [applicationMenuLabel]. Keeps
  /// `workbench_shell` free of any host's name so third-party
  /// consumers get a generic label rather than a specific product name.
  static const String defaultApplicationMenuLabel = 'App';

  const WorkbenchMenuBar({
    super.key,
    required this.entries,
    required this.child,
    this.useNativeMenuBar,
    this.applicationMenuLabel = defaultApplicationMenuLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (useNativeMenuBar ?? _isMacOS()) {
      return _buildMacOSMenuBar(context);
    }
    return _buildInWindowMenuBar(context);
  }

  Widget _buildMacOSMenuBar(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: applicationMenuLabel,
          menus: const [
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.servicesSubmenu,
            ),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.hideOtherApplications,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.showAllApplications,
            ),
            PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: _buildPlatformChildren(context, entries),
        ),
        const PlatformMenu(
          label: 'Window',
          menus: [
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.minimizeWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.zoomWindow,
            ),
            PlatformProvidedMenuItem(
              type: PlatformProvidedMenuItemType.toggleFullScreen,
            ),
          ],
        ),
      ],
      child: child,
    );
  }

  Widget _buildInWindowMenuBar(BuildContext context) {
    final workbench = context.workbenchTheme;
    // Force the Material `MenuBar` chrome to read from
    // `WorkbenchTheme` rather than the ambient `ThemeData`. macOS
    // is untouched — it renders through `PlatformMenuBar`, which
    // binds to `NSMenu` and ignores Material theming.
    //
    // `MenuButtonThemeData` covers both the top-level `SubmenuButton`
    // in the bar and the `MenuItemButton` entries in the submenu —
    // both descend from Flutter's private menu-button base class and
    // resolve through `MenuButtonTheme`. Flutter does not expose a
    // separate `SubmenuButtonTheme`.
    final foreground = workbench.menuBarForeground;
    final hoverBackground = workbench.menuBarHoverBackground;
    final menuSurface = workbench.panelBackground;
    final labelStyle = workbench.helperStyle.copyWith(color: foreground);
    final menuBarTheme = MenuBarThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(workbench.menuBarBackground),
        elevation: const WidgetStatePropertyAll(0),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      ),
    );
    final menuButtonTheme = MenuButtonThemeData(
      style: ButtonStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(foreground),
        overlayColor: WidgetStatePropertyAll(hoverBackground),
        textStyle: WidgetStatePropertyAll(labelStyle),
        iconColor: WidgetStatePropertyAll(foreground),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      ),
    );
    final menuTheme = MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(menuSurface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(2),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
      ),
    );
    final dividerTheme = DividerThemeData(color: workbench.menuBarBorder);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            menuBarTheme: menuBarTheme,
            menuButtonTheme: menuButtonTheme,
            menuTheme: menuTheme,
            dividerTheme: dividerTheme,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: workbench.menuBarBackground,
              border: Border(
                bottom: BorderSide(color: workbench.menuBarBorder),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MenuBar(
                children: [
                  SubmenuButton(
                    menuChildren: _buildMaterialChildren(context, entries),
                    child: const Text('View'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// Returns a [PlatformMenuItem.onSelected] callback that dispatches
  /// [intent] when the host's registered action reports enabled, or
  /// `null` (which disables the native menu item) otherwise.
  ///
  /// Evaluated at build time: `PlatformMenuBar` rebuilds when its
  /// child tree rebuilds, so hosts that want live enable-state updates
  /// trigger a rebuild of [WorkbenchMenuBar] (e.g. by wrapping it in
  /// a [ListenableBuilder] tied to the same source of truth).
  VoidCallback? _onSelectedFor(BuildContext context, Intent intent) {
    final action = Actions.maybeFind<Intent>(context, intent: intent);
    if (action == null || !action.isEnabled(intent)) return null;
    return () => Actions.maybeInvoke(context, intent);
  }

  // --- macOS native path (PlatformMenu tree) ---

  /// Builds the native menu children for [entries], splitting the list
  /// into [PlatformMenuItemGroup] runs at each [WorkbenchMenuSeparator]
  /// so the native menu draws a divider between groups. A single run
  /// (no separators) is returned unwrapped, since a lone group draws no
  /// divider.
  List<PlatformMenuItem> _buildPlatformChildren(
    BuildContext context,
    List<WorkbenchMenuEntry> entries,
  ) {
    final groups = <List<PlatformMenuItem>>[<PlatformMenuItem>[]];
    for (final entry in entries) {
      switch (entry) {
        case WorkbenchMenuSeparator():
          if (groups.last.isNotEmpty) groups.add(<PlatformMenuItem>[]);
        case WorkbenchMenuSubmenu(:final label, :final children):
          groups.last.add(
            PlatformMenu(
              label: label,
              menus: _buildPlatformChildren(context, children),
            ),
          );
        case final WorkbenchMenuActionEntry entry:
          groups.last.add(
            PlatformMenuItem(
              // The native menu carries no checked field, so a checked
              // checkbox/radio degrades to a leading "✓ " glyph
              // (§spec:menu-model).
              label: _platformLabel(entry),
              shortcut: entry.shortcut,
              onSelected: _onSelectedFor(context, entry.intent),
            ),
          );
      }
    }
    groups.removeWhere((group) => group.isEmpty);
    if (groups.length <= 1) {
      return groups.isEmpty ? const <PlatformMenuItem>[] : groups.single;
    }
    return [for (final group in groups) PlatformMenuItemGroup(members: group)];
  }

  String _platformLabel(WorkbenchMenuActionEntry entry) => switch (entry) {
    WorkbenchMenuCheckbox(:final label, :final checked) =>
      checked ? '✓ $label' : label,
    WorkbenchMenuRadio(:final label, :final selected) =>
      selected ? '✓ $label' : label,
    WorkbenchViewMenuTab(:final label) => label,
  };

  // --- in-window Material path (SubmenuButton tree) ---

  /// Builds the Material menu children for [entries]. Separators render
  /// as a [Divider]; submenus nest a [SubmenuButton]; command-bearing
  /// entries render an enable-aware checkbox/radio/command button.
  List<Widget> _buildMaterialChildren(
    BuildContext context,
    List<WorkbenchMenuEntry> entries,
  ) {
    return [
      for (final entry in entries)
        switch (entry) {
          WorkbenchMenuSeparator() => const Divider(height: 1),
          WorkbenchMenuSubmenu(:final label, :final children) => SubmenuButton(
            menuChildren: _buildMaterialChildren(context, children),
            child: Text(label),
          ),
          final WorkbenchMenuActionEntry entry => _EnableAwareMenuEntry(
            key: ValueKey(
              'view-menu-${entry.intent.runtimeType}-${entry.label}',
            ),
            entry: entry,
            dispatchContext: context,
          ),
        },
    ];
  }
}

/// Renders one command-bearing [WorkbenchMenuActionEntry] — a command,
/// checkbox, or radio — on the in-window Material path, mirroring the
/// enable state of the host's registered `Action<Intent>`. When no
/// matching action exists, or the action reports `isActionEnabled ==
/// false`, the item renders with a null callback, which Material's menu
/// paints as disabled.
///
/// Subscribes to the action via [Action.addActionListener] so that
/// hosts can toggle availability at runtime (e.g. register or
/// unregister a bottom-panel tab) and the menu re-renders without a
/// full parent rebuild.
class _EnableAwareMenuEntry extends StatefulWidget {
  const _EnableAwareMenuEntry({
    super.key,
    required this.entry,
    required this.dispatchContext,
  });

  final WorkbenchMenuActionEntry entry;
  final BuildContext dispatchContext;

  @override
  State<_EnableAwareMenuEntry> createState() => _EnableAwareMenuEntryState();
}

class _EnableAwareMenuEntryState extends State<_EnableAwareMenuEntry> {
  Action<Intent>? _action;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateActionSubscription();
  }

  @override
  void didUpdateWidget(_EnableAwareMenuEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.intent.runtimeType !=
            widget.entry.intent.runtimeType ||
        oldWidget.dispatchContext != widget.dispatchContext) {
      _updateActionSubscription();
    }
  }

  void _updateActionSubscription() {
    final resolved = Actions.maybeFind<Intent>(
      widget.dispatchContext,
      intent: widget.entry.intent,
    );
    if (identical(resolved, _action)) return;
    _action?.removeActionListener(_handleActionChanged);
    _action = resolved;
    _action?.addActionListener(_handleActionChanged);
  }

  void _handleActionChanged(Action<Intent> action) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _action?.removeActionListener(_handleActionChanged);
    super.dispose();
  }

  void _invoke() =>
      Actions.maybeInvoke(widget.dispatchContext, widget.entry.intent);

  @override
  Widget build(BuildContext context) {
    final action = _action;
    final enabled = action != null && action.isEnabled(widget.entry.intent);
    final entry = widget.entry;
    final label = Text(entry.label);
    switch (entry) {
      case WorkbenchMenuCheckbox(:final checked):
        return CheckboxMenuButton(
          value: checked,
          shortcut: entry.shortcut,
          onChanged: enabled ? (_) => _invoke() : null,
          child: label,
        );
      case WorkbenchMenuRadio(:final selected):
        // A single boolean RadioMenuButton: the value is selected
        // against a group value that equals it only when this item is
        // the chosen one, so the real radio mark tracks [selected].
        return RadioMenuButton<bool>(
          value: true,
          groupValue: selected,
          shortcut: entry.shortcut,
          onChanged: enabled ? (_) => _invoke() : null,
          child: label,
        );
      case WorkbenchViewMenuTab():
        return MenuItemButton(
          shortcut: entry.shortcut,
          onPressed: enabled ? _invoke : null,
          child: label,
        );
    }
  }
}

/// Keyboard shortcut wrapper for the one command the shell defaults:
/// Cmd/Ctrl+J to toggle the bottom panel.
///
/// Dispatches [ToggleBottomPanelIntent] via Flutter's `Shortcuts`
/// primitive; hosts register `Action<ToggleBottomPanelIntent>` at the
/// widget that owns the panel-visibility flag.
///
/// The shell ships only this single binding. Hosts install any other
/// workbench shortcuts (tab-focus, command-palette, etc.) via a
/// surrounding `Shortcuts` widget with their own intent vocabulary.
/// Host-specific extras can also pass through [extraShortcuts], which
/// merges into the default map.
class WorkbenchShortcuts extends StatelessWidget {
  final Widget child;

  /// Extra app-defined shortcuts merged into the default map.
  final Map<ShortcutActivator, Intent>? extraShortcuts;

  const WorkbenchShortcuts({
    super.key,
    required this.child,
    this.extraShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      // Bottom panel toggle: Cmd+J on macOS, Ctrl+J elsewhere. Both
      // activators live in the map so the binding fires regardless of
      // which platform the user is on.
      const SingleActivator(LogicalKeyboardKey.keyJ, meta: true):
          const ToggleBottomPanelIntent(),
      const SingleActivator(LogicalKeyboardKey.keyJ, control: true):
          const ToggleBottomPanelIntent(),
      ...?extraShortcuts,
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Focus(autofocus: true, child: child),
    );
  }
}

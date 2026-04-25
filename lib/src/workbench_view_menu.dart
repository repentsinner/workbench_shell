import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'workbench_intents.dart';
import 'workbench_theme.dart';

/// Descriptor for a bottom-panel tab the View menu can select. The
/// shell does not own tab content (see package SPEC §9.14 item 2 —
/// tabbed-panel primitive); it only owns the menu chrome.
///
/// The menu item label is static. Selection semantics — focus the
/// tab, or hide the panel if the tab is already focused — are
/// decided by the host's registered `Action<Intent>` handler for
/// [intent].
class WorkbenchViewMenuTab {
  /// Intent dispatched via `Actions.invoke` when the user selects this
  /// menu entry. Hosts register an `Action<Intent>` for the intent's
  /// runtime type at the widget that owns the target state. The shell
  /// does not constrain intent shape — each tab carries its own.
  final Intent intent;

  /// Label shown in the View menu.
  final String label;

  /// Optional keyboard shortcut, displayed next to the label. The
  /// shortcut glyph is cosmetic — hosts bind the activator themselves
  /// via a surrounding `Shortcuts` widget. `WorkbenchShortcuts` only
  /// installs the Cmd/Ctrl+J bottom-panel toggle.
  final MenuSerializableShortcut? shortcut;

  const WorkbenchViewMenuTab({
    required this.intent,
    required this.label,
    this.shortcut,
  });
}

bool _isMacOS() => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Platform-aware workbench menu bar.
///
/// On macOS, installs a [PlatformMenuBar] so the menu surfaces in
/// the system menu bar (with standard app/window/help defaults and
/// native keyboard-shortcut rendering). On other platforms, renders
/// an in-window Material [MenuBar] above [child].
///
/// The View menu is modeled on VS Code: a static "Panel" entry that
/// dispatches [ToggleBottomPanelIntent], followed by static entries
/// for each host-supplied tab. Each tab dispatches its own [Intent]
/// via `Actions.invoke`; hosts register the matching
/// `Action<Intent>` at the widget that owns the target state.
class WorkbenchMenuBar extends StatelessWidget {
  /// Tab descriptors. Each generates a static menu item that dispatches
  /// its [WorkbenchViewMenuTab.intent] on selection.
  final List<WorkbenchViewMenuTab> tabs;

  /// Child widget tree to wrap. On macOS, [PlatformMenuBar] passes
  /// this through unchanged while attaching menus to the system
  /// menu bar. On other platforms, a Material [MenuBar] is stacked
  /// above [child].
  final Widget child;

  /// When set, forces the native (macOS system menu bar) vs
  /// in-window rendering path. Intended for tests; production
  /// code should leave this null to use the platform default.
  final bool? useNativeMenuBar;

  const WorkbenchMenuBar({
    super.key,
    required this.tabs,
    required this.child,
    this.useNativeMenuBar,
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
        const PlatformMenu(
          label: 'Rove',
          menus: [
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
          menus: [
            PlatformMenuItem(
              label: 'Panel',
              shortcut: const SingleActivator(
                LogicalKeyboardKey.keyJ,
                meta: true,
              ),
              onSelected: _onSelectedFor(
                context,
                const ToggleBottomPanelIntent(),
              ),
            ),
            PlatformMenuItemGroup(
              members: [
                for (final tab in tabs)
                  PlatformMenuItem(
                    label: tab.label,
                    shortcut: tab.shortcut,
                    onSelected: _onSelectedFor(context, tab.intent),
                  ),
              ],
            ),
          ],
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
                    menuChildren: [
                      _EnableAwareMenuItem(
                        key: const ValueKey('view-menu-panel'),
                        intent: const ToggleBottomPanelIntent(),
                        dispatchContext: context,
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyJ,
                          control: true,
                        ),
                        label: const Text('Panel'),
                      ),
                      const Divider(height: 1),
                      for (final tab in tabs)
                        _EnableAwareMenuItem(
                          key: ValueKey(
                            'view-menu-tab-${tab.intent.runtimeType}-${tab.label}',
                          ),
                          intent: tab.intent,
                          dispatchContext: context,
                          shortcut: tab.shortcut,
                          label: Text(tab.label),
                        ),
                    ],
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
}

/// A [MenuItemButton] that mirrors the enable state of the host's
/// registered `Action<Intent>`. When no matching action exists, or the
/// action reports `isActionEnabled == false`, the item renders with a
/// null `onPressed`, which Material's menu paints as disabled.
///
/// Subscribes to the action via [Action.addActionListener] so that
/// hosts can toggle availability at runtime (e.g. register or
/// unregister a bottom-panel tab) and the menu re-renders without a
/// full parent rebuild.
class _EnableAwareMenuItem extends StatefulWidget {
  const _EnableAwareMenuItem({
    super.key,
    required this.intent,
    required this.dispatchContext,
    required this.label,
    this.shortcut,
  });

  final Intent intent;
  final BuildContext dispatchContext;
  final Widget label;
  final MenuSerializableShortcut? shortcut;

  @override
  State<_EnableAwareMenuItem> createState() => _EnableAwareMenuItemState();
}

class _EnableAwareMenuItemState extends State<_EnableAwareMenuItem> {
  Action<Intent>? _action;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateActionSubscription();
  }

  @override
  void didUpdateWidget(_EnableAwareMenuItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intent.runtimeType != widget.intent.runtimeType ||
        oldWidget.dispatchContext != widget.dispatchContext) {
      _updateActionSubscription();
    }
  }

  void _updateActionSubscription() {
    final resolved = Actions.maybeFind<Intent>(
      widget.dispatchContext,
      intent: widget.intent,
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

  @override
  Widget build(BuildContext context) {
    final action = _action;
    final enabled = action != null && action.isEnabled(widget.intent);
    return MenuItemButton(
      shortcut: widget.shortcut,
      onPressed: enabled
          ? () => Actions.maybeInvoke(widget.dispatchContext, widget.intent)
          : null,
      child: widget.label,
    );
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

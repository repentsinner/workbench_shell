import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Descriptor for a bottom-panel tab the View menu can select. The
/// shell does not own tab content (see SPEC.md §9.14 item 2 —
/// tabbed-panel primitive); it only owns the menu chrome.
///
/// The menu item label is static. Selection semantics — focus the
/// tab, or hide the panel if the tab is already focused — are
/// decided by the host via [WorkbenchMenuBar.onSelectTab].
class WorkbenchViewMenuTab {
  /// Stable identifier for the tab. Used as menu-item key.
  final String id;

  /// Label shown in the View menu.
  final String label;

  /// Optional keyboard shortcut, displayed next to the label.
  /// The host installs the actual binding via [WorkbenchShortcuts].
  final MenuSerializableShortcut? shortcut;

  const WorkbenchViewMenuTab({
    required this.id,
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
/// toggles bottom-panel visibility, followed by static entries for
/// each bottom-panel tab. Selecting a tab focuses it (showing the
/// panel first if hidden), or hides the panel if that tab is already
/// focused. The Cmd/Ctrl+J shortcut also toggles the panel without
/// picking a tab; see [WorkbenchShortcuts].
class WorkbenchMenuBar extends StatelessWidget {
  /// Called when the user selects the static "Panel" menu item.
  /// Toggles bottom-panel visibility regardless of focused tab.
  final VoidCallback onToggleBottomPanel;

  /// Tab descriptors. Each generates a static menu item.
  final List<WorkbenchViewMenuTab> tabs;

  /// Called with the tab id when the user picks a tab from the menu.
  /// The host implements focus-or-hide semantics.
  final ValueChanged<String> onSelectTab;

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
    required this.onToggleBottomPanel,
    required this.tabs,
    required this.onSelectTab,
    required this.child,
    this.useNativeMenuBar,
  });

  @override
  Widget build(BuildContext context) {
    if (useNativeMenuBar ?? _isMacOS()) {
      return _buildMacOSMenuBar();
    }
    return _buildInWindowMenuBar(context);
  }

  Widget _buildMacOSMenuBar() {
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
              onSelected: onToggleBottomPanel,
            ),
            PlatformMenuItemGroup(
              members: [
                for (final tab in tabs)
                  PlatformMenuItem(
                    label: tab.label,
                    shortcut: tab.shortcut,
                    onSelected: () => onSelectTab(tab.id),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: MenuBar(
            children: [
              SubmenuButton(
                menuChildren: [
                  MenuItemButton(
                    key: const ValueKey('view-menu-panel'),
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyJ,
                      control: true,
                    ),
                    onPressed: onToggleBottomPanel,
                    child: const Text('Panel'),
                  ),
                  const Divider(height: 1),
                  for (final tab in tabs)
                    MenuItemButton(
                      key: ValueKey('view-menu-tab-${tab.id}'),
                      shortcut: tab.shortcut,
                      onPressed: () => onSelectTab(tab.id),
                      child: Text(tab.label),
                    ),
                ],
                child: const Text('View'),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Keyboard shortcut wrapper for workbench-level commands.
///
/// Bindings match VS Code's View menu defaults:
///
/// - Ctrl+`          — focus MDI tab (VS Code Terminal; Ctrl on all
///   platforms, including macOS — deliberately not Cmd).
/// - Cmd/Ctrl+J      — toggle bottom panel.
/// - Shift+Cmd/Ctrl+M — focus Tasks tab (VS Code Problems).
/// - Shift+Cmd/Ctrl+Y — focus Machine State tab (VS Code Debug Console).
/// - Shift+Cmd/Ctrl+U — focus Output tab (VS Code Output).
///
/// Additional bindings may be passed via [extraShortcuts]; the wrapper
/// merges them with the defaults.
class WorkbenchShortcuts extends StatelessWidget {
  final Widget child;

  /// Invoked when the user presses Ctrl+` to focus the MDI tab.
  /// Same focus-or-hide semantics as picking MDI from the View menu.
  final VoidCallback? onFocusMdi;

  /// Invoked when the user presses Cmd/Ctrl+J to toggle the bottom
  /// panel. Mirrors VS Code's default.
  final VoidCallback? onToggleBottomPanel;

  /// Invoked on Shift+Cmd/Ctrl+M to focus the Tasks tab.
  final VoidCallback? onFocusTasks;

  /// Invoked on Shift+Cmd/Ctrl+Y to focus the Machine State tab.
  final VoidCallback? onFocusMachineState;

  /// Invoked on Shift+Cmd/Ctrl+U to focus the Output tab.
  final VoidCallback? onFocusOutput;

  /// Extra app-defined shortcuts merged into the default map.
  final Map<ShortcutActivator, Intent>? extraShortcuts;

  const WorkbenchShortcuts({
    super.key,
    required this.child,
    this.onFocusMdi,
    this.onToggleBottomPanel,
    this.onFocusTasks,
    this.onFocusMachineState,
    this.onFocusOutput,
    this.extraShortcuts,
  });

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      // MDI: Ctrl+` on all platforms (matches VS Code Terminal).
      const SingleActivator(LogicalKeyboardKey.backquote, control: true):
          const _FocusMdiIntent(),
      // Bottom panel toggle: Cmd+J on macOS, Ctrl+J elsewhere.
      const SingleActivator(LogicalKeyboardKey.keyJ, meta: true):
          const _ToggleBottomPanelIntent(),
      const SingleActivator(LogicalKeyboardKey.keyJ, control: true):
          const _ToggleBottomPanelIntent(),
      // Tasks: Shift+Cmd+M / Shift+Ctrl+M.
      const SingleActivator(LogicalKeyboardKey.keyM, meta: true, shift: true):
          const _FocusTasksIntent(),
      const SingleActivator(
        LogicalKeyboardKey.keyM,
        control: true,
        shift: true,
      ): const _FocusTasksIntent(),
      // Machine State: Shift+Cmd+Y / Shift+Ctrl+Y.
      const SingleActivator(LogicalKeyboardKey.keyY, meta: true, shift: true):
          const _FocusMachineStateIntent(),
      const SingleActivator(
        LogicalKeyboardKey.keyY,
        control: true,
        shift: true,
      ): const _FocusMachineStateIntent(),
      // Output: Shift+Cmd+U / Shift+Ctrl+U.
      const SingleActivator(LogicalKeyboardKey.keyU, meta: true, shift: true):
          const _FocusOutputIntent(),
      const SingleActivator(
        LogicalKeyboardKey.keyU,
        control: true,
        shift: true,
      ): const _FocusOutputIntent(),
      ...?extraShortcuts,
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusMdiIntent: CallbackAction<_FocusMdiIntent>(
            onInvoke: (_) {
              onFocusMdi?.call();
              return null;
            },
          ),
          _ToggleBottomPanelIntent: CallbackAction<_ToggleBottomPanelIntent>(
            onInvoke: (_) {
              onToggleBottomPanel?.call();
              return null;
            },
          ),
          _FocusTasksIntent: CallbackAction<_FocusTasksIntent>(
            onInvoke: (_) {
              onFocusTasks?.call();
              return null;
            },
          ),
          _FocusMachineStateIntent: CallbackAction<_FocusMachineStateIntent>(
            onInvoke: (_) {
              onFocusMachineState?.call();
              return null;
            },
          ),
          _FocusOutputIntent: CallbackAction<_FocusOutputIntent>(
            onInvoke: (_) {
              onFocusOutput?.call();
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

class _FocusMdiIntent extends Intent {
  const _FocusMdiIntent();
}

class _ToggleBottomPanelIntent extends Intent {
  const _ToggleBottomPanelIntent();
}

class _FocusTasksIntent extends Intent {
  const _FocusTasksIntent();
}

class _FocusMachineStateIntent extends Intent {
  const _FocusMachineStateIntent();
}

class _FocusOutputIntent extends Intent {
  const _FocusOutputIntent();
}

# Changelog

## [Unreleased]

### Added

- `ToggleBottomPanelIntent` public intent exported from
  `workbench_shell`. `WorkbenchViewMenuTab` now carries an arbitrary
  `Intent`; menu items dispatch via `Actions.maybeInvoke`. The View
  menu respects each action's `Action.isEnabled` and re-renders on
  `notifyActionListeners`.

### Changed

- **Breaking:** `WorkbenchMenuBar` drops `onToggleBottomPanel` and
  `onSelectTab`; hosts wrap the shell in `Actions` and register an
  `Action<Intent>` per intent they care about.
- **Breaking:** `WorkbenchShortcuts` drops every callback prop and ships
  only the Cmd+J / Ctrl+J → `ToggleBottomPanelIntent` defaults plus
  `extraShortcuts` passthrough. Tab-focus bindings are now host-owned.
- **Breaking:** `WorkbenchViewMenuTab.id` replaced by
  `WorkbenchViewMenuTab.intent`.

## 0.1.0

- Initial release: VS Code-style workbench chrome (activity bar,
  sidebar, editor area, tabbed bottom panel, status bar, menu bar),
  structural primitives (section, subsection, card, toggle card,
  empty state), theming (`WorkbenchTheme`, `WorkbenchThemeController`,
  `TokenTheme`), layout constants, and sidebar extension slots.

# [0.4.0](https://github.com/repentsinner/workbench_shell/compare/v0.3.0...v0.4.0) (2026-06-15)


### Features

* rename WorkbenchSection to WorkbenchViewPane ([15e36a3](https://github.com/repentsinner/workbench_shell/commit/15e36a3802d9cf9f48cb2b8b78d2cce404e3df4b))

# [0.3.0](https://github.com/repentsinner/workbench_shell/compare/v0.2.1...v0.3.0) (2026-06-13)


### Features

* remove the UI extension-slot API ([8e63893](https://github.com/repentsinner/workbench_shell/commit/8e63893d46b61c05c55be36e633a1882c954f9f9))

## [0.2.1](https://github.com/repentsinner/workbench_shell/compare/v0.2.0...v0.2.1) (2026-06-12)


### Bug Fixes

* exclude repo tooling from the pub archive ([20ecf00](https://github.com/repentsinner/workbench_shell/commit/20ecf00c0d21cf012aaecea8cdbd2e4c0a4708f9))

# [0.2.0](https://github.com/repentsinner/workbench_shell/compare/v0.1.0...v0.2.0) (2026-06-12)


### Bug Fixes

* add value equality to WorkbenchTheme ([aae8f99](https://github.com/repentsinner/workbench_shell/commit/aae8f99f22ab20c99abee57f0c92e7f6b49e67dc))
* keep tabbed panel active tab aligned across tab-list reshape ([798b824](https://github.com/repentsinner/workbench_shell/commit/798b824e9dfffbcde69556e250f1533915bba83f))
* **layout:** align layout constants to VS Code canon (SPEC §8.1) ([c31fca2](https://github.com/repentsinner/workbench_shell/commit/c31fca2fa232ee266163b14cf09ff2b7cd0e2d9b))
* parse malformed theme JSON without crashing ([b3cb579](https://github.com/repentsinner/workbench_shell/commit/b3cb579691e6b2377f203d6c8e8a55a79ef7e6f8))
* re-state .gitignore artifact exclusions in .pubignore ([5646fc9](https://github.com/repentsinner/workbench_shell/commit/5646fc9cacddd752c3bb68f374bfe3f61361f330))
* support out-of-order disposal of theme controllers ([f4a2e64](https://github.com/repentsinner/workbench_shell/commit/f4a2e64b8f2228e23ea7c2e5934c7ed1bd8e6ec5))


### Features

* **theming:** theme bare IconButton under chrome via iconForeground ([b02761e](https://github.com/repentsinner/workbench_shell/commit/b02761e21b8bdc970237e82165fd886ba3d188d4)), closes [#C5C5C5](https://github.com/repentsinner/workbench_shell/issues/C5C5C5) [#424242](https://github.com/repentsinner/workbench_shell/issues/424242) [#9](https://github.com/repentsinner/workbench_shell/issues/9)


### Performance Improvements

* cache unmodifiable notifications view ([5e860a4](https://github.com/repentsinner/workbench_shell/commit/5e860a40d5fb7545f624f5cca293d653ebc413fc))
* partition activity bar items once instead of per build ([1d26b1b](https://github.com/repentsinner/workbench_shell/commit/1d26b1b0143cdd8e2f3a075cf3bbd8414e84f177))

# 0.1.0 (2026-06-10)

Initial release.

### Added

- VS Code-style workbench chrome: activity bar, sidebar, editor area,
  tabbed bottom panel, status bar, and menu bar.
- Structural content primitives: section, subsection, card, toggle card,
  and empty state.
- Theming: `WorkbenchTheme` (a Material `ThemeExtension`),
  `WorkbenchThemeController`, and `TokenTheme`, built from bundled VS Code
  color-theme JSON. `applyWorkbenchChrome(base, chrome)` composes the
  chrome's Material theming onto a host's base `ThemeData` in one call
  (SPEC §spec:chrome-material-theming). Per-host `chromeFontFamily`, `editorFontFamily`, and
  `editorFontSize` overrides; editor-derived surfaces (log lines, tabular
  values) share a single monospace style (SPEC §spec:editor-derived-surfaces).
- Intent-driven actions: `ToggleBottomPanelIntent` with Cmd+J / Ctrl+J
  defaults; `WorkbenchViewMenuTab` carries an arbitrary `Intent` dispatched
  through `Actions`.
- Notification center: `NotificationService`, `NotificationHost`, and
  `NotificationProgressController` for stacked toast cards (SPEC §spec:notification-center).
- `WorkbenchLayoutConstants` layout tokens and host-registered extension
  slots (`SlotRegistry`, `SidebarSlot`).

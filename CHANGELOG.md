# [0.23.0](https://github.com/repentsinner/workbench_shell/compare/v0.22.0...v0.23.0) (2026-06-29)


### Bug Fixes

* **example:** nest Align Panel inside Appearance to match canon ([61460a0](https://github.com/repentsinner/workbench_shell/commit/61460a03f79eebac4b0e5afe6f8291aed2fa8333))
* **example:** order Appearance toggles to match canon (Status Bar before Panel) ([4b033a2](https://github.com/repentsinner/workbench_shell/commit/4b033a26f5657a6f3df2a9fd9dc027561292fe49))


### Features

* **example:** rewire View menu to the canon submenu/checkable model ([d626c03](https://github.com/repentsinner/workbench_shell/commit/d626c03bc48d094430d7c33eb72ddb560db8ba42))
* extend View menu to a WorkbenchMenuEntry descriptor tree ([196a9cc](https://github.com/repentsinner/workbench_shell/commit/196a9cc3327373e4c500ba280f6c3d37564e8691))

# [0.22.0](https://github.com/repentsinner/workbench_shell/compare/v0.21.0...v0.22.0) (2026-06-29)


### Features

* **example:** cycle panel alignment from the View menu ([508c0e1](https://github.com/repentsinner/workbench_shell/commit/508c0e1f8ece0d9d01b46bf3dc7b1fcb552bbf41))
* **layout:** align the bottom panel by re-parenting it ([dc189aa](https://github.com/repentsinner/workbench_shell/commit/dc189aaea5a5637c235485ecf7971bb9d67f4a57))

# [0.21.0](https://github.com/repentsinner/workbench_shell/compare/v0.20.0...v0.21.0) (2026-06-29)


### Features

* **layout:** expose status bar visibility as a host property ([beae6e3](https://github.com/repentsinner/workbench_shell/commit/beae6e32e6a873e724f9f3d5d2b3f44cc1c845d2)), closes [#77](https://github.com/repentsinner/workbench_shell/issues/77)

# [0.20.0](https://github.com/repentsinner/workbench_shell/compare/v0.19.0...v0.20.0) (2026-06-29)


### Features

* **layout:** add secondary side bar on the editor's opposite edge ([c270e66](https://github.com/repentsinner/workbench_shell/commit/c270e663cc091372888694f93f973be63e9f9906))
* **layout:** expose primary side bar visibility as a host property ([fb641ca](https://github.com/repentsinner/workbench_shell/commit/fb641ca344e406130ffee3bbe73a30cddbb0aaf7))

# [0.19.0](https://github.com/repentsinner/workbench_shell/compare/v0.18.0...v0.19.0) (2026-06-29)


### Bug Fixes

* **example:** match canon — 'Move Primary Side Bar Right/Left' menu label ([a173f41](https://github.com/repentsinner/workbench_shell/commit/a173f41602a6b486d0a4167231e56590bfe3ce28))
* **layout:** preserve side bar state when moving it across edges ([70ac087](https://github.com/repentsinner/workbench_shell/commit/70ac087006a7af28e7518d8d20d1ff17a4de1b35))


### Features

* **workbench-layout:** primary side bar left/right position ([1f19a44](https://github.com/repentsinner/workbench_shell/commit/1f19a44c3a3ec4a1d264dfaa35e8415699d0ec48))

# [0.18.0](https://github.com/repentsinner/workbench_shell/compare/v0.17.0...v0.18.0) (2026-06-28)


### Features

* **sash:** reset sidebar, panel, and view-pane seams on double-click ([b767863](https://github.com/repentsinner/workbench_shell/commit/b767863b9276d837ce5d715c434e90b0af1fc447))

# [0.17.0](https://github.com/repentsinner/workbench_shell/compare/v0.16.0...v0.17.0) (2026-06-28)


### Features

* **workbench-layout:** own resize geometry, seed-plus-commit ([45b8b8e](https://github.com/repentsinner/workbench_shell/commit/45b8b8e8f70bfebf482b3829f148ba68cdea4256)), closes [#68](https://github.com/repentsinner/workbench_shell/issues/68)

# [0.16.0](https://github.com/repentsinner/workbench_shell/compare/v0.15.0...v0.16.0) (2026-06-28)


### Features

* **workbench-layout:** add Zen and Centered editing modes ([a80f83e](https://github.com/repentsinner/workbench_shell/commit/a80f83ee0289eeaaa3f381bc240054287a25e05c))

# [0.15.0](https://github.com/repentsinner/workbench_shell/compare/v0.14.0...v0.15.0) (2026-06-27)


### Features

* **example:** persist sidebar width and panel height across restarts ([04440a0](https://github.com/repentsinner/workbench_shell/commit/04440a0410a3b9027411fb9f86ae3b43d90038e6))
* **layout:** expose sidebar width and panel height as host-persistable hooks ([c3d1665](https://github.com/repentsinner/workbench_shell/commit/c3d16655d0a3127a26bac89c1e5cd4eda2cfd798))


### Reverts

* **example:** drop disk persistence; keep layout hooks in-memory ([171cb00](https://github.com/repentsinner/workbench_shell/commit/171cb00540f0a5fd1e3191c01af525091bf3b580))

# [0.14.0](https://github.com/repentsinner/workbench_shell/compare/v0.13.0...v0.14.0) (2026-06-18)


### Features

* **view-pane:** add per-pane maximumBodySize with canon clamp ([31e33ed](https://github.com/repentsinner/workbench_shell/commit/31e33ed5776d6f2fcfd8ba7a5ca724d313563f99))

# [0.13.0](https://github.com/repentsinner/workbench_shell/compare/v0.12.1...v0.13.0) (2026-06-17)


### Bug Fixes

* **view-pane:** keep header focus across the collapse reparent ([a857648](https://github.com/repentsinner/workbench_shell/commit/a857648fe5fd4a6289e4ed80ed703bfee36cbe8d))


### Features

* **view-pane:** clear the header focus ring on a tap outside ([1a43daf](https://github.com/repentsinner/workbench_shell/commit/1a43dafd5d50fa81bde34b93b8d95a6ab6294434))
* **view-pane:** focusable header with focus ring and per-pane keys ([b1c047c](https://github.com/repentsinner/workbench_shell/commit/b1c047c793525c872b311040670a88e7bded60ad))
* **view-stack:** up/down focus traversal between pane headers ([c30de5c](https://github.com/repentsinner/workbench_shell/commit/c30de5c162cae51f1fa0cd3b7ad436ec635260e3))

## [0.12.1](https://github.com/repentsinner/workbench_shell/compare/v0.12.0...v0.12.1) (2026-06-17)


### Bug Fixes

* **view-stack:** model sash sizes as proportional weights that always fill ([ecdd4a3](https://github.com/repentsinner/workbench_shell/commit/ecdd4a3a47b98e155d2b79bccced2dd8059f840b))

# [0.12.0](https://github.com/repentsinner/workbench_shell/compare/v0.11.0...v0.12.0) (2026-06-17)


### Features

* **view-container:** host-persistable sash sizing via sizes/onSizesChanged ([28c669d](https://github.com/repentsinner/workbench_shell/commit/28c669d9bd76b6c9f19a20846d2a7e0c321c8e00))
* **view-container:** retain opened containers across activity-bar switches ([1a4050f](https://github.com/repentsinner/workbench_shell/commit/1a4050f20fe822a898026beab67cb1bc7fa33077))

# [0.11.0](https://github.com/repentsinner/workbench_shell/compare/v0.10.0...v0.11.0) (2026-06-17)


### Features

* reorder view panes by dragging the header ([5187d55](https://github.com/repentsinner/workbench_shell/commit/5187d55abc8ff249d17c0456a362f69fb3311de9))

# [0.10.0](https://github.com/repentsinner/workbench_shell/compare/v0.9.0...v0.10.0) (2026-06-16)


### Bug Fixes

* **sash:** panel sash renders full width, not half ([9c56462](https://github.com/repentsinner/workbench_shell/commit/9c564622ab904b6fb480e51b263b79d92c68ce69))
* **sash:** sidebar sash is transparent at rest, matching canon ([f51ec1a](https://github.com/repentsinner/workbench_shell/commit/f51ec1a995e6e7f24975747997eb2d9b6ecbf91d))


### Features

* **sash:** canonical sash.hoverBorder token, centered band, owned size ([2e9f4e6](https://github.com/repentsinner/workbench_shell/commit/2e9f4e6c998527247a153d0a7a7943aff3c586a3))
* **sash:** migrate view-pane sash to WorkbenchSash; add hover/drag highlight ([701b8cd](https://github.com/repentsinner/workbench_shell/commit/701b8cdd841b8dc1d2a913486e5524d1967a39ec))

# [0.9.0](https://github.com/repentsinner/workbench_shell/compare/v0.8.2...v0.9.0) (2026-06-16)


### Bug Fixes

* **view-stack:** anchor sash drag to absolute pointer position ([6161292](https://github.com/repentsinner/workbench_shell/commit/6161292cec5b3fbad32ddd5455ec05d1a7f45a53))


### Features

* **layout:** share a canonical sash for sidebar and panel resize ([d0f7e40](https://github.com/repentsinner/workbench_shell/commit/d0f7e4027a3c25a2f42aaa8ce21ab0f8506c987d))
* **view-stack:** directional sash cursor at clamp limits ([434cd7b](https://github.com/repentsinner/workbench_shell/commit/434cd7b87dbfd70bdc29ba4ef1b19500b04e4d1e))
* **view-stack:** drag the sash to resize adjacent panes ([99b518c](https://github.com/repentsinner/workbench_shell/commit/99b518ca3aa4d792d98ac62a13e32ebd1c3b81cc))

## [0.8.2](https://github.com/repentsinner/workbench_shell/compare/v0.8.1...v0.8.2) (2026-06-16)


### Bug Fixes

* **view-stack:** lay the view stack out as a fixed-height splitview ([453584a](https://github.com/repentsinner/workbench_shell/commit/453584a4b616212eae4f9e4b8a76ecd50bfdc823))

## [0.8.1](https://github.com/repentsinner/workbench_shell/compare/v0.8.0...v0.8.1) (2026-06-16)


### Bug Fixes

* **view-stack:** reserve twisty space so non-collapsible titles align ([919094f](https://github.com/repentsinner/workbench_shell/commit/919094fc2ad3dc4991d8732584497531d58fcb04))

# [0.8.0](https://github.com/repentsinner/workbench_shell/compare/v0.7.0...v0.8.0) (2026-06-16)


### Bug Fixes

* **example:** tighten Explorer body padding to canon density ([1da67b6](https://github.com/repentsinner/workbench_shell/commit/1da67b6f3febd2f21b4023592974a81aec3b23e9))
* **view-stack:** omit first-pane top rule, flush body under header ([39a600e](https://github.com/repentsinner/workbench_shell/commit/39a600ea0edb1aa7039da9b991d923ecef647b7c))


### Features

* **layout:** invert sidebar to typed view descriptors and retire host collapsible flag ([10f7347](https://github.com/repentsinner/workbench_shell/commit/10f7347e1e1c3b8416761546059ab87fa3b44811))
* **view-stack:** add WorkbenchViewContainer with container-derived collapsibility ([76a838b](https://github.com/repentsinner/workbench_shell/commit/76a838b2d9e52052c4bd01e2405e5c90c3b25d07))

# [0.7.0](https://github.com/repentsinner/workbench_shell/compare/v0.6.1...v0.7.0) (2026-06-16)


### Features

* render section-header band and rule on view-pane headers ([e705bfa](https://github.com/repentsinner/workbench_shell/commit/e705bfadb3f0a58ec93b2994afc6d0a35a452b04))

## [0.6.1](https://github.com/repentsinner/workbench_shell/compare/v0.6.0...v0.6.1) (2026-06-16)


### Bug Fixes

* **example:** route view-pane header actions through NotificationService ([e5aed8a](https://github.com/repentsinner/workbench_shell/commit/e5aed8a942f1e2ec8c3ad4a6d0be883af2d444bf)), closes [#35](https://github.com/repentsinner/workbench_shell/issues/35)

# [0.6.0](https://github.com/repentsinner/workbench_shell/compare/v0.5.0...v0.6.0) (2026-06-15)


### Features

* add hover-revealed header actions to WorkbenchViewPane ([117e15d](https://github.com/repentsinner/workbench_shell/commit/117e15d98d7d5c5b481c98522483d1bbc6eb0fc7))

# [0.5.0](https://github.com/repentsinner/workbench_shell/compare/v0.4.0...v0.5.0) (2026-06-15)


### Features

* add opt-in collapse to WorkbenchViewPane ([9710d60](https://github.com/repentsinner/workbench_shell/commit/9710d60e5d6298435324e28f41e3d937080fb446))

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

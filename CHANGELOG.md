# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## 0.1.0 - 2026-06-10

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
  (SPEC §9.19). Per-host `chromeFontFamily`, `editorFontFamily`, and
  `editorFontSize` overrides; editor-derived surfaces (log lines, tabular
  values) share a single monospace style (SPEC §7.7).
- Intent-driven actions: `ToggleBottomPanelIntent` with Cmd+J / Ctrl+J
  defaults; `WorkbenchViewMenuTab` carries an arbitrary `Intent` dispatched
  through `Actions`.
- Notification center: `NotificationService`, `NotificationHost`, and
  `NotificationProgressController` for stacked toast cards (SPEC §10).
- `WorkbenchLayoutConstants` layout tokens and host-registered extension
  slots (`SlotRegistry`, `SidebarSlot`).

# Changelog

## [Unreleased]

### Added

- `applyWorkbenchChrome(base, chrome)` helper composes the chrome's
  Material theming onto a host's base `ThemeData`: installs the
  `WorkbenchTheme` extension (replacing any stale one, preserving other
  host extensions) plus Elevated/Outlined/Text button themes carrying
  `WorkbenchLayoutConstants.buttonShape` (VS Code's 4px corners). Hosts
  obtain VS Code Material theming with one call instead of hand-wiring
  each widget theme. The bundled example builds its `ThemeData` through
  the helper and renders standard Material buttons, making it a
  self-contained chrome review surface. See SPEC §9.19.
- `ToggleBottomPanelIntent` public intent exported from
  `workbench_shell`. `WorkbenchViewMenuTab` now carries an arbitrary
  `Intent`; menu items dispatch via `Actions.maybeInvoke`. The View
  menu respects each action's `Action.isEnabled` and re-renders on
  `notifyActionListeners`.
- `editorFontFamily` and `editorFontSize` parameters on
  `WorkbenchTheme.fromVscodeColorMap` plus an `editorStyle` `TextStyle`
  on `WorkbenchTheme`. Anchors editor-derived surfaces (log lines, DRO
  numerics, tabular values) on a single per-host monospace override;
  defaults mirror VS Code's `EDITOR_FONT_DEFAULTS` per platform (Menlo
  / Consolas / Droid Sans Mono; 12 on macOS, 14 elsewhere). See SPEC
  §7.7.

### Changed

- **Breaking:** `WorkbenchMenuBar` drops `onToggleBottomPanel` and
  `onSelectTab`; hosts wrap the shell in `Actions` and register an
  `Action<Intent>` per intent they care about.
- **Breaking:** `WorkbenchShortcuts` drops every callback prop and ships
  only the Cmd+J / Ctrl+J → `ToggleBottomPanelIntent` defaults plus
  `extraShortcuts` passthrough. Tab-focus bindings are now host-owned.
- **Breaking:** `WorkbenchViewMenuTab.id` replaced by
  `WorkbenchViewMenuTab.intent`.
- **Breaking:** Chrome typography canon (§7.6) — every chrome semantic
  text style retunes to VS Code's literal CSS values
  (`sidebarOrPanelHeading` 11/w400, `sectionTitle` 11/w700,
  `bodyText`/`bodyStyle` 13/w400, `labelText` 13/w500,
  `statusText`/`statusBarTextStyle` 12/w400, `buttonTextStyle` 12/w400,
  `captionText`/`helperStyle` 12/w400, `smallText` 11/w600).
  `WorkbenchSection` now uppercases its title (parallel to the §5.2
  tab-label canon) and renders in `sectionTitle`.
- **Breaking:** `WorkbenchTheme.fromVscodeColorMap` parameter
  `fontFamily` (default `'Inconsolata'`) renamed to `chromeFontFamily`
  with a `null` default. Hosts that need a brand chrome font pass
  `chromeFontFamily: 'Inter'`; null delegates to Flutter's platform UI
  sans (matching VS Code's `-apple-system` / `Segoe UI` / `system-ui`
  rules). `WorkbenchThemeController` mirrors the parameter rename and
  adds `editorFontFamily` / `editorFontSize` passthrough.
- `loglineMessage` and `valueText` now derive from `editorStyle` via
  `copyWith`, so a host's `editorFontFamily` override flows through
  every editor-derived surface in one step.

### Removed

- **Breaking:** `WorkbenchTheme.sectionTitleStyle` field — duplicate
  of `sectionTitle`. Callers update to `theme.sectionTitle`.
- **Breaking:** `WorkbenchTheme.loglineTime`, `loglineName`, and
  `loglineLevel` fields. The three-field logline renderer never
  landed; both log consumers in this workspace render the full line
  via `loglineMessage`. Future per-field styling can derive from
  `editorStyle.copyWith` at the call site.

## 0.1.0

- Initial release: VS Code-style workbench chrome (activity bar,
  sidebar, editor area, tabbed bottom panel, status bar, menu bar),
  structural primitives (section, subsection, card, toggle card,
  empty state), theming (`WorkbenchTheme`, `WorkbenchThemeController`,
  `TokenTheme`), layout constants, and sidebar extension slots.

# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Chrome material theming contract

### §road:icon-button-theming

Close the parity gap in §spec:chrome-material-theming — bring
`IconButton` under chrome control so a bare icon button no longer falls
back to the host base `ThemeData`'s `onSurfaceVariant`. Reported in #9.
Touches:

- `lib/src/theming/workbench_chrome_theme.dart` — add an
  `iconButtonTheme: IconButtonThemeData` to `applyWorkbenchChrome`,
  styled via `IconButton.styleFrom` with the resolved icon foreground
  token and the shared flat compact sizing (`buttonShape`,
  `tapTargetSize: MaterialTapTargetSize.shrinkWrap`); extend the dartdoc
  tier list to name `IconButton` and drop the dead `§9.20` cross-ref.
- `lib/src/workbench_theme.dart` — only if `/plan` chooses a dedicated
  `iconForeground` token: add the field, factory binding (mapping VS
  Code `icon.foreground`), `copyWith`, `lerp`, and equality slots.
- `test/workbench_chrome_theme_test.dart` — add a failing-first test
  asserting `result.iconButtonTheme.style?.foregroundColor?.resolve({})`
  is non-null and equals the chosen chrome token (the issue's MCVE),
  plus a regression assertion that it is not
  `base.colorScheme.onSurfaceVariant`.
- `CHANGELOG.md` — `[Unreleased]` Fixed entry (bare `IconButton` now
  themed by the chrome); Added entry if an `iconForeground` token lands.

**Verify:**

1. `flutter test test/workbench_chrome_theme_test.dart` — the new
   IconButton parity test passes; existing FilledButton/TextButton/
   SegmentedButton theme assertions still pass.
2. Launch the bundled example app: `cd example && flutter run -d macos`.
   Place a bare `IconButton` in a sidebar section under a dark theme
   (e.g. Dark Modern); confirm its glyph is visible against the chrome
   background, not dimmed to near-invisible. Switch to a light theme and
   confirm it stays legible.
3. `flutter analyze` — zero new warnings.

# workbench_shell Roadmap

Workstream queue for `packages/workbench_shell/`. Each section
closes a documented gap between the current implementation and
SPEC.md. Workstreams are sized to fit one agent session; rationale
and design decisions live in the cited spec sections, not here.

## Chrome typography canon

### §road:chrome-typography-canon

Implement §spec:chrome-typography-canon and §spec:editor-derived-surfaces
in one PR. Touches:

- `packages/workbench_shell/lib/src/workbench_theme.dart` — rename the
  `WorkbenchTheme.fromVscodeColorMap` `fontFamily` parameter to
  `chromeFontFamily` (default `null`); add `editorFontFamily` (`String?`,
  default resolves to VS Code's `EDITOR_FONT_DEFAULTS` per platform) and
  `editorFontSize` (`double?`, default `12` on macOS, `14` elsewhere) plus
  a derived `editorStyle` field on `WorkbenchTheme`; re-tune every chrome
  semantic style literal to the VS Code source values in §7.6's table
  (sidebar/panel heading `11/w400`, `sectionTitle` `11/w700`,
  `bodyText`/`bodyStyle` `13/w400`, `labelText` `13/w500`,
  `statusText`/`statusBarTextStyle` `12/w400`, `buttonTextStyle`
  `12/w400`, `captionText`/`helperStyle` `12/w400`, `smallText`
  `11/w600`); coalesce the duplicate `sectionTitleStyle` field into
  `sectionTitle` and update the four callers in `workbench_content.dart`;
  drop the `loglineTime`, `loglineName`, `loglineLevel` fields plus
  factory bindings, `copyWith` slots, `lerp` slots, and equality
  contributions (zero consumers anywhere in the workspace); rebase
  `loglineMessage` and `valueText` to derive from `editorStyle.copyWith`
  rather than carrying their own family/size.
- `packages/workbench_shell/lib/src/workbench_content.dart` — apply
  `.toUpperCase()` to `WorkbenchSection.title` inside the rendering
  (parallel to `WorkbenchTabbedPanel`'s tab-label canon), update the
  `theme.sectionTitleStyle` references to `theme.sectionTitle` after
  coalescing.
- `packages/workbench_shell/test/` — update fixtures and assertions to
  match the new defaults; add a widget test confirming `WorkbenchSection`
  uppercases the title regardless of input casing; add a theme test
  asserting the §7.6 token literals and the §7.7 per-platform editor
  defaults.
- `packages/workbench_shell/CHANGELOG.md` — `[Unreleased]` entries under
  Added (editor-derived tokens), Changed (chrome typography canon, parameter
  rename), Removed (three unused logline tokens, duplicate `sectionTitleStyle`).
- `lib/app.dart` — update the `WorkbenchTheme.fromVscodeColorMap` call in
  `_ensureController` to pass `editorFontFamily: 'Inconsolata'` (preserves
  rove's monospaced DRO and Output panel rendering) and drop the legacy
  default Inconsolata chrome reliance. Required in the same PR so the
  workspace still compiles after the parameter rename.

Does **not** include migration of misapplied `theme.sectionTitle` call
sites in `rove_ui` (`app_settings.dart` dialog titles, dropdown styles,
TextField input styles, plus similar drift in `session_initialization.dart`,
`files_and_jobs.dart`, `run_job.dart`). Those become visually obviously
wrong once `sectionTitle` switches to `11/w700/uppercase` and need to
move to `bodyText` / `labelText`; tracked as a separate rove-side
workstream in the root ROADMAP.md, not bundled here.

**Verify:**

1. Run `cd packages/workbench_shell && fvm flutter test` — all updated
   theme and content tests pass; the new `WorkbenchSection` uppercase
   test passes; the per-platform editor-default test passes for the host
   platform.
2. Launch the bundled example app:
   `cd packages/workbench_shell/example && fvm flutter run -d macos`.
   Open a VS Code window beside it (any theme, doesn't matter which —
   they share chrome typography). Confirm visually:
   - Sidebar part title ("EXPLORER", "SETTINGS") matches VS Code's
     part-title size and weight, uppercase.
   - Panel tab labels ("OUTPUT", "DEBUG CONSOLE", "TERMINAL") match
     VS Code's panel tab strip density — no longer noticeably larger
     than VS Code.
   - Status bar item text matches VS Code's status bar density.
   - Body text inside the Notifications demo sidebar matches VS Code's
     workbench body density.
3. Launch rove: `tools/build.sh ci` then
   `fvm flutter run -d macos`. Confirm:
   - DRO numerics (Files & Jobs sidebar) still render in Inconsolata at
     the existing visual weight — `editorFontFamily: 'Inconsolata'`
     preserves the family override.
   - Output panel log lines render in Inconsolata at the editor size.
   - Sidebar group headers inside `WorkbenchSection` (Files & Jobs,
     Session Initialization) render uppercase regardless of how the
     host call site cased the input.
4. Run `tools/build.sh ci` (full project CI) — formatter, analyzer, and
   workspace-wide tests all pass, including the workbench_shell boundary
   lint.

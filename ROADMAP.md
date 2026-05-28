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

## Layout constants canon

### §road:layout-constants-canon

Implement §spec:layout-constants-canon in one PR. Touches:

- `packages/workbench_shell/lib/src/layout_constants.dart` — update
  literal values to match VS Code source per §8.1's canonical table:
  `statusBarHeight` 25 → 22, `sidebarMinWidth` 200 → 170, `panelMinHeight`
  100 → 77, `notificationCardWidth` 360 → 450, `panelTabStripHeight`
  22 → 35. Remove `panelTabStripPaddingY` (collapsed into the new single
  35px container per §8.1's "panel tab strip coalesce" decision); zero
  consumers outside the package, so the removal has no external blast
  radius.
- `packages/workbench_shell/lib/src/workbench_tabbed_panel.dart` — drop
  the two leading/trailing `SizedBox(height: panelTabStripPaddingY)`
  wrappers and host the tab strip directly inside the
  `SizedBox(height: panelTabStripHeight)` (now 35px). The existing `Row`
  flex-aligns its children vertically without explicit padding,
  matching VS Code's single-container construction.
- `packages/workbench_shell/test/` — update any layout-constants test
  fixtures that asserted the previous values; add a small regression
  test that records the canonical literals so a future accidental edit
  fails loudly. No new widget tests required — the §8.1 verify path
  is visual measurement, not unit assertion.
- `packages/workbench_shell/CHANGELOG.md` — `[Unreleased]` Changed
  entries for the five literal updates and the `panelTabStripPaddingY`
  removal (one bullet per change so the release notes call out each
  visible shift).

No `lib/app.dart` host changes required: rove reads
`WorkbenchLayoutConstants.*` at composition time but doesn't depend on
any specific literal value, so the workspace continues to compile and
run with the new defaults. Independent of `§road:chrome-typography-canon`
— the two workstreams touch different fields in
`layout_constants.dart` vs `workbench_theme.dart` and can land in either
order, though landing typography first reduces the visual delta a
reviewer needs to absorb in the layout PR (most density change comes
from the typography canon; layout closes the remaining ~3-30px pixel
deltas).

**Verify:**

1. Run `cd packages/workbench_shell && fvm flutter test` — the
   layout-constants regression test passes with the canonical values;
   no existing test fails after the literal updates.
2. Launch the bundled example app:
   `cd packages/workbench_shell/example && fvm flutter run -d macos`.
   Open a VS Code window beside it (any chrome theme — geometry is
   theme-independent). Measure with a pixel ruler (macOS Preview's
   ruler, or the Display Pixel Ruler app) or simply align windows
   edge-to-edge and visually compare:
   - Status bar height matches VS Code's (22px, was 25 — VS Code's
     bar should align to the same horizontal line as the example
     when both windows have the same vertical extent).
   - Drag the sidebar to its minimum width; the collapse floor
     matches VS Code's (170px, was 200 — the sidebar should bottom
     out tighter than before).
   - Drag the bottom panel to its minimum height; the collapse floor
     matches VS Code's (77px, was 100).
   - Trigger any notification (Notifications demo sidebar provides
     buttons); the toast card width matches VS Code's notifications
     (450px, was 360 — the card should be visibly wider).
   - Panel tab strip and sidebar heading both render in the same
     35px container with vertically-centred labels — no awkward
     padding asymmetry from the removed three-constant split.
3. Launch rove: `tools/build.sh ci` then
   `fvm flutter run -d macos`. Walk through the workbench:
   - Status bar at the bottom of the rove window now sits 3px lower
     visually (because it's 3px shorter); no overlap with any
     content above.
   - Sidebar resize handle still works; minimum is now 170px (the
     Files & Jobs sidebar should look slightly more compact at the
     collapse floor).
   - Any notification (trigger via job actions) renders at 450px
     wide.
4. Run `tools/build.sh ci` (full project CI) — formatter, analyzer,
   workspace-wide tests, and the workbench_shell boundary lint all
   pass.

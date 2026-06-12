# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

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

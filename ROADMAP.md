# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Modern UI Surface Treatment §road:modern-ui-surfaces

Render the workbench parts as the bordered, rounded cards VS Code
now ships (§spec:modern-ui-surfaces). Every workstream in this section
expresses its geometry through the shipped size ladders
(§spec:design-size-ladders).

### View pane header metrics §road:pane-header-metrics

Apply the treatment's pane header height, inset separator rules,
header radius and hover tint in `lib/src/workbench_view_container.dart`
and `lib/src/workbench_content.dart`, including the suppressed rule
above the first pane in a stack (§spec:modern-ui-surfaces).

### Workbench backdrop §road:workbench-backdrop

Paint the ground behind the cards from VS Code's
`titleBar.activeBackground` rather than reusing `editorBackground`,
adding the token to `lib/src/workbench_theme.dart` and applying it in
`lib/src/workbench_layout.dart` (§spec:modern-ui-surfaces). The card
framing made this visible: the gutters it introduced expose a colour
that previously rendered nowhere, and on a dark theme it resolves close
enough to the editor card that the treatment reads as a hairline grid
rather than as floating cards.

### Layout density seam §road:layout-density

Expose layout density as a host-configurable property on
`WorkbenchLayout` following the controlled/uncontrolled pattern, wire
it through `lib/src/workbench_layout.dart` and
`lib/src/workbench_layout_state.dart` so it modulates the preceding
workstreams' geometry, and demonstrate both densities in
`example/lib/main.dart` (§spec:modern-ui-surfaces,
§spec:layout-customization). The card framing, editor frame and
activity bar rail it modulates have shipped; depends on
§road:pane-header-metrics.

**Verify:** Run the example app beside VS Code at the same density.
The side bars, panel and editor each read as a separate bordered card
with a visible gap; one hairline separates the activity bar from the
primary side bar with no gap between them and the rail's icons
optically centred; selecting an activity bar item fills a rounded
background behind its icon rather than drawing a left border; a
stacked view pane shows an inset rule above it and the first pane in
the stack shows none. Switch the example's density control to compact
and confirm the gaps and corner radii disappear and the parts meet
edge-to-edge. Drag a side bar to its minimum width and confirm it
still collapses at the documented floor.

## Menu and Select Surfaces §road:menu-select-surfaces

Bring popup menus and host selects under the chrome theming contract
(§spec:chrome-material-theming).

### Dropdown chrome theming §road:dropdown-chrome-theming

Add the three missing `dropdown.*` colors — `dropdown.foreground`,
`dropdown.border` and `dropdown.listBackground` — alongside the existing
`dropdownBackground` in `lib/src/workbench_theme.dart`, then extend
`applyWorkbenchChrome` in `lib/src/theming/workbench_chrome_theme.dart`
with `dropdownMenuTheme`, `menuTheme` and `menuButtonTheme` so a host's
stock `DropdownMenu` and `MenuAnchor` inherit chrome without per-widget
wiring (§spec:chrome-material-theming). Demonstrate a bare
`DropdownMenu` in `example/lib/main.dart`. Closes #30.

**Verify:** Drop an unstyled `DropdownMenu` into the example app's
editor area. Its trigger reads `dropdown.background` flat at the
chrome's button height with no ripple; its open list reads
`dropdown.listBackground` flat with a `dropdown.border` hairline and
compact rows. Switch themes and confirm both follow. Confirm the
package exports no select widget — `grep` the public API for
`WorkbenchSelect` and expect no match (§spec:form-controls-excluded).

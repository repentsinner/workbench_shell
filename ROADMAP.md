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

### Part title height §road:part-title-height

Tighten the side bar heading and panel tab strip from the base
`.part > .title` height to the treatment's, updating
`sidebarHeadingHeight` and `panelTabStripHeight` in
`lib/src/layout_constants.dart` and their row in
§spec:layout-constants-canon's source table
(§spec:modern-ui-surfaces). The canon table still cites the base value,
so a version-pinned re-audit reads the constants as current and the
drift stays invisible.

### Workbench backdrop §road:workbench-backdrop

Paint the ground behind the cards from VS Code's
`titleBar.activeBackground` rather than reusing `editorBackground`,
adding the token to `lib/src/workbench_theme.dart` and applying it in
`lib/src/workbench_layout.dart` (§spec:modern-ui-surfaces). The card
framing made this visible: the gutters it introduced expose a colour
that previously rendered nowhere, and on a dark theme it resolves close
enough to the editor card that the treatment reads as a hairline grid
rather than as floating cards.

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
chrome's button height with no ripple; its open list is flat with a
`dropdown.border` hairline and compact rows. Under a theme that sets
`dropdown.listBackground` the list takes that colour; under one that
omits it — the default in dark and light — the list takes the trigger
fill, never Material's surface. Switch themes and confirm both follow.
Confirm the package exports no select widget — `grep` the public API
for `WorkbenchSelect` and expect no match
(§spec:form-controls-excluded).

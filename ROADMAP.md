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

## Split Button §road:split-button

Give the shell VS Code's Commit control — a primary action, a pipe, and
a disclosure opening a menu — which Flutter ships no equivalent for
(§spec:split-button).

### Button token family §road:button-token-family

Add `button.separator`, `button.secondaryBorder` and
`button.secondaryHoverBackground` to `lib/src/workbench_theme.dart` and
drive the secondary tier's border and hover from the new pair in
`applyWorkbenchChrome` (`lib/src/theming/workbench_chrome_theme.dart`),
completing the nine registered `button.*` colours the package carries
six of (§spec:split-button, §spec:chrome-material-theming).

### Split button control §road:split-button-control

Add `WorkbenchSplitButton` under `lib/src/`, export it from
`lib/workbench_shell.dart`, open the shell's existing menu surface from
its disclosure half, and demonstrate both tiers in
`example/lib/main.dart` (§spec:split-button). Depends on
§road:button-token-family.

**Verify:** Place a primary and a secondary split button in the example
app. Each reads as one control: a single rounded outline across both
halves, no doubled stroke where they meet, and one pipe in
`button.separator` inset from the top and bottom edges rather than
running the full height. Click the primary half — the action runs and no
menu opens. Click the disclosure half — the menu opens anchored to the
control, carrying the primary action as its first entry, and rendering
at the same fill, border and row height as the View menu. Disable the
control and confirm both halves and the pipe dim together rather than
independently. Switch themes from the Settings sidebar and confirm both
tiers follow, with the secondary tier drawing its border and hover from
the `button.secondary*` family rather than a Material default.


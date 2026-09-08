# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Modern UI Surface Treatment §road:modern-ui-surfaces

Render the workbench as VS Code's Modern UI treatment ships it
(§spec:modern-ui-surfaces). Upstream enables fifteen modules from one
setting; the package has landed the card framing, the editor frame,
the activity bar and the pane header metrics. Every workstream below
closes one surveyed module or metric, expresses its geometry through
the shipped size ladders (§spec:design-size-ladders), and renders its
base behavior when the `modernUI` flag is off.

### Workbench backdrop §road:workbench-backdrop

Paint the ground behind the cards from VS Code's
`titleBar.activeBackground` rather than reusing `editorBackground`,
adding the token to `lib/src/workbench_theme.dart` and applying it in
`lib/src/workbench_layout.dart` (§spec:modern-ui-surfaces).

### Workbench casing §road:workbench-casing

Drop the `.toUpperCase()` transform from the view-pane header, the
composite title, the secondary tab labels and the panel tab strip
(`lib/src/workbench_content.dart`, `lib/src/workbench_layout.dart`,
`lib/src/workbench_tabbed_panel.dart`) and move `sectionTitle` and
`sidebarOrPanelHeading` to the treatment's 12px semiBold tier in
`lib/src/workbench_theme.dart` (§spec:chrome-typography-canon,
§spec:modern-ui-surfaces).

### Sash grips §road:sash-grips

Draw the three-dot grip on every inter-part sash in
`lib/src/workbench_sash.dart`, suppressed on the view-stack pane
sashes, at compact density, and while the sash is hovered or dragged
(§spec:modern-ui-surfaces).

### Part title padding §road:part-title-padding

Replace the composite title row's flat inset with upstream's part and
label padding in `lib/src/workbench_layout.dart`, and do the same for
the panel tab strip in `lib/src/workbench_tabbed_panel.dart`
(§spec:modern-ui-surfaces).

### Status bar treatment §road:status-bar-treatment

Inset the status bar's content and round its items at the controls
tier in `lib/src/workbench_status_bar.dart`, aligning the horizontal
inset to the activity bar's gutter (§spec:modern-ui-surfaces).

### Keyboard-only focus rings §road:keyboard-focus-rings

Paint the view-pane header's focus ring only for keyboard-originated
focus in `lib/src/workbench_content.dart`, reading the highlight mode
`FocusManager` tracks rather than gesture history
(§spec:modern-ui-surfaces, §spec:view-pane-focus).

### Notification surface treatment §road:notification-treatment

Round the notification card at the card tier and adopt the
treatment's row insets in `lib/src/notifications/notification_host.dart`
(§spec:modern-ui-surfaces, §spec:notification-center).

### Activity bar zone margins §road:activity-bar-zone-margins

Give the activity bar's item column its leading margin and its
trailing zone the matching bottom margin in
`lib/src/workbench_layout.dart` (§spec:modern-ui-surfaces).

**Verify:** Run the example app beside VS Code at the same density and
on the same theme. The side bars, panel and editor each read as a
separate bordered card with a visible gap, against a ground the same
colour as the status bar. Pane headers, the side bar title and the
panel tabs read in title case at the same size VS Code renders. Each
boundary between two parts shows three dots at its midpoint that
vanish while dragging, and a pane sash inside the Explorer shows none.
Status bar items round when they paint a background. Click a pane
header — no focus ring; Tab to it — a ring. Post a notification from
the Explorer header action and confirm its corner radius matches a
card's. Switch density to compact and confirm the gaps, the corner
radii and the sash grips all disappear. Untick View ▸ Appearance ▸
Modern UI and confirm every surface returns to the base treatment.

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


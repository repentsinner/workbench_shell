# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Secondary side bar container tabs §road:secondary-sidebar-tabs

### Replace the single-container API with membership and tabs §road:secondary-tab-strip

Replace `secondaryViewContainerId`/`initialSecondaryViewContainerId`/
`onSecondaryViewContainerChanged` with an ordered
`secondaryViewContainerIds` membership list plus the
controlled/uncontrolled `secondaryActiveViewContainerId` seam, render
one text-label tab per member in the secondary title row in place of
the composite title label (rejecting ids shared with the activity
bar), and rewire the example's secondary bar to two member containers —
`lib/src/workbench_layout.dart`, `example/lib/main.dart`
(§spec:secondary-sidebar).

**Verify:** Run the example app and toggle the secondary side bar
(Cmd/Ctrl+Alt+B). Its title row shows one tab per member container
instead of the "SECONDARY SIDE BAR" label. Click the inactive tab:
the bar switches containers. Reorder a pane, switch tabs and back:
pane order and sash sizes survive. The active container's `⋯`
overflow still lists its Views toggles.

## Structural primitives canon §road:structural-primitives-canon

### Remove the card primitives §road:remove-card-primitives

Delete `WorkbenchCard` and `WorkbenchToggleCard` with their tests and
purge remaining references from `lib/src/workbench_content.dart`,
`lib/src/workbench_theme.dart` doc comments, and the example's
primitive-listing label (§spec:structural-primitives).

### Reshape the empty state into view welcome content §road:view-welcome

Replace `WorkbenchEmptyState` with `WorkbenchViewWelcome` — stacked
paragraphs and capped full-width buttons per canon — in
`lib/src/workbench_content.dart`, updating its tests and demonstrating
it as an example view body (§spec:structural-primitives).

### Fix the problems-item info count §road:problems-info-count

Render `WorkbenchStatusBarProblemsItem`'s info count only when greater
than zero (error and warning stay unconditional, including zero),
correct the widget doc, and add the item to the example's status bar —
`lib/src/workbench_status_bar.dart`, `example/lib/main.dart`
(§spec:status-bar).

**Verify:** Run the example app. Sidebar view bodies render without
card chrome, and `grep -r "WorkbenchCard\|WorkbenchToggleCard\|WorkbenchEmptyState" lib example test`
returns nothing. The welcome-content view shows paragraphs and a
capped full-width button, no icon hero. The status bar problems item
reads error 0, warning 0 with no info glyph while info is zero, and
grows an info segment when the host reports info diagnostics.

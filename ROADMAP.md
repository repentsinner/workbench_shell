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

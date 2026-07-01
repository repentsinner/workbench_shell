# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Layout State Persistence §road:layout-state-persistence

Closes §spec:layout-state-persistence: the shell exposes its
view-container arrangement (sizes, order, expansion, visibility) as a
single serializable `WorkbenchLayoutState` a host persists and
rehydrates, with reconciliation against live descriptors owned by the
shell.

### Serializable layout-state model §road:layout-state-model

Add a `WorkbenchLayoutState` value type bundling the four
container-keyed maps (sizes, order, expansion, visibility) with a
tolerant `toJson`/`fromJson` and a `reconcile`/`applyReorder` step that
resolves persisted state against live view descriptors, in a new
`lib/src/workbench_layout_state.dart` exported from
`lib/workbench_shell.dart` (§spec:layout-state-persistence).

### Layout state seam §road:layout-state-seam

Expose a `WorkbenchLayoutState` snapshot of the shell's live container
arrangement and accept a reconciled state to seed it, notifying the
host on change, in `lib/src/workbench_layout.dart` and
`lib/src/workbench_view_container.dart`. Depends on
§road:layout-state-model (§spec:layout-state-persistence).

### Example persist-and-restore §road:layout-state-example

Dogfood cross-restart persistence: the example serializes the layout
state into a host store and rehydrates plus reconciles it on next
build, in `example/lib/main.dart`. Depends on §road:layout-state-seam
(§spec:layout-state-persistence).

**Verify:** Run the example app (`cd example && flutter run`). In the
Explorer, reorder panes, collapse one, hide a view through the `⋯`
Views menu, and sash-resize a pane. Fully restart the app (not hot
reload). Confirm the pane order, collapsed state, hidden view, and
sizes return as left. Then remove a view from the host's descriptor
list and restart: confirm the layout renders without error — the stale
view's saved state is dropped and the remaining panes are placed
correctly.

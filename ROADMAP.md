# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## View Pane Header Keyboard §road:view-pane-keyboard

Bring the view-pane header to full VS Code keyboard parity: Left collapses
and Right expands, alongside the existing Enter/Space toggle
(§spec:section-disclosure).

### Add Left/Right collapse/expand to the pane header §road:header-arrow-keys

Add Left (collapse) and Right (expand) key handling to the collapsible
`WorkbenchViewPane` header in `lib/src/workbench_content.dart`, alongside
the existing Enter/Space toggle. §spec:section-disclosure.

**Verify:** Run the example; focus a collapsible pane header, press Left
to collapse and Right to expand, with Enter/Space still toggling. A widget
test sends Left/Right key events and asserts the expansion state changes.
`flutter analyze` and `flutter test` pass.

## View Container State Persistence §road:view-container-state

Pane state (order, expansion, sash sizes) survives activity-bar container
switches, and every persistable concern has a host hook for cross-restart
persistence (§spec:view-container-state, §spec:view-stack).

### Host-persistable sash sizing §road:sash-size-hook

Add a controlled `sizes` map and `onSizesChanged` notification to
`WorkbenchViewContainer` and `WorkbenchViewContainerSpec`
(`lib/src/workbench_view_container.dart`), mirroring `order`/`onReorder`, so a
host can drive and persist sash body sizing. §spec:view-stack.

### Retain view-container state across activity-bar switches §road:retain-view-containers

Make `WorkbenchLayout` (`lib/src/workbench_layout.dart`) lazily mount and keep
each opened view container alive, keyed by container id, so pane order,
expansion, and sash sizes survive switching containers and returning.
§spec:view-container-state.

**Verify:** Run the example. In a multi-pane container (Explorer), reorder a
pane, collapse a pane, and drag a sash to resize; switch to another
activity-bar container and back — the order, collapsed state, and sizes are all
retained. A widget test confirms a container whose activity-bar entry was never
selected has not run its body builders (a body-builder side effect fires only
after first selection). For sizing persistence, a widget test supplies a
container `sizes` + `onSizesChanged`, drags a sash, asserts `onSizesChanged`
fires, and re-supplying `sizes` restores the apportionment. `flutter analyze`
and `flutter test` pass.

---

Needs `/plan` before queuing (audited VS Code gap, not yet specced): the
**composite view-container title "…" overflow menu** with a Views
show/hide submenu — the bar above the panes carrying container-level
actions to toggle which views are visible. Run `/plan` to add a spec
section, then `/roadmap`.

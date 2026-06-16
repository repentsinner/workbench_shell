# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## View Pane Drag Reorder §road:view-stack-reorder

Let the user drag a pane header to reorder panes within a container
(§spec:view-stack).

### Reorder panes by dragging the header §road:drag-reorder

Add header drag-and-drop to `WorkbenchViewContainer`
(`lib/src/workbench_view_container.dart`) that reorders the panes within
a container, with a drop indicator showing the target position.
§spec:view-stack.

**Verify:** Run the example; drag a pane header (e.g. Outline above Open
Editors) in the Explorer container — the panes reorder, a drop indicator
shows the target slot during the drag, and the new order persists.
`flutter analyze` and `flutter test` pass.

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

---

Needs `/plan` before queuing (audited VS Code gap, not yet specced): the
**composite view-container title "…" overflow menu** with a Views
show/hide submenu — the bar above the panes carrying container-level
actions to toggle which views are visible. Run `/plan` to add a spec
section, then `/roadmap`.

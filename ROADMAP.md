# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## View Pane Proportional Sizing §road:view-pane-proportional-sizing

The view stack apportions height by proportional weights that always fill
the available height, so collapsing a pane or dragging a sash never leaves
dead space and survivors keep their relative sizes across collapse/expand
(§spec:view-stack).

### Model sash sizes as proportional weights that always fill §road:proportional-weight-sizing

Replace the two-class `manualBody`/auto apportionment in
`lib/src/workbench_view_container.dart` with a proportional-weight model —
sizes are weights the container rescales to fill the available body pool
(clamped to each pane's minimum body height) and preserves across
collapse/expand, retiring the sized-vs-unsized split that orphaned freed
space. §spec:view-stack.

**Verify:** Run the example. In Explorer, drag a sash so OUTLINE's body is
clearly taller than OPEN EDITORS, then collapse TIMELINE — the freed space is
absorbed by OUTLINE and OPEN EDITORS in proportion (their ~2:1 ratio holds)
with no dead space at the bottom of the stack; expand TIMELINE and it returns
to its prior size while the others shrink proportionally. A widget test sizes
two expanded panes unevenly, collapses a third, and asserts the laid-out stack
height equals the available height (no gap) and the survivors' body-height
ratio is preserved; a re-expand restores the collapsed pane's prior body
height. `flutter analyze` and `flutter test` pass.

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

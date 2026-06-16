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

---

Needs `/plan` before queuing (audited VS Code gap, not yet specced): the
**composite view-container title "…" overflow menu** with a Views
show/hide submenu — the bar above the panes carrying container-level
actions to toggle which views are visible. Run `/plan` to add a spec
section, then `/roadmap`.

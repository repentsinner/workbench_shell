# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

Needs `/plan` before queuing (audited VS Code gap, not yet specced): the
**composite view-container title "…" overflow menu** with a Views
show/hide submenu — the bar above the panes carrying container-level
actions to toggle which views are visible. Run `/plan` to add a spec
section, then `/roadmap`.

## Panel Alignment §road:panel-alignment

Closes §spec:panel-alignment. The bottom panel's horizontal extent via
re-parenting (per side bar: inside or outside the panel's band), not a
layout solver. Center/justify first; left/right last as the boundary case
the §spec:layout-customization "no layout engine" decision is tested
against.

### Panel Center/Justify §road:panel-align-center-justify

Add a `WorkbenchPanelAlignment` enum and a controlled/uncontrolled
`panelAlignment` property supporting `center` (editor-width, the current
default) and `justify` (full-width) by re-parenting the panel between the
editor column and the outer column — in `lib/src/workbench_layout.dart`,
exported from `lib/workbench_shell.dart`, with a View-menu item in
`example/lib/main.dart`. §spec:panel-alignment

### Panel Left/Right §road:panel-align-left-right

Extend `panelAlignment` with `left` and `right`, where the panel abuts
one edge's side bar while the other side bar runs full height, via the
per-side-bar nesting choice — in `lib/src/workbench_layout.dart`.
§spec:panel-alignment. Depends on §road:panel-align-center-justify; the
nesting must place both the primary and the shipped secondary side bar
(§spec:secondary-sidebar). Stop and defer if the nesting collapses into
per-combination special-casing rather than two booleans.

**Verify:** In the example app's View menu, set Panel Alignment to
Justify — confirm the bottom panel spans the full window width past both
side bars; set Center — confirm it spans only the editor while side bars
run full height. Set Left — confirm the panel abuts the left side bar
(which stops at the panel's top) while the right side bar runs full
height; set Right — confirm the mirror.

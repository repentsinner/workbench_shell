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

## Editing Modes §road:editing-modes

Closes §spec:editing-modes. Two independent host-driven toggles, each a
controlled/uncontrolled property on `WorkbenchLayout` mirroring the
existing active-container pattern. Built first: independent of the other
sections and the smallest slices.

### Zen Mode §road:zen-mode

Add a `zenMode` toggle (controlled/uncontrolled) to `WorkbenchLayout`
that hides activity bar, both side bars, panel, and status bar, leaving
the editor — in `lib/src/workbench_layout.dart`, exported from
`lib/workbench_shell.dart`, with a View-menu item wired in
`example/lib/main.dart`. §spec:editing-modes

### Centered Layout §road:centered-layout

Add a `centeredLayout` toggle (controlled/uncontrolled) to
`WorkbenchLayout` that constrains the editor to a maximum width and
centers it, leaving chrome in place — in `lib/src/workbench_layout.dart`,
max-width constant in `lib/src/layout_constants.dart`, exported from
`lib/workbench_shell.dart`, with a View-menu item in
`example/lib/main.dart`. §spec:editing-modes

**Verify:** In the example app's View menu, toggle Zen Mode on — confirm
only the editor remains; toggle off — confirm all chrome returns. Toggle
Centered Layout on — confirm the editor narrows and centers with side
margins while activity bar, side bar, and status bar stay; toggle off —
confirm the editor fills the width again.

## Primary Side Bar Position §road:sidebar-position

Closes §spec:sidebar-position. Names the side bar's edge so the secondary
bar can derive its opposite. Depends on the §spec:workbench-layout sash
holding unchanged on either edge.

### Side Bar Left/Right §road:sidebar-position-prop

Add a `WorkbenchSidebarPosition { left, right }` enum and a
controlled/uncontrolled `sidebarPosition` property to `WorkbenchLayout`,
moving the primary side bar (with its activity bar), its sash, and its
border to the selected edge — in `lib/src/workbench_layout.dart`,
exported from `lib/workbench_shell.dart`, with a View-menu item in
`example/lib/main.dart`. §spec:sidebar-position

**Verify:** In the example app's View menu, set Side Bar Position to
Right — confirm the activity bar and side bar move to the editor's right
edge and the resize sash drags correctly from that edge. Set back to Left
— confirm they return and the sash still tracks.

## Secondary Side Bar §road:secondary-sidebar

Closes §spec:secondary-sidebar. A second side bar on the editor's
opposite edge, reusing the container machinery and the canonical sash.
Depends on §road:sidebar-position-prop for the edge-derivation logic.

### Secondary Side Bar Slot §road:secondary-sidebar-prop

Add an independently visible and resizable secondary side bar on the edge
opposite the primary, hosting view containers through the same
`containerBuilder` path with its own controlled/uncontrolled active
container, visibility, and width — in `lib/src/workbench_layout.dart`,
exported from `lib/workbench_shell.dart`, with example wiring in
`example/lib/main.dart`. §spec:secondary-sidebar. Depends on
§road:sidebar-position-prop.

**Verify:** In the example app, enable the secondary side bar with a
sample container — confirm it appears on the edge opposite the primary,
toggles visibility independently, and resizes with its own sash. Swap the
primary to the other edge — confirm the secondary follows to the now-free
opposite edge.

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
§spec:panel-alignment. Depends on §road:panel-align-center-justify and
§road:secondary-sidebar-prop (the nesting must place both bars). Stop and
defer if the nesting collapses into per-combination special-casing rather
than two booleans.

**Verify:** In the example app's View menu, set Panel Alignment to
Justify — confirm the bottom panel spans the full window width past both
side bars; set Center — confirm it spans only the editor while side bars
run full height. Set Left — confirm the panel abuts the left side bar
(which stops at the panel's top) while the right side bar runs full
height; set Right — confirm the mirror.

## Drag-Resize Geometry §road:resize-geometry

Closes §spec:resize-geometry. Replace the controlled/per-frame resize-geometry
API with seed-plus-commit across sidebar width, panel height, and view-stack
sizes, matching VS Code's layout-owns-geometry model. Breaking change to
0.15.0.

### Seed-plus-commit geometry §road:resize-geometry-prop

Replace `WorkbenchLayout.sidebarWidth`/`onSidebarWidthChanged` and
`panelHeight`/`onPanelHeightChanged`, and the view container's
`sizes`/`onSizesChanged`, with `initialSidebarWidth`/`onSidebarWidthChangeEnd`,
`initialPanelHeight`/`onPanelHeightChangeEnd`, and
`initialSizes`/`onSizesChangeEnd`. The shell owns each value as internal state
seeded by `initial…`; each `…ChangeEnd` fires once off the canonical sash's
drag-end (`WorkbenchSash.onDragChanged(false)`/`_onEnd`,
§spec:workbench-layout) with the final clamped value. Remove the
controlled-geometry properties. In `lib/src/workbench_layout.dart`,
`lib/src/workbench_view_container.dart`, and `lib/src/workbench_sash.dart`
(surface the final value at drag-end), exported from
`lib/workbench_shell.dart`. Reconcile the superseded controlled-`sizes`
language in §spec:view-stack and §spec:view-container-state, and update
`example/lib/main.dart` to seed from and persist on the new callbacks.
§spec:resize-geometry. Reported in #68.

**Verify:** In the example app, log the sidebar callbacks during a drag —
confirm nothing fires per frame and `onSidebarWidthChangeEnd` fires exactly
once on release with the final width. Restart with a seeded
`initialSidebarWidth` — confirm the sidebar opens at the seeded width. Repeat
for panel height and a view-pane sash (`onSizesChangeEnd` + `initialSizes`).

## Sash Double-Click Reset §road:sash-reset

Closes the double-click-reset gap in §spec:workbench-layout. The gesture is a
universal VS Code `Sash` behavior; the shell already exposes
`WorkbenchSash.onReset` and honors it on the centered-layout margins, but the
sidebar, panel, and view-pane sashes ignore it. Depends on
`WorkbenchSash.onReset` landing (§road:editing-modes) and should follow
§road:resize-geometry, which reworks how those sash values are owned (resetting
to a default is a single-commit reset in the same seed-plus-commit shape).

### Reset The Outer And Pane Sashes §road:sash-reset-wiring

Wire `onReset` on the sidebar, panel, and view-pane sashes per the
§spec:workbench-layout per-seam semantics: the sidebar and panel sashes reset to
`WorkbenchLayoutConstants.sidebarDefaultWidth` / `panelDefaultHeight`; a
view-pane sash resets the two adjacent expanded panes to an even split of their
combined body height — in `lib/src/workbench_layout.dart` and
`lib/src/workbench_view_container.dart`. §spec:workbench-layout

**Verify:** In the example app, drag the sidebar wider, then double-click its
sash — confirm it snaps back to the default width. Repeat for the panel height.
Drag a view-pane boundary lopsided, double-click it — confirm the two panes
even out.

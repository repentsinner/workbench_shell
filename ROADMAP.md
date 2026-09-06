# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Design Size Ladders §road:design-size-ladders

Replace the package-local geometry vocabulary with VS Code's
registered ladders (§spec:design-size-ladders).

### Corner radius and stroke ladders §road:radius-stroke-ladders

Replace `containerRadius`, `buttonRadius` and `notificationCardRadius`
in `lib/src/layout_constants.dart` with the upstream corner-radius
ladder plus a stroke-thickness constant, assign each existing radius
call site the tier matching its surface role, and migrate consumers in
`lib/src/` and `example/lib/` (§spec:design-size-ladders).

### Spacing ramp §road:spacing-ramp

Replace the `spacingXxs`…`spacingXl` scale in
`lib/src/layout_constants.dart` with the upstream spacing ramp and
migrate every call site in `lib/src/` and `example/lib/`
(§spec:design-size-ladders). Depends on §road:radius-stroke-ladders.

**Verify:** Build the example app. Chrome renders unchanged — this is
a renaming, not a restyling — and no `WorkbenchLayoutConstants` member
carries a t-shirt name. Grep the public API for `containerRadius` and
`spacing[XSML]` and confirm no matches. Compare the surviving names
against VS Code's `baseSizes.ts` registrations and confirm each name
carries the same value upstream does.

## Modern UI Surface Treatment §road:modern-ui-surfaces

Render the workbench parts as the bordered, rounded cards VS Code
now ships (§spec:modern-ui-surfaces). Every workstream in this section
depends on §road:design-size-ladders.

### Part card framing §road:part-card-framing

Render the primary side bar, secondary side bar and bottom panel as
bordered, rounded, gapped cards in `lib/src/workbench_layout.dart`,
adding the surface border and background tokens they need to
`lib/src/workbench_theme.dart` (§spec:modern-ui-surfaces).

### Editor frame §road:editor-frame

Frame the editor area with a hairline border and radius drawn inside
its existing layout allocation in `lib/src/workbench_layout.dart`,
leaving drag-resize arithmetic and the min/max floors measuring
unchanged quantities (§spec:modern-ui-surfaces). Depends on
§road:part-card-framing.

### Activity bar rail and indicator §road:activity-bar-modern

Give the activity bar its treatment-specific rail width and replace
the active item's left-border indicator with a filled rounded
background across `lib/src/workbench_layout.dart`,
`lib/src/activity_bar_item.dart` and `lib/src/workbench_theme.dart`,
including the shared seam where the rail meets the primary side bar
(§spec:modern-ui-surfaces). Depends on §road:part-card-framing.

### View pane header metrics §road:pane-header-metrics

Apply the treatment's pane header height, inset separator rules,
header radius and hover tint in `lib/src/workbench_view_container.dart`
and `lib/src/workbench_content.dart`, including the suppressed rule
above the first pane in a stack (§spec:modern-ui-surfaces).

### Layout density seam §road:layout-density

Expose layout density as a host-configurable property on
`WorkbenchLayout` following the controlled/uncontrolled pattern, wire
it through `lib/src/workbench_layout.dart` and
`lib/src/workbench_layout_state.dart` so it modulates the preceding
workstreams' geometry, and demonstrate both densities in
`example/lib/main.dart` (§spec:modern-ui-surfaces,
§spec:layout-customization). Depends on §road:part-card-framing,
§road:editor-frame, §road:activity-bar-modern and
§road:pane-header-metrics.

**Verify:** Run the example app beside VS Code at the same density.
The side bars, panel and editor each read as a separate bordered card
with a visible gap; one hairline separates the activity bar from the
primary side bar with no gap between them and the rail's icons
optically centred; selecting an activity bar item fills a rounded
background behind its icon rather than drawing a left border; a
stacked view pane shows an inset rule above it and the first pane in
the stack shows none. Switch the example's density control to compact
and confirm the gaps and corner radii disappear and the parts meet
edge-to-edge. Drag a side bar to its minimum width and confirm it
still collapses at the documented floor.

# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## View Pane Header Focus and Keyboard Navigation §road:view-pane-focus

A view-pane header is focusable, paints a focus ring, and drives the pane's
disclosure and the stack's header traversal from the keyboard — VS Code's
`PaneView`/`Pane` model (§spec:view-pane-focus).

### Focusable header with focus ring and per-pane keys §road:header-focus-keys

Make the `WorkbenchViewPane` header in `lib/src/workbench_content.dart` a
single focus stop that paints the `focusBorder` ring while focused, focuses
on a pointer click (and on a collapsible header also toggles), and handles
Enter/Space toggle plus Left collapse / Right expand on a focused collapsible
header. §spec:view-pane-focus.

### Up/Down focus traversal between headers §road:header-focus-traversal

Add container-level Down/Up focus traversal that moves focus to the
next/previous pane header (clamped at the ends, ≥2 panes) in
`lib/src/workbench_view_container.dart`, and exercise the full capability
through the example Explorer container (`example/lib/main.dart`).
§spec:view-pane-focus. Depends on §road:header-focus-keys.

**Verify:** Run the example. Click an Explorer pane header — it shows a focus
ring; clicking a collapsible header also toggles it. With a collapsible
header focused, Enter/Space toggle, Left collapses, and Right expands the
pane; Down/Up move the focus ring to the next/previous header and stop at the
first/last (no wrap). Widget tests: a pointer click focuses the header and
paints the ring; on a focused collapsible header Left/Right/Enter/Space
change its expansion while the same keys are no-ops on a non-collapsible
header; Down/Up move focus across headers and clamp at the ends with two or
more panes. `flutter analyze` and `flutter test` pass.

---

Needs `/plan` before queuing (audited VS Code gap, not yet specced): the
**composite view-container title "…" overflow menu** with a Views
show/hide submenu — the bar above the panes carrying container-level
actions to toggle which views are visible. Run `/plan` to add a spec
section, then `/roadmap`.

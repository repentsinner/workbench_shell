# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## View Container Title Overflow §road:view-container-title

Closes §spec:view-container-title: the sidebar title gains a `⋯`
overflow menu whose Views submenu toggles per-view visibility.

### View visibility and Views overflow menu §road:view-visibility-overflow

Add `visible`/`canHide` to `WorkbenchViewDescriptor` with
`onVisibleChanged` (controlled/uncontrolled), drop hidden panes from the
stack while retaining their `order` slot, derive collapsibility from the
visible-view count, and render the right-aligned `⋯` button in the
`_Sidebar` title row opening an in-window Material popup with a
shell-built Views checkbox submenu — in `lib/src/workbench_view_container.dart`,
`lib/src/workbench_layout.dart`, reusing the menu path in
`lib/src/workbench_view_menu.dart` (§spec:view-container-title).

### Host container-title actions and overflow entries §road:container-title-actions

Add optional host-supplied inline title actions (`List<Widget>`,
mirroring §spec:section-header-actions) and extra overflow entries
(`List<WorkbenchMenuEntry>`, mirroring §spec:menu-model) to
`WorkbenchViewContainerSpec`, placed beside the `⋯` button and within
the popup around the shell's Views group — in
`lib/src/workbench_view_container.dart`, `lib/src/workbench_layout.dart`.
Depends on §road:view-visibility-overflow (§spec:view-container-title).

**Verify:** Run the example app (`cd example && flutter run`). Open a
sidebar container with multiple views (the Explorer-like container),
click the `⋯` button in the sidebar title, and uncheck a view in the
Views submenu — confirm its pane leaves the stack and the remaining
panes absorb the freed height. Re-check it and confirm the pane returns
to its original position. Hide views until one remains and confirm the
lone pane becomes non-collapsible (or merged). Switch to another
activity-bar container and back; confirm the hidden/shown state
survives.

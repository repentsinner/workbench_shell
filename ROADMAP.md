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

## View Menu Item Model §road:menu-model

Closes §spec:menu-model. Gives the View menu a nesting and
selection-state vocabulary (submenus, checkable/radio groups) so hosts
build canon-faithful menus instead of mutating entry labels. Real
checkmarks on the in-window Material path; "✓ " label degradation on the
native macOS menu, since Flutter's `PlatformMenuItem` carries no checked
state.

### Menu Model Vocabulary §road:menu-model-prop

Extend `WorkbenchMenuBar`'s descriptor model from a flat
`WorkbenchViewMenuTab` list to a tree — command, submenu, separator, and
checkable/radio entries — rendering submenus and checked state on both
the macOS `PlatformMenuBar` path (native `PlatformMenu` nesting; "✓ "
label degradation for the checkmark) and the in-window Material path
(`SubmenuButton` / `RadioMenuButton` / `CheckboxMenuButton`) — in
`lib/src/workbench_view_menu.dart`, exported from
`lib/workbench_shell.dart`. §spec:menu-model

### Example Menu Canon §road:example-menu-canon

Rewire the example app's View menu to the VS Code structure using the
extended model: an Appearance submenu, an Align Panel radio submenu
(Center/Justify/Left/Right with the active value checked), and checkable
toggles for the visibility items (primary and secondary side bar, status
bar, panel) replacing today's label-mutating entries — in
`example/lib/main.dart`. §spec:menu-model. Depends on
§road:menu-model-prop.

**Verify:** In the example app, open View ▸ Align Panel — confirm a
submenu lists Center/Justify/Left/Right with a checkmark (in-window) or
leading "✓ " (macOS) on the active value, and selecting one moves the
mark without mutating any label. Confirm the visibility toggles show a
check when their chrome is shown and clear it when hidden.

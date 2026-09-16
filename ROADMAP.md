# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Editor tabs §road:editor-tabs

Closes the gap between the single `editor` slot and §spec:editor-tabs.
Reported in #140; the workstream that completes the section closes it.
Each workstream extends the example app so its slice is exercisable
there.

### Editor tab strip skeleton §road:editor-tab-skeleton

Add the `WorkbenchEditorTab` descriptor and `WorkbenchLayout.editorTabs`
with the base-treatment strip (icon, label, `tab.*` and
`editorGroupHeader.*` theme tokens), click activation through the
controlled/uncontrolled active-tab seam, lazily built retained tab
content, tab semantics, and the empty-list fallback to `editor`, in
`lib/src/workbench_layout.dart`, a new editor-tabs source file,
`lib/src/workbench_theme.dart`, `lib/src/layout_constants.dart`, and
`example/lib/main.dart` (§spec:editor-tabs, §spec:editor-tab-rendering,
§spec:editor-tab-interaction).

### Connected editor tabs under Modern UI §road:editor-tab-connected

Render the strip in upstream's `connected` style when `modernUI` is on,
following the treatment's density, in the editor-tabs source file,
`lib/src/workbench_theme.dart`, and `lib/src/layout_constants.dart`
(§spec:editor-tab-rendering, §spec:modern-ui-surfaces). Depends on
§road:editor-tab-skeleton.

### Open, close, and unsaved state §road:editor-tab-lifecycle

Make tab order shell-owned (open to the right of the active tab,
`onEditorTabOrderChanged`), activate the most recently active tab when
the active one leaves, and add `onEditorTabCloseRequested` with the
close button's visibility rules, the dirty dot, and no close affordance
without a handler, in the editor-tabs source file and
`example/lib/main.dart` (§spec:editor-tab-state,
§spec:editor-tab-rendering). Depends on §road:editor-tab-skeleton.

### Drag to reorder §road:editor-tab-reorder

Add drag reordering with the `tab.dragAndDropBorder` drop indicator,
reporting the new order through `onEditorTabOrderChanged`, in the
editor-tabs source file (§spec:editor-tab-interaction). Depends on
§road:editor-tab-lifecycle.

### Editor tab keyboard bindings §road:editor-tab-keyboard

Publish the editor-tab intents and bind VS Code's per-platform defaults
while the layout has tabs (close only while tabs are closable), in
`lib/src/workbench_intents.dart`, `lib/src/workbench_layout.dart`, and
`example/lib/main.dart` (§spec:editor-tab-interaction,
§spec:action-dispatch, §spec:shortcuts). Depends on
§road:editor-tab-lifecycle.

**Verify:** Run the example app, which starts with Modern UI on, and
open its editor tabs.

1. **Strip and switching.** Confirm a strip in the `connected` style
   sits over the editor. Scroll a tab's content, switch to another
   tab and back, and confirm the scroll position held. Turn Modern UI
   off from the menu and confirm the classic strip: a 35px row, with a
   top border on the active tab when the theme sets
   `tab.activeBorderTop`.
2. **Theme.** Switch to Light Modern and confirm the tab colors follow
   the theme.
3. **Open.** Open a new tab from the example's host control. Confirm
   it appears right of the active tab and becomes active.
4. **Unsaved state.** Mark a tab dirty. Confirm a dot replaces its
   close button, and that hovering the tab shows the button again.
5. **Close.** Close the active tab with its button. Confirm the most
   recently active remaining tab activates. Close the last tab and
   confirm the example's empty-editor surface shows with no strip.
6. **Reorder.** Drag a tab across another. Confirm the 2px drop bar
   tracks which half of the target tab the pointer is over, and the
   tab lands there.
7. **Keyboard.** On macOS, press Cmd+Alt+Right/Left, Ctrl+1 and Cmd+W.
   On Windows or Linux, press Ctrl+PageDown/PageUp, Alt+1 and Ctrl+W.
   Confirm each moves between tabs or closes the active one.
8. **No close handler.** Remove the close handler in the example.
   Confirm no tab shows a close button and Cmd/Ctrl+W does nothing.

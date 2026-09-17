# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Editor tabs on stable canon §road:editor-tabs-stable

Closes the gap between the shipped strip and §spec:editor-tabs as
corrected to VS Code 1.138.0: Modern UI renders pills, not the
`connected` style, and the strip scrolls when its tabs overflow. Each
workstream extends the example app so its slice is exercisable there.

### Pill editor tabs under Modern UI §road:editor-tab-pills

Replace the connected style with the 1.138.0 pill treatment (transparent
32px row, content-sized tabs with an inset 24px rounded fill, the
`modernEditorTab.*` to `modernTab.*` to list color chain, the close
button on every tab, dirty-tab hover reveal) and remove the connected
painter, its constants and tests, in `lib/src/workbench_editor_tabs.dart`,
`lib/src/workbench_theme.dart`, `lib/src/layout_constants.dart`, and
their tests (§spec:editor-tab-rendering, §spec:modern-ui-surfaces).

### Editor tab overflow scrolling §road:editor-tab-overflow

Make the strip scroll horizontally with the wheel, overlay the 3px
auto-visibility scrollbar in the `scrollbarSlider.*` colors, reveal the
active tab with the least scroll (not after a close through the
button), and scroll the strip while a dragged tab nears either end, in
`lib/src/workbench_editor_tabs.dart`, `lib/src/workbench_theme.dart`,
`lib/src/layout_constants.dart`, and `example/lib/main.dart` (enough
editors to overflow) (§spec:editor-tab-overflow). Depends on
§road:editor-tab-pills.

**Verify:** Run the example app, which starts with Modern UI on.

1. **Pills.** Confirm the editor tabs render as rounded pills on a
   transparent strip with gaps between them, the active pill filled,
   inactive labels dimmed, and a close button on every tab. Compare
   side by side with VS Code 1.138.0 with Modern UI on.
2. **Theme.** Switch between Dark Modern, Light Modern and 2026 Dark;
   confirm pill fills follow each theme's list colors. Turn Modern UI
   off and confirm the classic 35px strip still follows `tab.*`.
3. **Unsaved.** Mark a tab unsaved; confirm the dot replaces its close
   button and hovering anywhere on the tab brings the button back.
4. **Overflow.** Open editors until the tabs outgrow the strip.
   Confirm a vertical wheel scrolls the strip sideways, a thin
   scrollbar appears only while the pointer is over the strip or it is
   scrolling, and it fades after scrolling stops.
5. **Reveal.** With the strip scrolled, activate a tab cut off at
   either end with Cmd+Alt+Right/Left (Ctrl+PageDown/PageUp elsewhere)
   and confirm it scrolls fully into view with the least movement.
   Close a tab with its button and confirm the strip does not jump.
6. **Drag.** Drag a tab toward either end of an overflowing strip;
   confirm the strip scrolls and the tab drops at a position that
   started out of view.

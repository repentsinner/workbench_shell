# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Hover canon §road:hover-canon

Closes the gap between the shell's hover rendering and
§spec:hover-canon. Three shell-drawn surfaces and two chrome-themed
widgets still paint Material's state layer where VS Code registers a
hover token.

### Shell-drawn hover §road:shell-hover-canon

Add a `statusBarItemHoverBackground` token mapping
`statusBarItem.hoverBackground`, and paint it on status bar items. Make
the tabbed-panel close button and the view-container `⋯` button paint
`toolbar.hoverBackground` themselves rather than inheriting hover from
the host's `ThemeData`. Files: `lib/src/workbench_theme.dart`,
`lib/src/workbench_status_bar.dart`, `lib/src/workbench_tabbed_panel.dart`,
`lib/src/workbench_layout.dart`, and their tests (§spec:hover-canon,
§spec:status-bar). Depends on the `toolbarHoverBackground` token from
PR #167.

### Themed widget hover §road:themed-widget-hover

Add tokens mapping `textLink.activeForeground` and
`inputOption.hoverBackground`. Shift a hovered `TextButton` label to the
first and fill a hovered unselected `SegmentedButton` segment with the
second, in `lib/src/theming/workbench_chrome_theme.dart`,
`lib/src/workbench_theme.dart`, and their tests (§spec:hover-canon,
§spec:chrome-material-theming).

**Verify:** Run the example app under a dark and a light theme.

1. **Status bar.** Hover a status bar item. Confirm a 12% white tint in
   the dark theme and a 12% black tint in the light one.
2. **Shell icon buttons.** Hover the panel close button and a view
   container's `⋯` button. Confirm a `toolbar.hoverBackground` fill with
   no extra state layer. Remove `applyWorkbenchChrome` from the example's
   theme and confirm the same fill.
3. **Link button.** Hover a `TextButton`. Confirm its label shifts to
   `textLink.activeForeground`.
4. **Segments.** Hover an unselected segment of a `SegmentedButton`.
   Confirm an `inputOption.hoverBackground` fill, and that hovering the
   selected segment leaves its active treatment unchanged.

# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Chrome theming parity §road:chrome-theming-parity

Closes the gap between `applyWorkbenchChrome` and
§spec:chrome-material-theming. A consuming app placed stock
`OutlinedButton`s beside chrome-themed controls, and they rendered as
Material 3 pills because the chrome sets no theme for them. A stock
`TextField` falls back to Material defaults the same way.

### Outlined and elevated buttons §road:outlined-elevated-button-parity

Add `outlinedButtonTheme` and `elevatedButtonTheme` to
`applyWorkbenchChrome`, rendering both widgets as the secondary tier at
the shared flat compact sizing, in
`lib/src/theming/workbench_chrome_theme.dart`, its tests, and the
example app's button review sidebar (§spec:chrome-material-theming).

### Text input decoration §road:text-input-parity

Add a top-level `inputDecorationTheme` to `applyWorkbenchChrome` that
paints `TextField` and `TextFormField` from the `input.*` tokens and
`focusBorder`, leaving the `DropdownMenu` trigger's own decoration
unchanged, in `lib/src/theming/workbench_chrome_theme.dart`, its tests,
and the example app (§spec:chrome-material-theming,
§spec:form-controls-not-owned).

**Verify:** Run the example app.

1. **Buttons.** Place an `OutlinedButton`, an `OutlinedButton.icon` and
   an `ElevatedButton`. Confirm each one renders flat with a 4px corner
   and compact height, filled and labeled like `FilledButton.tonal`, and
   that a two-word label fits a half-width grid cell without wrapping.
2. **Text input.** Place a `TextField` with a hint. Confirm a dense
   single-line box with an `input.border` hairline and no floating
   label, and that focusing it swaps the hairline for `focusBorder`.
3. **Theme switch.** Switch between a dark and a light theme. Confirm
   the buttons and the text field follow the theme with the rest of the
   chrome.
4. **Select unchanged.** Open a `DropdownMenu`. Confirm its trigger
   still reads `dropdown.*`, not `input.*`.

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

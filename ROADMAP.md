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

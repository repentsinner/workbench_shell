# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Split Button §road:split-button

Give the shell VS Code's Commit control — a primary action, a pipe, and
a disclosure opening a menu — which Flutter ships no equivalent for
(§spec:split-button).

### Button token family §road:button-token-family

Add `button.separator`, `button.secondaryBorder` and
`button.secondaryHoverBackground` to `lib/src/workbench_theme.dart` and
drive the secondary tier's border and hover from the new pair in
`applyWorkbenchChrome` (`lib/src/theming/workbench_chrome_theme.dart`),
completing the nine registered `button.*` colours the package carries
six of (§spec:split-button, §spec:chrome-material-theming).

### Split button control §road:split-button-control

Add `WorkbenchSplitButton` under `lib/src/`, export it from
`lib/workbench_shell.dart`, open the shell's existing menu surface from
its disclosure half, and demonstrate both tiers in
`example/lib/main.dart` (§spec:split-button). Depends on
§road:button-token-family.

**Verify:** Place a primary and a secondary split button in the example
app. Each reads as one control: a single rounded outline across both
halves, no doubled stroke where they meet, and one pipe in
`button.separator` inset from the top and bottom edges rather than
running the full height. Click the primary half — the action runs and no
menu opens. Click the disclosure half — the menu opens anchored to the
control, carrying the primary action as its first entry, and rendering
at the same fill, border and row height as the View menu. Disable the
control and confirm both halves and the pipe dim together rather than
independently. Switch themes from the Settings sidebar and confirm both
tiers follow, with the secondary tier drawing its border and hover from
the `button.secondary*` family rather than a Material default.


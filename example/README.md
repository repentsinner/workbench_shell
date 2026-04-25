# workbench_shell example

Minimal Flutter app demonstrating `workbench_shell` chrome without any
host-application dependencies. Renders two activity-bar entries
(Explorer, Search), their sidebars, VS Code's five canonical bottom
panels with default keybindings, and a status bar.

## Run

```bash
cd packages/workbench_shell/example
flutter pub get
flutter run -d macos      # or -d linux / -d windows
```

## Test

```bash
flutter test
```

The widget test in `test/example_test.dart` asserts both activity-bar
icons render, the default sidebar body is visible, all five panel
tabs are present, the initial Problems tab body shows, and the
activity bar switches sidebars on tap.

## Layout

- Activity bar with two icons.
- Collapsible sidebar per active icon.
- Editor area placeholder in the main region.
- Tabbed bottom panel (close via its own affordance; toggle
  visibility from the View menu or with Cmd+J / Ctrl+J).
- Status bar with an info readout.
- View menu (system menu bar on macOS) wired through
  `WorkbenchMenuBar` + `WorkbenchShortcuts`.

## Bottom panels

VS Code's five canonical panels with default keybindings:

| Panel         | Shortcut          |
| ------------- | ----------------- |
| Problems      | Shift+Cmd+M       |
| Output        | Shift+Cmd+U       |
| Debug Console | Shift+Cmd+Y       |
| Terminal      | Ctrl+\`           |
| Ports         | (no default)      |

The example defines its own `ExamplePanel` enum and
`FocusExamplePanelIntent` — `workbench_shell` ships only
`ToggleBottomPanelIntent` and is agnostic about tab vocabulary.
This is the canonical integration pattern for pub.dev consumers:
hosts declare their own tabs and intents; the shell handles chrome.

No Rove, CNC, or notification-center code — the notification center
is a separate workstream that lands alongside §10 of the package SPEC.

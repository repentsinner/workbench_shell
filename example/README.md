# workbench_shell example

Minimal Flutter app demonstrating `workbench_shell` chrome without any
host-application dependencies. Renders five activity-bar entries
(Explorer, Search, Buttons, Notifications, Settings), their sidebars,
VS Code's five canonical bottom panels with default keybindings, a
notification-center demo, and a status bar.

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

The widget test in `test/example_test.dart` asserts the activity-bar
icons render, the default sidebar body is visible, all five panel
tabs are present, the initial Problems tab body shows, the activity
bar switches sidebars on tap, the Settings sidebar exposes the theme
slots, and the Notifications demo posts a toast.

## Layout

- Activity bar with five icons (Explorer, Search, Buttons,
  Notifications in the upper zone; Settings in the lower zone).
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

The Notifications sidebar posts toast cards through `NotificationService`
and `NotificationHost` (package SPEC §10), demonstrating the
notification-center API. No host-application or domain code.

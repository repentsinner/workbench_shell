# workbench_shell example

Minimal Flutter app demonstrating `workbench_shell` chrome without any
host-application dependencies. Renders two activity-bar entries
(Explorer, Search), their sidebars, a tabbed bottom panel with an
Output tab, and a status bar.

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
icons render, the default sidebar body is visible, the bottom panel's
Output tab is present, and the activity bar switches sidebars on tap.

## Layout

- Activity bar with two icons.
- Collapsible sidebar per active icon.
- Editor area placeholder in the main region.
- Tabbed bottom panel (close via its own affordance; toggle
  visibility from the View menu or with Cmd+J / Ctrl+J).
- Status bar with an info readout.
- View menu (system menu bar on macOS) wired through
  `WorkbenchMenuBar` + `WorkbenchShortcuts`.

No Rove, CNC, or notification-center code — the notification center
is a separate workstream that lands alongside §10 of the package SPEC.

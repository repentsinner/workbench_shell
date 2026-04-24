# workbench_shell

VS Code-style workbench layout chrome for Flutter desktop and mobile apps.
Provides the activity bar, sidebar, editor area, tabbed bottom panel,
status bar, and platform-conditional menu bar, plus a small vocabulary of
structural primitives (section, subsection, card, toggle card, empty
state) that keep sidebar and panel content visually consistent by
construction.

## Features

- `WorkbenchLayout` — composes activity bar + sidebar + editor + bottom
  panel + status bar, with controlled or uncontrolled section navigation.
- `WorkbenchTabbedPanel` — scrollable tab strip, close button, stable
  tab ids, View-menu and keyboard-shortcut focus contract.
- `WorkbenchStatusBar` + `WorkbenchStatusBarProblemsItem` — canonical
  VS Code Problems indicator with three severity counts.
- `WorkbenchMenuBar` — native `PlatformMenuBar` on macOS, in-window
  `MenuBar` on Windows and Linux.
- `WorkbenchShortcuts` — keyboard bindings aligned with VS Code
  defaults (Cmd/Ctrl+J, Shift+Cmd/Ctrl+M, etc.).
- `WorkbenchSection`, `WorkbenchSubsection`, `WorkbenchCard`,
  `WorkbenchToggleCard`, `WorkbenchEmptyState` — structural primitives
  that encode the workbench's visual hierarchy.
- `WorkbenchTheme` + `WorkbenchThemeController` — VS Code theme JSON
  loader, token map, and active theme state. Bundled themes: Dark
  Modern, Light Modern, Dark (Visual Studio), Light (Visual Studio).
- `TokenTheme` — syntax-highlighting companion surface populated from
  `tokenColors`.
- `WorkbenchLayoutConstants` — fixed geometry (activity bar width,
  sidebar widths, status bar height, spacing scale, icon sizes).
- `SlotRegistry`, `SidebarSlot`, `SidebarZone` — extension points for
  sidebar composition.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [WorkbenchTheme.darkDefault()],
      ),
      home: Scaffold(
        body: WorkbenchLayout(
          activityBarItems: const [
            ActivityBarItem(id: 'explorer', icon: Icons.folder),
            ActivityBarItem(id: 'search', icon: Icons.search),
          ],
          sidebarBuilder: (context, sectionId) =>
              WorkbenchSection(title: sectionId, children: const []),
          editorBuilder: (context) => const Center(child: Text('Editor')),
          statusBarItems: const [],
        ),
      ),
    );
  }
}
```

A runnable example with two sidebars, a tabbed bottom panel, and a
status bar lives under [`example/`](example/).

## Design

Chrome that is generic to a VS Code-style workbench belongs in
`workbench_shell`; chrome that encodes a specific product's domain
stays in the consuming application. The package imports only Flutter,
`equatable`, `material_color_utilities`, and `material_symbols_icons`;
it carries no BLoCs, domain types, or business logic.

See [SPEC.md](SPEC.md) for scope, boundary, theming contract, and
rationale.

## License

MIT -- see [LICENSE](LICENSE).

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
- `WorkbenchShortcuts` — ships the Cmd/Ctrl+J bottom-panel toggle;
  hosts register additional shortcuts via `extraShortcuts` or a
  surrounding `Shortcuts` widget.
- `WorkbenchSection`, `WorkbenchSubsection`, `WorkbenchCard`,
  `WorkbenchToggleCard`, `WorkbenchEmptyState` — structural primitives
  that encode the workbench's visual hierarchy.
- `WorkbenchTheme` + `WorkbenchThemeController` — VS Code theme JSON
  loader, token map, and active theme state. Bundled themes: Dark/Light
  2026, Dark/Light Modern, Dark+/Light+ (Visual Studio), Monokai, and
  Solarized Dark/Light.
- `TokenTheme` — syntax-highlighting companion surface populated from
  `tokenColors`.
- `NotificationService`, `NotificationHost`, `NotificationProgressController`
  — stacked toast cards anchored bottom-right, with progress and
  auto-dismiss.
- `WorkbenchLayoutConstants` — fixed geometry (activity bar width,
  sidebar widths, status bar height, spacing scale, icon sizes).

## Install

```bash
flutter pub add workbench_shell
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Build a WorkbenchTheme from VS Code theme JSON. This resolves an
    // empty map to dark defaults; load a bundled palette (Dark Modern,
    // Monokai, …) at runtime via WorkbenchThemeController.
    final workbench = WorkbenchTheme.fromVscodeColorMap(
      const VscodeColorMap(name: 'Dark', baseType: 'vs-dark', colors: {}),
    );

    return MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: [workbench]),
      home: Scaffold(
        body: WorkbenchLayout(
          activityBarItems: const [
            ActivityBarItem(id: 'explorer', label: 'Explorer', icon: Icons.folder),
            ActivityBarItem(id: 'search', label: 'Search', icon: Icons.search),
          ],
          sidebarBuilder: (sectionId) => WorkbenchSection(
            title: sectionId,
            child: const SizedBox.shrink(),
          ),
          editor: const Center(child: Text('Editor')),
          bottomPanel: const SizedBox.shrink(),
          statusBar: const WorkbenchStatusBar(),
        ),
      ),
    );
  }
}
```

A runnable example with five sidebars, a tabbed bottom panel, a
notification demo, and a status bar lives under [`example/`](example/).

## API

Full API documentation is generated from source and published at
[pub.dev/documentation/workbench_shell](https://pub.dev/documentation/workbench_shell/latest/).

## Design

Chrome that is generic to a VS Code-style workbench belongs in
`workbench_shell`; chrome that encodes a specific product's domain
stays in the consuming application. The package imports only Flutter,
`equatable`, `material_color_utilities`, and `material_symbols_icons`;
it carries no BLoCs, domain types, or business logic.

See [SPEC.md](SPEC.md) for scope, boundary, theming contract, and
rationale.

## License

BSD 3-Clause -- see [LICENSE](LICENSE).

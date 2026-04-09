import 'package:flutter/material.dart';
import 'package:workbench_shell/workbench_shell.dart';

/// Shared test [WorkbenchTheme] fixture.
///
/// Built from an empty [VscodeColorMap] so every token resolves to
/// its built-in fallback — tests get a full theme without hand
/// listing each field.
final WorkbenchTheme testWorkbenchTheme = WorkbenchTheme.fromVscodeColorMap(
  const VscodeColorMap(name: 'Test', baseType: 'vs-dark', colors: {}),
);

/// Wrap a widget in a [MaterialApp] with [testWorkbenchTheme] installed.
Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [testWorkbenchTheme]),
    home: Scaffold(body: child),
  );
}

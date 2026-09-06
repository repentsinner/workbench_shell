import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// The open popup's panel — the `Material` Flutter's `_MenuPanel` builds
/// around the menu's children, carrying the fill and hairline resolved from
/// `MenuThemeData`. Located as the nearest `Material` *ancestor* of the row
/// labelled [rowLabel], which excludes the `Material` the row's own
/// `MenuItemButton` builds beneath itself.
///
/// Matches the *last* row carrying the label: `DropdownMenu` keeps an
/// offstage copy of its rows in the anchor's own subtree to measure the
/// menu's preferred width, and that copy sits above the open panel's row in
/// the element tree.
Material popupPanelOf(WidgetTester tester, String rowLabel) {
  return tester.widget<Material>(
    find
        .ancestor(
          of: find.widgetWithText(MenuItemButton, rowLabel).last,
          matching: find.byType(Material),
        )
        .first,
  );
}

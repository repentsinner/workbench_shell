import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/src/workbench_surface_treatment.dart';
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
///
/// [modernUI] publishes the surface treatment the way `WorkbenchLayout` does
/// (§spec:modern-ui-surfaces), so a primitive can be pumped under either
/// treatment without hand-rolling the inherited widget. [theme] overrides the
/// shared fixture for a test that needs particular tokens.
Widget wrapWithTheme(
  Widget child, {
  bool modernUI = true,
  WorkbenchTheme? theme,
}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [theme ?? testWorkbenchTheme]),
    home: Scaffold(
      body: WorkbenchSurfaceTreatment(modernUI: modernUI, child: child),
    ),
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

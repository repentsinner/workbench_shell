import 'package:flutter/material.dart';
import 'package:workbench_shell/workbench_shell.dart';

/// Shared test [WorkbenchTheme] fixture.
const WorkbenchTheme testWorkbenchTheme = WorkbenchTheme(
  activityBarBackground: Color(0xFF333333),
  activityBarBorder: Color(0xFF444444),
  activityBarForeground: Color(0xFFFFFFFF),
  activityBarInactiveForeground: Color(0xFF888888),
  sideBarBackground: Color(0xFF252526),
  sideBarBorder: Color(0xFF444444),
  editorBackground: Color(0xFF1E1E1E),
  panelBorder: Color(0xFF444444),
  statusBarBackground: Color(0xFF007ACC),
  statusBarBorder: Color(0xFF007ACC),
  sashHoverBackground: Color(0xFF007ACC),
  sidebarOrPanelHeading: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFFBBBBBB),
  ),
  sectionTitleStyle: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Color(0xFFCCCCCC),
  ),
  subsectionTitleStyle: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Color(0xFFCCCCCC),
  ),
  bodyStyle: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: Color(0xFFCCCCCC),
  ),
  helperStyle: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: Color(0xFF888888),
  ),
  borderColor: Color(0xFF3C3C3C),
  focusBorderColor: Color(0xFF007ACC),
  inputBackground: Color(0xFF3C3C3C),
  descriptionForeground: Color(0xFF888888),
);

/// Wrap a widget in a [MaterialApp] with [testWorkbenchTheme] installed.
Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [testWorkbenchTheme]),
    home: Scaffold(body: child),
  );
}

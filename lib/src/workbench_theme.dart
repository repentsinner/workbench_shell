import 'package:flutter/material.dart';

/// Color tokens for workbench layout chrome.
///
/// Carries only the colors needed by the shell widgets (activity bar,
/// sidebar container, resizers, status bar container). Content-area
/// colors belong to the consumer's own theme.
///
/// Install as a [ThemeExtension] on the app's [ThemeData]. Shell
/// widgets access it via [WorkbenchThemeExtension.of].
class WorkbenchTheme extends ThemeExtension<WorkbenchTheme> {
  // Activity bar
  final Color activityBarBackground;
  final Color activityBarBorder;
  final Color activityBarForeground;
  final Color activityBarInactiveForeground;

  // Sidebar
  final Color sideBarBackground;
  final Color sideBarBorder;

  // Editor area
  final Color editorBackground;

  // Panel
  final Color panelBorder;

  // Status bar
  final Color statusBarBackground;
  final Color statusBarBorder;

  // Sash (resizer drag handle)
  final Color sashHoverBackground;

  // Sidebar/panel heading text style
  final TextStyle sidebarOrPanelHeading;

  const WorkbenchTheme({
    required this.activityBarBackground,
    required this.activityBarBorder,
    required this.activityBarForeground,
    required this.activityBarInactiveForeground,
    required this.sideBarBackground,
    required this.sideBarBorder,
    required this.editorBackground,
    required this.panelBorder,
    required this.statusBarBackground,
    required this.statusBarBorder,
    required this.sashHoverBackground,
    required this.sidebarOrPanelHeading,
  });

  @override
  WorkbenchTheme copyWith({
    Color? activityBarBackground,
    Color? activityBarBorder,
    Color? activityBarForeground,
    Color? activityBarInactiveForeground,
    Color? sideBarBackground,
    Color? sideBarBorder,
    Color? editorBackground,
    Color? panelBorder,
    Color? statusBarBackground,
    Color? statusBarBorder,
    Color? sashHoverBackground,
    TextStyle? sidebarOrPanelHeading,
  }) {
    return WorkbenchTheme(
      activityBarBackground:
          activityBarBackground ?? this.activityBarBackground,
      activityBarBorder: activityBarBorder ?? this.activityBarBorder,
      activityBarForeground:
          activityBarForeground ?? this.activityBarForeground,
      activityBarInactiveForeground:
          activityBarInactiveForeground ?? this.activityBarInactiveForeground,
      sideBarBackground: sideBarBackground ?? this.sideBarBackground,
      sideBarBorder: sideBarBorder ?? this.sideBarBorder,
      editorBackground: editorBackground ?? this.editorBackground,
      panelBorder: panelBorder ?? this.panelBorder,
      statusBarBackground: statusBarBackground ?? this.statusBarBackground,
      statusBarBorder: statusBarBorder ?? this.statusBarBorder,
      sashHoverBackground: sashHoverBackground ?? this.sashHoverBackground,
      sidebarOrPanelHeading:
          sidebarOrPanelHeading ?? this.sidebarOrPanelHeading,
    );
  }

  @override
  WorkbenchTheme lerp(covariant WorkbenchTheme? other, double t) {
    if (other == null) return this;
    return WorkbenchTheme(
      activityBarBackground: Color.lerp(
        activityBarBackground,
        other.activityBarBackground,
        t,
      )!,
      activityBarBorder: Color.lerp(
        activityBarBorder,
        other.activityBarBorder,
        t,
      )!,
      activityBarForeground: Color.lerp(
        activityBarForeground,
        other.activityBarForeground,
        t,
      )!,
      activityBarInactiveForeground: Color.lerp(
        activityBarInactiveForeground,
        other.activityBarInactiveForeground,
        t,
      )!,
      sideBarBackground: Color.lerp(
        sideBarBackground,
        other.sideBarBackground,
        t,
      )!,
      sideBarBorder: Color.lerp(sideBarBorder, other.sideBarBorder, t)!,
      editorBackground: Color.lerp(
        editorBackground,
        other.editorBackground,
        t,
      )!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      statusBarBackground: Color.lerp(
        statusBarBackground,
        other.statusBarBackground,
        t,
      )!,
      statusBarBorder: Color.lerp(statusBarBorder, other.statusBarBorder, t)!,
      sashHoverBackground: Color.lerp(
        sashHoverBackground,
        other.sashHoverBackground,
        t,
      )!,
      sidebarOrPanelHeading: TextStyle.lerp(
        sidebarOrPanelHeading,
        other.sidebarOrPanelHeading,
        t,
      )!,
    );
  }
}

/// Convenience accessor for [WorkbenchTheme] from [BuildContext].
extension WorkbenchThemeExtension on BuildContext {
  /// The [WorkbenchTheme] from the nearest [Theme] ancestor.
  WorkbenchTheme get workbenchTheme =>
      Theme.of(this).extension<WorkbenchTheme>()!;
}

import 'package:flutter/material.dart';

/// Color and typography tokens for workbench layout chrome and
/// content primitives.
///
/// Carries the tokens needed by the shell widgets (activity bar,
/// sidebar container, resizers, status bar container) plus the
/// content primitives ([WorkbenchSection], [WorkbenchCard], form
/// controls, etc.) that sidebars and panels compose.
///
/// Install as a [ThemeExtension] on the app's [ThemeData]. Shell
/// widgets and primitives access it via [WorkbenchThemeExtension.of].
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

  // Sidebar/panel heading text style (chrome — the tab strip label)
  final TextStyle sidebarOrPanelHeading;

  // ---- Content primitive tokens ----

  /// Section title — top-level grouping inside sidebar/panel content.
  /// Typical: 14pt w600.
  final TextStyle sectionTitleStyle;

  /// Subsection title — second-level grouping inside a section.
  /// Typical: 12pt w500.
  final TextStyle subsectionTitleStyle;

  /// Body text for control labels and content.
  final TextStyle bodyStyle;

  /// Helper text under form controls. Smaller and dimmer than body.
  final TextStyle helperStyle;

  /// Default border color for cards, text inputs, dropdowns, buttons.
  final Color borderColor;

  /// Border color when a form control is focused.
  final Color focusBorderColor;

  /// Background color for text inputs and dropdowns.
  final Color inputBackground;

  /// Secondary / description foreground — used by empty-state subtitle
  /// and tooltips.
  final Color descriptionForeground;

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
    required this.sectionTitleStyle,
    required this.subsectionTitleStyle,
    required this.bodyStyle,
    required this.helperStyle,
    required this.borderColor,
    required this.focusBorderColor,
    required this.inputBackground,
    required this.descriptionForeground,
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
    TextStyle? sectionTitleStyle,
    TextStyle? subsectionTitleStyle,
    TextStyle? bodyStyle,
    TextStyle? helperStyle,
    Color? borderColor,
    Color? focusBorderColor,
    Color? inputBackground,
    Color? descriptionForeground,
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
      sectionTitleStyle: sectionTitleStyle ?? this.sectionTitleStyle,
      subsectionTitleStyle: subsectionTitleStyle ?? this.subsectionTitleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      helperStyle: helperStyle ?? this.helperStyle,
      borderColor: borderColor ?? this.borderColor,
      focusBorderColor: focusBorderColor ?? this.focusBorderColor,
      inputBackground: inputBackground ?? this.inputBackground,
      descriptionForeground:
          descriptionForeground ?? this.descriptionForeground,
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
      sectionTitleStyle: TextStyle.lerp(
        sectionTitleStyle,
        other.sectionTitleStyle,
        t,
      )!,
      subsectionTitleStyle: TextStyle.lerp(
        subsectionTitleStyle,
        other.subsectionTitleStyle,
        t,
      )!,
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t)!,
      helperStyle: TextStyle.lerp(helperStyle, other.helperStyle, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
      focusBorderColor: Color.lerp(
        focusBorderColor,
        other.focusBorderColor,
        t,
      )!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      descriptionForeground: Color.lerp(
        descriptionForeground,
        other.descriptionForeground,
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

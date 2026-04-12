import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import 'theming/token_theme.dart';
import 'theming/vscode_color_map.dart';

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
  // ---- Activity bar ----
  final Color activityBarBackground;

  /// Activity bar right-edge separator. Null in modern themes
  /// (Dark+, Light+) whose VS Code registry default is null —
  /// widgets shall skip painting the separator entirely rather than
  /// falling back to a neighboring border color. Dark Modern and
  /// similar themes set this explicitly. See SPEC §9.6 Token
  /// Semantics: Null and Alpha.
  final Color? activityBarBorder;

  final Color activityBarForeground;
  final Color activityBarInactiveForeground;

  // ---- Sidebar ----
  final Color sideBarBackground;

  /// Sidebar right-edge separator. Null in modern themes whose VS
  /// Code registry default is null — see [activityBarBorder].
  final Color? sideBarBorder;

  final Color sideBarForeground;

  // ---- Editor area ----
  final Color editorBackground;

  // ---- Panel ----
  final Color panelBackground;

  /// Panel top-edge separator. Defaults to translucent grey
  /// (`#80808059`) in every modern VS Code theme so the seam blends
  /// with the surface beneath. Nullable so a theme can suppress the
  /// panel border outright.
  final Color? panelBorder;

  final Color panelTitleActiveForeground;
  final Color panelTitleInactiveForeground;

  // ---- Status bar ----
  final Color statusBarBackground;
  final Color statusBarBorder;
  final Color statusBarForeground;

  // ---- Tab strip (container-level) ----
  final Color tabActiveBackground;
  final Color tabInactiveBackground;
  final Color tabActiveForeground;
  final Color tabInactiveForeground;
  final Color tabBorder;

  // ---- Input / dropdown / button ----
  final Color inputBackground;
  final Color inputForeground;
  final Color inputBorder;
  final Color inputPlaceholderForeground;
  final Color dropdownBackground;
  final Color buttonBackground;
  final Color buttonForeground;
  final Color buttonHoverBackground;

  // ---- Foreground / accent ----
  final Color foreground;
  final Color descriptionForeground;
  final Color accentForeground;

  // ---- Semantic status ----
  final Color errorForeground;
  final Color warningForeground;
  final Color successForeground;
  final Color infoForeground;

  // ---- List hover / selection ----
  final Color listHoverBackground;
  final Color listActiveSelectionBackground;

  // ---- Focus ring ----
  final Color focusBorder;

  // ---- Sash (resizer drag handle) ----
  final Color sashHoverBackground;

  // ---- Menu bar (Windows/Linux in-window fallback strip) ----
  //
  // macOS renders the View menu through `PlatformMenuBar` which
  // binds to `NSMenu`, so these tokens only affect the Windows/Linux
  // Material `MenuBar` strip. Kept distinct from activity/side bar
  // tokens so future theming work (e.g. a custom title bar) can
  // redirect the menu strip without disturbing adjacent chrome.
  final Color menuBarBackground;
  final Color menuBarForeground;
  final Color menuBarHoverBackground;
  final Color menuBarBorder;

  // ---- Pre-mixed opacity variants (semantic color modifiers, §9.6) ----
  final Color focusBorderSubtle;
  final Color focusBorderMuted;
  final Color focusBorderProminent;
  final Color descriptionBadgeBackground;
  final Color descriptionDisabledBackground;
  final Color descriptionMuted;
  final Color descriptionSecondary;
  final Color errorBorderMuted;
  final Color warningBackgroundSubtle;
  final Color warningBorderMuted;
  final Color infoBackgroundSubtle;
  final Color infoBorderMuted;
  final Color successBackgroundSubtle;
  final Color successBorderMuted;
  final Color sideBarBackgroundSubtle;
  final Color sideBarBackgroundMuted;
  final Color editorBackgroundOverlay;

  // ---- Base font ----
  final String fontFamily;

  // ---- Tab strip chrome (consumed by WorkbenchTabbedPanel) ----
  final Color tabBarLabelColor;
  final Color tabBarUnselectedLabelColor;
  final Color tabBarIndicatorColor;
  final Color tabBarDividerColor;

  // ---- Content primitive tokens ----
  final TextStyle sectionTitleStyle;
  final TextStyle subsectionTitleStyle;
  final TextStyle bodyStyle;
  final TextStyle helperStyle;

  /// Content-primitive border color (WorkbenchCard, form inputs,
  /// action button outlines). Derived from [panelBorder], so follows
  /// its nullability: null when a theme explicitly suppresses panel
  /// borders. Consumers shall skip drawing or fall back to
  /// [Colors.transparent] when null.
  final Color? borderColor;

  final Color focusBorderColor;

  // ---- Semantic text styles (§9.6 Text Styles) ----
  final TextStyle sectionTitle;
  final TextStyle labelText;
  final TextStyle bodyText;
  final TextStyle captionText;
  final TextStyle smallText;
  final TextStyle buttonTextStyle;
  final TextStyle statusText;

  /// Primary status-bar item text style.
  ///
  /// Matches the size/weight of [helperStyle] but paints in
  /// [statusBarForeground] so text reads against the status bar's
  /// theme-defined background (`#007ACC` blue by default). Use from
  /// every status-bar leaf that needs a foreground — defaulting to
  /// [helperStyle] is a legibility regression because that style
  /// resolves to `descriptionForeground` (grey on blue).
  final TextStyle statusBarTextStyle;

  final TextStyle valueText;
  final TextStyle sidebarOrPanelHeading;
  final TextStyle loglineTime;
  final TextStyle loglineName;
  final TextStyle loglineLevel;
  final TextStyle loglineMessage;

  // ---- Syntax token theme ----
  final TokenTheme tokenTheme;

  // ---- Domain color resolver input (§9.15) ----
  /// HCT tone (0–100) of the canonical chrome surface ([editorBackground]).
  ///
  /// Domain themes (e.g. `RoveDomainTheme`) read this to pick a tone
  /// from a tonal palette that contrasts the active chrome. Dark
  /// chrome (low tone) selects high palette tones; light chrome
  /// selects low palette tones. See SPEC §9.15.
  final double surfaceTone;

  const WorkbenchTheme({
    required this.activityBarBackground,
    required this.activityBarBorder,
    required this.activityBarForeground,
    required this.activityBarInactiveForeground,
    required this.sideBarBackground,
    required this.sideBarBorder,
    required this.sideBarForeground,
    required this.editorBackground,
    required this.panelBackground,
    required this.panelBorder,
    required this.panelTitleActiveForeground,
    required this.panelTitleInactiveForeground,
    required this.statusBarBackground,
    required this.statusBarBorder,
    required this.statusBarForeground,
    required this.tabActiveBackground,
    required this.tabInactiveBackground,
    required this.tabActiveForeground,
    required this.tabInactiveForeground,
    required this.tabBorder,
    required this.inputBackground,
    required this.inputForeground,
    required this.inputBorder,
    required this.inputPlaceholderForeground,
    required this.dropdownBackground,
    required this.buttonBackground,
    required this.buttonForeground,
    required this.buttonHoverBackground,
    required this.foreground,
    required this.descriptionForeground,
    required this.accentForeground,
    required this.errorForeground,
    required this.warningForeground,
    required this.successForeground,
    required this.infoForeground,
    required this.listHoverBackground,
    required this.listActiveSelectionBackground,
    required this.focusBorder,
    required this.sashHoverBackground,
    required this.menuBarBackground,
    required this.menuBarForeground,
    required this.menuBarHoverBackground,
    required this.menuBarBorder,
    required this.focusBorderSubtle,
    required this.focusBorderMuted,
    required this.focusBorderProminent,
    required this.descriptionBadgeBackground,
    required this.descriptionDisabledBackground,
    required this.descriptionMuted,
    required this.descriptionSecondary,
    required this.errorBorderMuted,
    required this.warningBackgroundSubtle,
    required this.warningBorderMuted,
    required this.infoBackgroundSubtle,
    required this.infoBorderMuted,
    required this.successBackgroundSubtle,
    required this.successBorderMuted,
    required this.sideBarBackgroundSubtle,
    required this.sideBarBackgroundMuted,
    required this.editorBackgroundOverlay,
    required this.fontFamily,
    required this.tabBarLabelColor,
    required this.tabBarUnselectedLabelColor,
    required this.tabBarIndicatorColor,
    required this.tabBarDividerColor,
    required this.sectionTitleStyle,
    required this.subsectionTitleStyle,
    required this.bodyStyle,
    required this.helperStyle,
    required this.borderColor,
    required this.focusBorderColor,
    required this.sectionTitle,
    required this.labelText,
    required this.bodyText,
    required this.captionText,
    required this.smallText,
    required this.buttonTextStyle,
    required this.statusText,
    required this.statusBarTextStyle,
    required this.valueText,
    required this.sidebarOrPanelHeading,
    required this.loglineTime,
    required this.loglineName,
    required this.loglineLevel,
    required this.loglineMessage,
    required this.tokenTheme,
    required this.surfaceTone,
  });

  /// Compute the HCT tone (0–100) for [color] using
  /// `package:material_color_utilities`.
  ///
  /// Used to derive [surfaceTone] from the chrome's primary
  /// background color. Exposed as a static so callers that build a
  /// [WorkbenchTheme] manually can
  /// reuse it without re-deriving the formula.
  static double hctToneFor(Color color) => Hct.fromInt(color.toARGB32()).tone;

  /// Build a [WorkbenchTheme] from a parsed VS Code color theme.
  ///
  /// Resolves every chrome token with sensible fallbacks so themes
  /// that omit tokens still produce a valid workbench theme. The
  /// `fontFamily` parameter overrides the default (`Inconsolata`)
  /// used across the semantic text styles.
  factory WorkbenchTheme.fromVscodeColorMap(
    VscodeColorMap map, {
    String fontFamily = 'Inconsolata',
  }) {
    // Base-type-aware fallback: picks the correct default for dark vs
    // light themes. Values sourced from VS Code's color registry in
    // src/vs/workbench/common/theme.ts and
    // src/vs/platform/theme/common/colors/*.ts.
    Color dl(Color dark, Color light) => map.isDark ? dark : light;

    final fg = map.resolve(
      'foreground',
      dl(const Color(0xFFCCCCCC), const Color(0xFF000000)),
    );
    // VS Code: transparent(foreground, 0.5) for both dark and light.
    final secondaryFg = map.resolve(
      'descriptionForeground',
      fg.withValues(alpha: 0.5),
    );
    final accentFg = map.resolve(
      'focusBorder',
      dl(const Color(0xFF007ACC), const Color(0xFF0078D4)),
    );
    // VS Code registry: #FFFFFF in both dark and light.
    final statusBarFg = map.resolve(
      'statusBar.foreground',
      const Color(0xFFFFFFFF),
    );
    // VS Code registry: Color.fromHex('#808080').transparent(0.35) →
    // 0x59808080 — same for dark and light.
    final Color panelBorder = map['panel.border'] ?? const Color(0x59808080);
    final sideBarBg = map.resolve(
      'sideBar.background',
      dl(const Color(0xFF252526), const Color(0xFFF3F3F3)),
    );
    final editorBg = map.resolve(
      'editor.background',
      dl(const Color(0xFF1E1E1E), const Color(0xFFFFFFFF)),
    );
    final errorFg = map.resolve('errorForeground', const Color(0xFFF85149));
    final warningFg = map.resolve(
      'editorWarning.foreground',
      const Color(0xFFFF9800),
    );
    final successFg = map.resolve(
      'testing.iconPassed',
      const Color(0xFF4CAF50),
    );
    final infoFg = map.resolve(
      'editorInfo.foreground',
      const Color(0xFF2196F3),
    );

    TextStyle t(double size, FontWeight weight, {Color? color}) => TextStyle(
      fontFamily: fontFamily,
      color: color ?? fg,
      fontSize: size,
      fontWeight: weight,
    );

    return WorkbenchTheme(
      // Activity bar
      activityBarBackground: map.resolve(
        'activityBar.background',
        dl(const Color(0xFF333333), const Color(0xFF2C2C2C)),
      ),
      // Null when the theme omits it — VS Code's ACTIVITY_BAR_BORDER
      // registry default is null in dark/light themes. Widgets skip
      // painting the separator when null (see SPEC §9.6).
      activityBarBorder: map['activityBar.border'],
      activityBarForeground: map.resolve(
        'activityBar.foreground',
        const Color(0xFFFFFFFF),
      ),
      // VS Code: transparent(activityBar.foreground, 0.4).
      activityBarInactiveForeground: map.resolve(
        'activityBar.inactiveForeground',
        map
            .resolve('activityBar.foreground', const Color(0xFFFFFFFF))
            .withValues(alpha: 0.4),
      ),
      // Sidebar
      sideBarBackground: sideBarBg,
      // Null by the same registry semantics as activityBar.border.
      sideBarBorder: map['sideBar.border'],
      sideBarForeground: map.resolve('sideBar.foreground', fg),
      // Editor
      editorBackground: editorBg,
      // Panel
      panelBackground: map.resolve('panel.background', editorBg),
      panelBorder: panelBorder,
      panelTitleActiveForeground: map.resolve(
        'panelTitle.activeForeground',
        fg,
      ),
      panelTitleInactiveForeground: map.resolve(
        'panelTitle.inactiveForeground',
        secondaryFg,
      ),
      // Status bar
      statusBarBackground: map.resolve(
        'statusBar.background',
        const Color(0xFF007ACC),
      ),
      // VS Code registry: null for dark/light, contrastBorder for HC.
      // Transparent fallback so the BorderSide draws but is invisible.
      statusBarBorder: map['statusBar.border'] ?? const Color(0x00000000),
      statusBarForeground: statusBarFg,
      // Tab strip container
      // VS Code: tab.activeBackground inherits from editor.background.
      tabActiveBackground: map.resolve('tab.activeBackground', editorBg),
      tabInactiveBackground: map.resolve(
        'tab.inactiveBackground',
        dl(const Color(0xFF2D2D2D), const Color(0xFFECECEC)),
      ),
      tabActiveForeground: map.resolve(
        'tab.activeForeground',
        dl(const Color(0xFFFFFFFF), const Color(0xFF333333)),
      ),
      tabInactiveForeground: map.resolve('tab.inactiveForeground', secondaryFg),
      tabBorder: map.resolve(
        'tab.border',
        dl(const Color(0xFF252526), const Color(0xFFF3F3F3)),
      ),
      // Inputs / buttons
      inputBackground: map.resolve(
        'input.background',
        dl(const Color(0xFF3C3C3C), const Color(0xFFFFFFFF)),
      ),
      inputForeground: map.resolve('input.foreground', fg),
      // VS Code registry: null for dark/light.
      inputBorder: map['input.border'] ?? const Color(0x00000000),
      inputPlaceholderForeground: map.resolve(
        'input.placeholderForeground',
        secondaryFg,
      ),
      dropdownBackground: map.resolve(
        'dropdown.background',
        dl(const Color(0xFF3C3C3C), const Color(0xFFFFFFFF)),
      ),
      buttonBackground: map.resolve(
        'button.background',
        dl(const Color(0xFF0E639C), const Color(0xFF007ACC)),
      ),
      buttonForeground: map.resolve(
        'button.foreground',
        const Color(0xFFFFFFFF),
      ),
      buttonHoverBackground: map.resolve(
        'button.hoverBackground',
        dl(const Color(0xFF1177BB), const Color(0xFF0062A3)),
      ),
      // Foregrounds / accent
      foreground: fg,
      descriptionForeground: secondaryFg,
      accentForeground: map.resolve(
        'textLink.foreground',
        const Color(0xFF569CD6),
      ),
      // Semantic status
      errorForeground: errorFg,
      warningForeground: warningFg,
      successForeground: successFg,
      infoForeground: infoFg,
      // List
      listHoverBackground: map.resolve(
        'list.hoverBackground',
        dl(const Color(0xFF2A2D2E), const Color(0xFFF0F0F0)),
      ),
      listActiveSelectionBackground: map.resolve(
        'list.activeSelectionBackground',
        dl(const Color(0xFF04395E), const Color(0xFF0060C0)),
      ),
      // Focus / sash
      focusBorder: accentFg,
      sashHoverBackground: map.resolve('sash.hoverBackground', accentFg),
      // Menu bar (Windows/Linux in-window strip).
      // VS Code stops at `titleBar.activeBackground` for the strip
      // itself; individual menu items read `menubar.*` and `menu.*`.
      menuBarBackground: map.resolve(
        'titleBar.activeBackground',
        dl(const Color(0xFF3C3C3C), const Color(0xFFDDDDDD)),
      ),
      menuBarForeground: map.resolve(
        'titleBar.activeForeground',
        dl(const Color(0xFFCCCCCC), const Color(0xFF333333)),
      ),
      menuBarHoverBackground: map.resolve(
        'menubar.selectionBackground',
        map.resolve(
          'list.hoverBackground',
          dl(const Color(0xFF2A2D2E), const Color(0xFFF0F0F0)),
        ),
      ),
      // menuBar is an in-window strip; keep a visible seam for the
      // Win/Linux Material MenuBar. Fall through to the panel border
      // default, which is already translucent-grey.
      menuBarBorder: map.resolve('titleBar.border', panelBorder),
      // Pre-mixed modifiers
      focusBorderSubtle: accentFg.withValues(alpha: 0.1),
      focusBorderMuted: accentFg.withValues(alpha: 0.3),
      focusBorderProminent: accentFg.withValues(alpha: 0.8),
      descriptionBadgeBackground: secondaryFg.withValues(alpha: 0.2),
      descriptionDisabledBackground: secondaryFg.withValues(alpha: 0.3),
      descriptionMuted: secondaryFg.withValues(alpha: 0.5),
      descriptionSecondary: secondaryFg.withValues(alpha: 0.7),
      errorBorderMuted: errorFg.withValues(alpha: 0.3),
      warningBackgroundSubtle: warningFg.withValues(alpha: 0.1),
      warningBorderMuted: warningFg.withValues(alpha: 0.3),
      infoBackgroundSubtle: infoFg.withValues(alpha: 0.1),
      infoBorderMuted: infoFg.withValues(alpha: 0.3),
      successBackgroundSubtle: successFg.withValues(alpha: 0.1),
      successBorderMuted: successFg.withValues(alpha: 0.3),
      sideBarBackgroundSubtle: sideBarBg.withValues(alpha: 0.3),
      sideBarBackgroundMuted: sideBarBg.withValues(alpha: 0.5),
      editorBackgroundOverlay: editorBg.withValues(alpha: 0.85),
      // Font / tab strip chrome
      fontFamily: fontFamily,
      tabBarLabelColor: map.resolve('panelTitle.activeForeground', fg),
      tabBarUnselectedLabelColor: map.resolve(
        'panelTitle.inactiveForeground',
        secondaryFg,
      ),
      tabBarIndicatorColor: fg,
      tabBarDividerColor: const Color(0x00000000),
      // Content primitive tokens (kept for widgets that already read them)
      sectionTitleStyle: t(14, FontWeight.w600),
      subsectionTitleStyle: t(12, FontWeight.w500),
      bodyStyle: t(12, FontWeight.w400),
      helperStyle: t(11, FontWeight.w400, color: secondaryFg),
      borderColor: panelBorder,
      focusBorderColor: accentFg,
      // Semantic text styles (§9.6)
      sectionTitle: t(14, FontWeight.w600),
      labelText: t(12, FontWeight.w500),
      bodyText: t(12, FontWeight.w400),
      captionText: t(11, FontWeight.w400, color: secondaryFg),
      smallText: t(10, FontWeight.w400, color: secondaryFg),
      buttonTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      statusText: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      // Match the size/weight of helperStyle (11pt, w400) but paint
      // in statusBar.foreground rather than descriptionForeground so
      // status bar text reads against the blue status bar background.
      statusBarTextStyle: t(11, FontWeight.w400, color: statusBarFg),
      valueText: t(12, FontWeight.w600),
      sidebarOrPanelHeading: t(13, FontWeight.w600),
      loglineTime: t(11, FontWeight.w400, color: secondaryFg),
      loglineName: t(11, FontWeight.w500, color: accentFg),
      loglineLevel: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      loglineMessage: t(11, FontWeight.w400),
      // Syntax token theme
      tokenTheme: map.resolvedTokenTheme,
      // HCT tone of the canonical chrome surface (editor background).
      // Domain themes read this to pick contrasting palette tones —
      // see RoveDomainTheme and SPEC §9.15.
      surfaceTone: hctToneFor(editorBg),
    );
  }

  @override
  WorkbenchTheme copyWith({
    Color? activityBarBackground,
    Color? activityBarBorder,
    Color? activityBarForeground,
    Color? activityBarInactiveForeground,
    Color? sideBarBackground,
    Color? sideBarBorder,
    Color? sideBarForeground,
    Color? editorBackground,
    Color? panelBackground,
    Color? panelBorder,
    Color? panelTitleActiveForeground,
    Color? panelTitleInactiveForeground,
    Color? statusBarBackground,
    Color? statusBarBorder,
    Color? statusBarForeground,
    Color? tabActiveBackground,
    Color? tabInactiveBackground,
    Color? tabActiveForeground,
    Color? tabInactiveForeground,
    Color? tabBorder,
    Color? inputBackground,
    Color? inputForeground,
    Color? inputBorder,
    Color? inputPlaceholderForeground,
    Color? dropdownBackground,
    Color? buttonBackground,
    Color? buttonForeground,
    Color? buttonHoverBackground,
    Color? foreground,
    Color? descriptionForeground,
    Color? accentForeground,
    Color? errorForeground,
    Color? warningForeground,
    Color? successForeground,
    Color? infoForeground,
    Color? listHoverBackground,
    Color? listActiveSelectionBackground,
    Color? focusBorder,
    Color? sashHoverBackground,
    Color? menuBarBackground,
    Color? menuBarForeground,
    Color? menuBarHoverBackground,
    Color? menuBarBorder,
    Color? focusBorderSubtle,
    Color? focusBorderMuted,
    Color? focusBorderProminent,
    Color? descriptionBadgeBackground,
    Color? descriptionDisabledBackground,
    Color? descriptionMuted,
    Color? descriptionSecondary,
    Color? errorBorderMuted,
    Color? warningBackgroundSubtle,
    Color? warningBorderMuted,
    Color? infoBackgroundSubtle,
    Color? infoBorderMuted,
    Color? successBackgroundSubtle,
    Color? successBorderMuted,
    Color? sideBarBackgroundSubtle,
    Color? sideBarBackgroundMuted,
    Color? editorBackgroundOverlay,
    String? fontFamily,
    Color? tabBarLabelColor,
    Color? tabBarUnselectedLabelColor,
    Color? tabBarIndicatorColor,
    Color? tabBarDividerColor,
    TextStyle? sectionTitleStyle,
    TextStyle? subsectionTitleStyle,
    TextStyle? bodyStyle,
    TextStyle? helperStyle,
    Color? borderColor,
    Color? focusBorderColor,
    TextStyle? sectionTitle,
    TextStyle? labelText,
    TextStyle? bodyText,
    TextStyle? captionText,
    TextStyle? smallText,
    TextStyle? buttonTextStyle,
    TextStyle? statusText,
    TextStyle? statusBarTextStyle,
    TextStyle? valueText,
    TextStyle? sidebarOrPanelHeading,
    TextStyle? loglineTime,
    TextStyle? loglineName,
    TextStyle? loglineLevel,
    TextStyle? loglineMessage,
    TokenTheme? tokenTheme,
    double? surfaceTone,
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
      sideBarForeground: sideBarForeground ?? this.sideBarForeground,
      editorBackground: editorBackground ?? this.editorBackground,
      panelBackground: panelBackground ?? this.panelBackground,
      panelBorder: panelBorder ?? this.panelBorder,
      panelTitleActiveForeground:
          panelTitleActiveForeground ?? this.panelTitleActiveForeground,
      panelTitleInactiveForeground:
          panelTitleInactiveForeground ?? this.panelTitleInactiveForeground,
      statusBarBackground: statusBarBackground ?? this.statusBarBackground,
      statusBarBorder: statusBarBorder ?? this.statusBarBorder,
      statusBarForeground: statusBarForeground ?? this.statusBarForeground,
      tabActiveBackground: tabActiveBackground ?? this.tabActiveBackground,
      tabInactiveBackground:
          tabInactiveBackground ?? this.tabInactiveBackground,
      tabActiveForeground: tabActiveForeground ?? this.tabActiveForeground,
      tabInactiveForeground:
          tabInactiveForeground ?? this.tabInactiveForeground,
      tabBorder: tabBorder ?? this.tabBorder,
      inputBackground: inputBackground ?? this.inputBackground,
      inputForeground: inputForeground ?? this.inputForeground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputPlaceholderForeground:
          inputPlaceholderForeground ?? this.inputPlaceholderForeground,
      dropdownBackground: dropdownBackground ?? this.dropdownBackground,
      buttonBackground: buttonBackground ?? this.buttonBackground,
      buttonForeground: buttonForeground ?? this.buttonForeground,
      buttonHoverBackground:
          buttonHoverBackground ?? this.buttonHoverBackground,
      foreground: foreground ?? this.foreground,
      descriptionForeground:
          descriptionForeground ?? this.descriptionForeground,
      accentForeground: accentForeground ?? this.accentForeground,
      errorForeground: errorForeground ?? this.errorForeground,
      warningForeground: warningForeground ?? this.warningForeground,
      successForeground: successForeground ?? this.successForeground,
      infoForeground: infoForeground ?? this.infoForeground,
      listHoverBackground: listHoverBackground ?? this.listHoverBackground,
      listActiveSelectionBackground:
          listActiveSelectionBackground ?? this.listActiveSelectionBackground,
      focusBorder: focusBorder ?? this.focusBorder,
      sashHoverBackground: sashHoverBackground ?? this.sashHoverBackground,
      menuBarBackground: menuBarBackground ?? this.menuBarBackground,
      menuBarForeground: menuBarForeground ?? this.menuBarForeground,
      menuBarHoverBackground:
          menuBarHoverBackground ?? this.menuBarHoverBackground,
      menuBarBorder: menuBarBorder ?? this.menuBarBorder,
      focusBorderSubtle: focusBorderSubtle ?? this.focusBorderSubtle,
      focusBorderMuted: focusBorderMuted ?? this.focusBorderMuted,
      focusBorderProminent: focusBorderProminent ?? this.focusBorderProminent,
      descriptionBadgeBackground:
          descriptionBadgeBackground ?? this.descriptionBadgeBackground,
      descriptionDisabledBackground:
          descriptionDisabledBackground ?? this.descriptionDisabledBackground,
      descriptionMuted: descriptionMuted ?? this.descriptionMuted,
      descriptionSecondary: descriptionSecondary ?? this.descriptionSecondary,
      errorBorderMuted: errorBorderMuted ?? this.errorBorderMuted,
      warningBackgroundSubtle:
          warningBackgroundSubtle ?? this.warningBackgroundSubtle,
      warningBorderMuted: warningBorderMuted ?? this.warningBorderMuted,
      infoBackgroundSubtle: infoBackgroundSubtle ?? this.infoBackgroundSubtle,
      infoBorderMuted: infoBorderMuted ?? this.infoBorderMuted,
      successBackgroundSubtle:
          successBackgroundSubtle ?? this.successBackgroundSubtle,
      successBorderMuted: successBorderMuted ?? this.successBorderMuted,
      sideBarBackgroundSubtle:
          sideBarBackgroundSubtle ?? this.sideBarBackgroundSubtle,
      sideBarBackgroundMuted:
          sideBarBackgroundMuted ?? this.sideBarBackgroundMuted,
      editorBackgroundOverlay:
          editorBackgroundOverlay ?? this.editorBackgroundOverlay,
      fontFamily: fontFamily ?? this.fontFamily,
      tabBarLabelColor: tabBarLabelColor ?? this.tabBarLabelColor,
      tabBarUnselectedLabelColor:
          tabBarUnselectedLabelColor ?? this.tabBarUnselectedLabelColor,
      tabBarIndicatorColor: tabBarIndicatorColor ?? this.tabBarIndicatorColor,
      tabBarDividerColor: tabBarDividerColor ?? this.tabBarDividerColor,
      sectionTitleStyle: sectionTitleStyle ?? this.sectionTitleStyle,
      subsectionTitleStyle: subsectionTitleStyle ?? this.subsectionTitleStyle,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      helperStyle: helperStyle ?? this.helperStyle,
      borderColor: borderColor ?? this.borderColor,
      focusBorderColor: focusBorderColor ?? this.focusBorderColor,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      labelText: labelText ?? this.labelText,
      bodyText: bodyText ?? this.bodyText,
      captionText: captionText ?? this.captionText,
      smallText: smallText ?? this.smallText,
      buttonTextStyle: buttonTextStyle ?? this.buttonTextStyle,
      statusText: statusText ?? this.statusText,
      statusBarTextStyle: statusBarTextStyle ?? this.statusBarTextStyle,
      valueText: valueText ?? this.valueText,
      sidebarOrPanelHeading:
          sidebarOrPanelHeading ?? this.sidebarOrPanelHeading,
      loglineTime: loglineTime ?? this.loglineTime,
      loglineName: loglineName ?? this.loglineName,
      loglineLevel: loglineLevel ?? this.loglineLevel,
      loglineMessage: loglineMessage ?? this.loglineMessage,
      tokenTheme: tokenTheme ?? this.tokenTheme,
      surfaceTone: surfaceTone ?? this.surfaceTone,
    );
  }

  @override
  WorkbenchTheme lerp(covariant WorkbenchTheme? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    // Nullable lerp: null endpoints interpolate through transparent so
    // an animated swap from a null border to a concrete one fades in
    // instead of snapping.
    Color? cn(Color? a, Color? b) {
      if (a == null && b == null) return null;
      return Color.lerp(a, b, t);
    }

    TextStyle ts(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return WorkbenchTheme(
      activityBarBackground: c(
        activityBarBackground,
        other.activityBarBackground,
      ),
      activityBarBorder: cn(activityBarBorder, other.activityBarBorder),
      activityBarForeground: c(
        activityBarForeground,
        other.activityBarForeground,
      ),
      activityBarInactiveForeground: c(
        activityBarInactiveForeground,
        other.activityBarInactiveForeground,
      ),
      sideBarBackground: c(sideBarBackground, other.sideBarBackground),
      sideBarBorder: cn(sideBarBorder, other.sideBarBorder),
      sideBarForeground: c(sideBarForeground, other.sideBarForeground),
      editorBackground: c(editorBackground, other.editorBackground),
      panelBackground: c(panelBackground, other.panelBackground),
      panelBorder: cn(panelBorder, other.panelBorder),
      panelTitleActiveForeground: c(
        panelTitleActiveForeground,
        other.panelTitleActiveForeground,
      ),
      panelTitleInactiveForeground: c(
        panelTitleInactiveForeground,
        other.panelTitleInactiveForeground,
      ),
      statusBarBackground: c(statusBarBackground, other.statusBarBackground),
      statusBarBorder: c(statusBarBorder, other.statusBarBorder),
      statusBarForeground: c(statusBarForeground, other.statusBarForeground),
      tabActiveBackground: c(tabActiveBackground, other.tabActiveBackground),
      tabInactiveBackground: c(
        tabInactiveBackground,
        other.tabInactiveBackground,
      ),
      tabActiveForeground: c(tabActiveForeground, other.tabActiveForeground),
      tabInactiveForeground: c(
        tabInactiveForeground,
        other.tabInactiveForeground,
      ),
      tabBorder: c(tabBorder, other.tabBorder),
      inputBackground: c(inputBackground, other.inputBackground),
      inputForeground: c(inputForeground, other.inputForeground),
      inputBorder: c(inputBorder, other.inputBorder),
      inputPlaceholderForeground: c(
        inputPlaceholderForeground,
        other.inputPlaceholderForeground,
      ),
      dropdownBackground: c(dropdownBackground, other.dropdownBackground),
      buttonBackground: c(buttonBackground, other.buttonBackground),
      buttonForeground: c(buttonForeground, other.buttonForeground),
      buttonHoverBackground: c(
        buttonHoverBackground,
        other.buttonHoverBackground,
      ),
      foreground: c(foreground, other.foreground),
      descriptionForeground: c(
        descriptionForeground,
        other.descriptionForeground,
      ),
      accentForeground: c(accentForeground, other.accentForeground),
      errorForeground: c(errorForeground, other.errorForeground),
      warningForeground: c(warningForeground, other.warningForeground),
      successForeground: c(successForeground, other.successForeground),
      infoForeground: c(infoForeground, other.infoForeground),
      listHoverBackground: c(listHoverBackground, other.listHoverBackground),
      listActiveSelectionBackground: c(
        listActiveSelectionBackground,
        other.listActiveSelectionBackground,
      ),
      focusBorder: c(focusBorder, other.focusBorder),
      sashHoverBackground: c(sashHoverBackground, other.sashHoverBackground),
      menuBarBackground: c(menuBarBackground, other.menuBarBackground),
      menuBarForeground: c(menuBarForeground, other.menuBarForeground),
      menuBarHoverBackground: c(
        menuBarHoverBackground,
        other.menuBarHoverBackground,
      ),
      menuBarBorder: c(menuBarBorder, other.menuBarBorder),
      focusBorderSubtle: c(focusBorderSubtle, other.focusBorderSubtle),
      focusBorderMuted: c(focusBorderMuted, other.focusBorderMuted),
      focusBorderProminent: c(focusBorderProminent, other.focusBorderProminent),
      descriptionBadgeBackground: c(
        descriptionBadgeBackground,
        other.descriptionBadgeBackground,
      ),
      descriptionDisabledBackground: c(
        descriptionDisabledBackground,
        other.descriptionDisabledBackground,
      ),
      descriptionMuted: c(descriptionMuted, other.descriptionMuted),
      descriptionSecondary: c(descriptionSecondary, other.descriptionSecondary),
      errorBorderMuted: c(errorBorderMuted, other.errorBorderMuted),
      warningBackgroundSubtle: c(
        warningBackgroundSubtle,
        other.warningBackgroundSubtle,
      ),
      warningBorderMuted: c(warningBorderMuted, other.warningBorderMuted),
      infoBackgroundSubtle: c(infoBackgroundSubtle, other.infoBackgroundSubtle),
      infoBorderMuted: c(infoBorderMuted, other.infoBorderMuted),
      successBackgroundSubtle: c(
        successBackgroundSubtle,
        other.successBackgroundSubtle,
      ),
      successBorderMuted: c(successBorderMuted, other.successBorderMuted),
      sideBarBackgroundSubtle: c(
        sideBarBackgroundSubtle,
        other.sideBarBackgroundSubtle,
      ),
      sideBarBackgroundMuted: c(
        sideBarBackgroundMuted,
        other.sideBarBackgroundMuted,
      ),
      editorBackgroundOverlay: c(
        editorBackgroundOverlay,
        other.editorBackgroundOverlay,
      ),
      fontFamily: t < 0.5 ? fontFamily : other.fontFamily,
      tabBarLabelColor: c(tabBarLabelColor, other.tabBarLabelColor),
      tabBarUnselectedLabelColor: c(
        tabBarUnselectedLabelColor,
        other.tabBarUnselectedLabelColor,
      ),
      tabBarIndicatorColor: c(tabBarIndicatorColor, other.tabBarIndicatorColor),
      tabBarDividerColor: c(tabBarDividerColor, other.tabBarDividerColor),
      sectionTitleStyle: ts(sectionTitleStyle, other.sectionTitleStyle),
      subsectionTitleStyle: ts(
        subsectionTitleStyle,
        other.subsectionTitleStyle,
      ),
      bodyStyle: ts(bodyStyle, other.bodyStyle),
      helperStyle: ts(helperStyle, other.helperStyle),
      borderColor: cn(borderColor, other.borderColor),
      focusBorderColor: c(focusBorderColor, other.focusBorderColor),
      sectionTitle: ts(sectionTitle, other.sectionTitle),
      labelText: ts(labelText, other.labelText),
      bodyText: ts(bodyText, other.bodyText),
      captionText: ts(captionText, other.captionText),
      smallText: ts(smallText, other.smallText),
      buttonTextStyle: ts(buttonTextStyle, other.buttonTextStyle),
      statusText: ts(statusText, other.statusText),
      statusBarTextStyle: ts(statusBarTextStyle, other.statusBarTextStyle),
      valueText: ts(valueText, other.valueText),
      sidebarOrPanelHeading: ts(
        sidebarOrPanelHeading,
        other.sidebarOrPanelHeading,
      ),
      loglineTime: ts(loglineTime, other.loglineTime),
      loglineName: ts(loglineName, other.loglineName),
      loglineLevel: ts(loglineLevel, other.loglineLevel),
      loglineMessage: ts(loglineMessage, other.loglineMessage),
      tokenTheme: t < 0.5 ? tokenTheme : other.tokenTheme,
      surfaceTone: surfaceTone + (other.surfaceTone - surfaceTone) * t,
    );
  }
}

/// Convenience accessor for [WorkbenchTheme] from [BuildContext].
extension WorkbenchThemeExtension on BuildContext {
  /// The [WorkbenchTheme] from the nearest [Theme] ancestor.
  WorkbenchTheme get workbenchTheme =>
      Theme.of(this).extension<WorkbenchTheme>()!;
}

/// Helper for content-primitive widgets that need a concrete
/// [Color] regardless of whether the theme suppresses the chrome
/// panel border. When [WorkbenchTheme.panelBorder] is null the
/// helper falls through to [Colors.transparent] — content primitives
/// outside the workbench chrome still lay out identically, they
/// just render edgelessly.
extension WorkbenchThemeContentBorder on WorkbenchTheme {
  /// Non-null panel-border color, substituting transparent when the
  /// theme suppresses the border. Use from content-primitive widgets
  /// (jog controls, cards, sidebar chips) whose structural width must
  /// not change when the theme omits the border.
  Color get panelBorderOrTransparent => panelBorder ?? Colors.transparent;
}

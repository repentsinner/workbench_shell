import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import 'notifications/notification.dart';
import 'theming/token_theme.dart';
import 'theming/vscode_color_map.dart';

/// Color and typography tokens for workbench layout chrome and
/// content primitives.
///
/// Carries the tokens needed by the shell widgets (activity bar,
/// sidebar container, resizers, status bar container) plus the
/// content primitives ([WorkbenchViewPane], [WorkbenchCard], form
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
  /// similar themes set this explicitly. See SPEC
  /// §spec:vscode-theme-format (null and alpha token semantics).
  final Color? activityBarBorder;

  final Color activityBarForeground;
  final Color activityBarInactiveForeground;

  // ---- Sidebar ----
  final Color sideBarBackground;

  /// Sidebar right-edge separator. Null in modern themes whose VS
  /// Code registry default is null — see [activityBarBorder].
  final Color? sideBarBorder;

  final Color sideBarForeground;

  /// Section-header band fill for stacked view-pane headers. VS Code
  /// `sideBarSectionHeader.background`. Null when the theme omits the
  /// key — the header then paints no band (mirrors the nullable
  /// [sideBarBorder] / [activityBarBorder] handling). See SPEC
  /// §spec:view-stack.
  final Color? sideBarSectionHeaderBackground;

  /// Section-header top rule for stacked view-pane headers. VS Code
  /// `sideBarSectionHeader.border`. Null when the theme omits the key —
  /// the header then paints no rule. See SPEC §spec:view-stack.
  final Color? sideBarSectionHeaderBorder;

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

  /// Secondary-button fill. VS Code `button.secondaryBackground`,
  /// falling back to [listHoverBackground] (a neutral surface) when the
  /// theme omits it. Drives the §spec:chrome-material-theming [FilledButton.tonal] tier.
  final Color buttonSecondaryBackground;

  /// Secondary-button label. VS Code `button.secondaryForeground`,
  /// falling back to [foreground] when the theme omits it.
  final Color buttonSecondaryForeground;

  /// Button border. VS Code `button.border`, falling back to transparent
  /// when the theme omits it. Modern themes (Dark Modern, Dark 2026) give
  /// the secondary button a transparent `button.secondaryBackground` and
  /// rely on this border to make it visible at rest; older themes omit it
  /// and the secondary button is visible via its solid fill. Applied to
  /// both §spec:chrome-material-theming filled tiers.
  final Color buttonBorder;

  /// Active-toggle fill. VS Code `inputOption.activeBackground` (the
  /// find/search toggle "on" state), a subtle accent tint; falls back to a
  /// translucent [focusBorder] accent. Marks the selected segment of the
  /// §spec:chrome-material-theming jog `SegmentedButton`s — an *active* colour, distinct from the
  /// primary-action fill and from a dimmed-disabled segment.
  final Color inputOptionActiveBackground;

  /// Active-toggle border. VS Code `inputOption.activeBorder`, a solid
  /// accent; falls back to [focusBorder]. The prominent "selected" signal
  /// on the active segment, paired with [inputOptionActiveBackground].
  final Color inputOptionActiveBorder;

  // ---- Foreground / accent ----
  final Color foreground;
  final Color descriptionForeground;
  final Color accentForeground;

  /// Icon-button glyph color. VS Code `icon.foreground` — near-full
  /// contrast, deliberately distinct from [foreground] (body text) and
  /// [descriptionForeground] (secondary text). Drives bare `IconButton`s
  /// composed under the chrome (§spec:chrome-material-theming).
  final Color iconForeground;

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
  final Color sashHoverBorder;

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

  // ---- Pre-mixed opacity variants (semantic color modifiers, §spec:theming) ----
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

  // ---- Chrome font (§spec:chrome-typography-canon) ----
  //
  // Defaults to `null` so Flutter resolves the platform's default UI
  // sans (matching VS Code's `-apple-system` / `Segoe UI` / `system-ui`
  // rules in `src/vs/workbench/browser/media/style.css`). Hosts pass a
  // brand override (e.g. `'Inter'`) on
  // [WorkbenchTheme.fromVscodeColorMap]; the override flows through
  // every chrome semantic text style.
  final String? chromeFontFamily;

  // ---- Editor font (§spec:editor-derived-surfaces) ----
  //
  // Anchor for log-line and host numeric surfaces (DRO readouts,
  // tabular values). VS Code uses `editor.fontFamily` /
  // `editor.fontSize` for these surfaces and they default to a
  // per-platform monospace via `EDITOR_FONT_DEFAULTS` in
  // `src/vs/editor/common/config/fontInfo.ts`. Hosts override
  // [editorFontFamily] / [editorFontSize] on the factory; the
  // override flows through [editorStyle] to every editor-derived
  // token without per-call-site changes.
  final String editorFontFamily;
  final double editorFontSize;
  final TextStyle editorStyle;

  // ---- Tab strip chrome (consumed by WorkbenchTabbedPanel) ----
  final Color tabBarLabelColor;
  final Color tabBarUnselectedLabelColor;
  final Color tabBarIndicatorColor;
  final Color tabBarDividerColor;

  // ---- Badges (consumed by PanelTabBadge and any future shell badge
  // surface). VS Code's `badge.background` / `badge.foreground` are
  // a separate accent from the panel-tab underline — same colour in
  // some themes, different in others (Light Modern uses a saturated
  // blue badge against a near-black underline).
  final Color badgeBackground;
  final Color badgeForeground;

  // ---- Content primitive tokens (legacy slots retained for
  // back-compat with widgets that read them; see §spec:chrome-typography-canon table for the
  // canonical replacements). ----
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

  // ---- Semantic text styles (§spec:chrome-typography-canon) ----
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
  final TextStyle loglineMessage;

  // ---- Syntax token theme ----
  final TokenTheme tokenTheme;

  // ---- Notification center (§spec:notification-center) ----
  //
  // Severity icons and accents reuse [infoForeground],
  // [warningForeground], [errorForeground], and [successForeground]
  // — the existing semantic-status tokens. The fields below cover
  // the chrome that isn't already on the theme: card background,
  // close button colour, action-button styling, and progress bar
  // track / fill.
  //
  // VS Code surfaces these through the `notifications.*` colour
  // namespace; the fallback chain prefers those tokens when present
  // and falls back to neighbouring chrome tokens (input/list) so
  // older themes still render coherent cards.

  /// Card background. Falls back to [inputBackground] so cards read
  /// as elevated chrome against the editor surface even on themes
  /// that omit `notifications.background`.
  final Color notificationBackground;

  /// Card border colour. Falls back to [panelBorder] (which itself
  /// defaults to translucent grey).
  final Color notificationBorder;

  /// Card foreground (message text). Falls back to [foreground].
  final Color notificationForeground;

  /// Close-button glyph colour. Falls back to [descriptionForeground]
  /// so the affordance reads as secondary chrome.
  final Color notificationCloseForeground;

  /// Action-button background. Falls back to [buttonBackground].
  final Color notificationActionBackground;

  /// Action-button foreground. Falls back to [buttonForeground].
  final Color notificationActionForeground;

  /// Action-button hover background. Falls back to
  /// [buttonHoverBackground].
  final Color notificationActionHoverBackground;

  /// Progress bar track (background of the bar). Falls back to a
  /// 30 %-alpha modulation of [notificationBorder] so the track
  /// reads as a recessed channel.
  final Color notificationProgressTrack;

  /// Progress bar fill (foreground of the bar). Falls back to
  /// [focusBorder] — the same accent the rest of the chrome uses
  /// for in-progress emphasis.
  final Color notificationProgressFill;

  // ---- Domain color resolver input (§spec:hct-tonal-resolution) ----
  /// HCT tone (0–100) of the canonical chrome surface ([editorBackground]).
  ///
  /// A host's domain theme reads this to pick a tone from a tonal
  /// palette that contrasts the active chrome. Dark
  /// chrome (low tone) selects high palette tones; light chrome
  /// selects low palette tones. See SPEC §spec:hct-tonal-resolution.
  final double surfaceTone;

  const WorkbenchTheme({
    required this.activityBarBackground,
    required this.activityBarBorder,
    required this.activityBarForeground,
    required this.activityBarInactiveForeground,
    required this.sideBarBackground,
    required this.sideBarBorder,
    required this.sideBarForeground,
    required this.sideBarSectionHeaderBackground,
    required this.sideBarSectionHeaderBorder,
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
    required this.buttonSecondaryBackground,
    required this.buttonSecondaryForeground,
    required this.buttonBorder,
    required this.inputOptionActiveBackground,
    required this.inputOptionActiveBorder,
    required this.foreground,
    required this.descriptionForeground,
    required this.accentForeground,
    required this.iconForeground,
    required this.errorForeground,
    required this.warningForeground,
    required this.successForeground,
    required this.infoForeground,
    required this.listHoverBackground,
    required this.listActiveSelectionBackground,
    required this.focusBorder,
    required this.sashHoverBorder,
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
    required this.chromeFontFamily,
    required this.editorFontFamily,
    required this.editorFontSize,
    required this.editorStyle,
    required this.tabBarLabelColor,
    required this.tabBarUnselectedLabelColor,
    required this.tabBarIndicatorColor,
    required this.tabBarDividerColor,
    required this.badgeBackground,
    required this.badgeForeground,
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
    required this.loglineMessage,
    required this.tokenTheme,
    required this.notificationBackground,
    required this.notificationBorder,
    required this.notificationForeground,
    required this.notificationCloseForeground,
    required this.notificationActionBackground,
    required this.notificationActionForeground,
    required this.notificationActionHoverBackground,
    required this.notificationProgressTrack,
    required this.notificationProgressFill,
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
  /// that omit tokens still produce a valid workbench theme.
  ///
  /// [chromeFontFamily] overrides the default platform UI sans used
  /// across chrome semantic text styles (sidebar headings, panel tab
  /// labels, status bar items, body text, buttons). Null delegates to
  /// Flutter's platform-default UI font, matching VS Code's
  /// `-apple-system` / `Segoe UI` / `system-ui` resolution rules
  /// (§spec:chrome-typography-canon).
  ///
  /// [editorFontFamily] overrides the per-platform monospace used by
  /// editor-derived surfaces ([editorStyle], [loglineMessage],
  /// [valueText]). Null resolves to VS Code's `EDITOR_FONT_DEFAULTS`
  /// primary family per host platform (§spec:editor-derived-surfaces).
  ///
  /// [editorFontSize] overrides the editor font size. Null resolves
  /// to VS Code's per-platform default (12 on macOS, 14 elsewhere).
  factory WorkbenchTheme.fromVscodeColorMap(
    VscodeColorMap map, {
    String? chromeFontFamily,
    String? editorFontFamily,
    double? editorFontSize,
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
    // Shared so [listHoverBackground] and the §spec:chrome-material-theming
    // [buttonSecondaryBackground] fallback resolve from one value
    // (VS Code: button.secondaryBackground defaults to list.hoverBackground).
    final listHoverBg = map.resolve(
      'list.hoverBackground',
      dl(const Color(0xFF2A2D2E), const Color(0xFFF0F0F0)),
    );

    // Chrome typography: chrome surfaces honour [chromeFontFamily]
    // (null → platform UI sans). The local helper carries the chrome
    // family so a single decision propagates across every chrome
    // token literal in the factory body.
    TextStyle t(double size, FontWeight weight, {Color? color}) => TextStyle(
      fontFamily: chromeFontFamily,
      color: color ?? fg,
      fontSize: size,
      fontWeight: weight,
    );

    // Editor typography: resolve [editorFontFamily] / [editorFontSize]
    // against VS Code's EDITOR_FONT_DEFAULTS table when the host
    // hasn't overridden either. Tokens whose role is editor-derived
    // monospace (loglineMessage, valueText) derive from [editorStyle]
    // via [TextStyle.copyWith] so the family resolution lives in one
    // place (§spec:editor-derived-surfaces).
    final resolvedEditorFamily =
        editorFontFamily ?? _platformEditorFontFamily();
    final resolvedEditorSize = editorFontSize ?? _platformEditorFontSize();
    final editorStyle = TextStyle(
      fontFamily: resolvedEditorFamily,
      color: fg,
      fontSize: resolvedEditorSize,
      fontWeight: FontWeight.w400,
    );

    return WorkbenchTheme(
      // Activity bar
      activityBarBackground: map.resolve(
        'activityBar.background',
        dl(const Color(0xFF333333), const Color(0xFF2C2C2C)),
      ),
      // Null when the theme omits it — VS Code's ACTIVITY_BAR_BORDER
      // registry default is null in dark/light themes. Widgets skip
      // painting the separator when null (see SPEC §spec:vscode-theme-format).
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
      // Section-header band + rule for stacked view panes (§spec:view-stack).
      // Null by the same registry semantics as sideBar.border — a theme
      // that omits the key suppresses the corresponding paint.
      sideBarSectionHeaderBackground: map['sideBarSectionHeader.background'],
      sideBarSectionHeaderBorder: map['sideBarSectionHeader.border'],
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
      // §spec:chrome-material-theming secondary tier. VS Code registry: secondaryBackground
      // defaults to list.hoverBackground, secondaryForeground to foreground.
      buttonSecondaryBackground: map.resolve(
        'button.secondaryBackground',
        listHoverBg,
      ),
      buttonSecondaryForeground: map.resolve('button.secondaryForeground', fg),
      // §spec:chrome-material-theming button border. VS Code has no registry default — themes opt
      // in; transparent when absent, so older themes draw no border.
      buttonBorder: map.resolve('button.border', const Color(0x00000000)),
      // §spec:chrome-material-theming active-toggle (SegmentedButton selected segment). VS Code's
      // find/search toggle "on" state: a subtle accent tint plus a solid
      // accent border. Fall back to a translucent / solid focusBorder
      // accent when the theme omits them.
      inputOptionActiveBackground: map.resolve(
        'inputOption.activeBackground',
        accentFg.withValues(alpha: 0.25),
      ),
      inputOptionActiveBorder: map.resolve(
        'inputOption.activeBorder',
        accentFg,
      ),
      // Foregrounds / accent
      foreground: fg,
      descriptionForeground: secondaryFg,
      accentForeground: map.resolve(
        'textLink.foreground',
        const Color(0xFF569CD6),
      ),
      iconForeground: map.resolve(
        'icon.foreground',
        dl(const Color(0xFFC5C5C5), const Color(0xFF424242)),
      ),
      // Semantic status
      errorForeground: errorFg,
      warningForeground: warningFg,
      successForeground: successFg,
      infoForeground: infoFg,
      // List
      listHoverBackground: listHoverBg,
      listActiveSelectionBackground: map.resolve(
        'list.activeSelectionBackground',
        dl(const Color(0xFF04395E), const Color(0xFF0060C0)),
      ),
      // Focus / sash
      focusBorder: accentFg,
      sashHoverBorder: map.resolve('sash.hoverBorder', accentFg),
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
      chromeFontFamily: chromeFontFamily,
      editorFontFamily: resolvedEditorFamily,
      editorFontSize: resolvedEditorSize,
      editorStyle: editorStyle,
      tabBarLabelColor: map.resolve('panelTitle.activeForeground', fg),
      tabBarUnselectedLabelColor: map.resolve(
        'panelTitle.inactiveForeground',
        secondaryFg,
      ),
      tabBarIndicatorColor: map.resolve('panelTitle.activeBorder', fg),
      tabBarDividerColor: const Color(0x00000000),
      // Badge accent (panel-tab count, future shell badge surfaces).
      //
      // Fallback chain when the theme JSON omits `badge.background`:
      //   1. `activityBarBadge.background` — most VS Code themes
      //      define this even when they leave `badge.background`
      //      unset; it's the same accent in practice. Dark+ and
      //      Light+ both rely on this path (they only define the
      //      activity-bar form).
      //   2. VS Code's vs-dark / vs base-theme default
      //      (`#4D4D4D` / `#C4C4C4`) — what VS Code itself paints
      //      when nothing in the theme registry defines the badge.
      //
      // Falling back to `panelTitle.activeBorder` was wrong: in
      // Dark+ (where neither `badge.background` nor
      // `panelTitle.activeBorder` is defined) the chain bottomed out
      // at `fg` (white-ish) and the badge text washed out against
      // its own background.
      badgeBackground: map.resolve(
        'badge.background',
        map.resolve(
          'activityBarBadge.background',
          dl(const Color(0xFF4D4D4D), const Color(0xFFC4C4C4)),
        ),
      ),
      badgeForeground: map.resolve(
        'badge.foreground',
        map.resolve('activityBarBadge.foreground', const Color(0xFFFFFFFF)),
      ),
      // Legacy content-primitive tokens (kept for widgets that read
      // them; canonical replacements live in the §spec:chrome-typography-canon block below).
      subsectionTitleStyle: t(12, FontWeight.w500),
      bodyStyle: t(12, FontWeight.w400),
      borderColor: panelBorder,
      focusBorderColor: accentFg,
      // Chrome typography canon (§spec:chrome-typography-canon) — every literal is sourced
      // from VS Code's workbench CSS. See SPEC §spec:chrome-typography-canon table for the
      // upstream file and selector per token.
      //
      // sidebar / panel part title ("EXPLORER", "SETTINGS") —
      // part.css `.title-label h2`.
      sidebarOrPanelHeading: t(11, FontWeight.w400),
      // pane header / WorkbenchViewPane title — paneview.css
      // `.pane-header` (11 / bold / uppercase). The uppercase
      // transform lives in WorkbenchViewPane's rendering, not the
      // token literal.
      sectionTitle: t(11, FontWeight.w700),
      // workbench body content — part.css `.part > .content`.
      bodyText: t(13, FontWeight.w400),
      // settings label / form label — settingsEditor2.css
      // `.setting-item-category`.
      labelText: t(13, FontWeight.w500),
      // status bar item — statusbarpart.css. Same metrics as
      // [helperStyle]; paints in [statusBarForeground] so the text
      // reads against the blue status bar background.
      statusText: t(12, FontWeight.w400),
      statusBarTextStyle: t(12, FontWeight.w400, color: statusBarFg),
      // button (default) — button.css.
      buttonTextStyle: TextStyle(
        fontFamily: chromeFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      // description / caption — inherits body, painted in
      // descriptionForeground (12 / w400).
      captionText: t(12, FontWeight.w400, color: secondaryFg),
      helperStyle: t(12, FontWeight.w400, color: secondaryFg),
      // badge tier — paneCompositeBar.css (11 / w600). Internal
      // token the panel-tab badge pill paints in and the host
      // analogue for dense numeric indicators.
      smallText: t(11, FontWeight.w600, color: secondaryFg),
      // Editor-derived surfaces (§spec:editor-derived-surfaces) — DRO numerics and log lines
      // anchor on [editorStyle] so the host's editor-font override
      // flows through without per-call-site changes. DRO retains
      // w600 for tabular numeric emphasis; log lines stay at w400.
      valueText: editorStyle.copyWith(fontWeight: FontWeight.w600),
      loglineMessage: editorStyle,
      // Syntax token theme
      tokenTheme: map.resolvedTokenTheme,
      // Notification center (§spec:notification-center) — VS Code surfaces these through
      // `notifications.*`; fall back to neighbouring chrome tokens
      // when absent so older themes still render coherent cards.
      notificationBackground: map.resolve(
        'notifications.background',
        map.resolve(
          'input.background',
          dl(const Color(0xFF3C3C3C), const Color(0xFFFFFFFF)),
        ),
      ),
      notificationBorder: map.resolve('notifications.border', panelBorder),
      notificationForeground: map.resolve('notifications.foreground', fg),
      notificationCloseForeground: map.resolve(
        'notificationCenter.foreground',
        secondaryFg,
      ),
      notificationActionBackground: map.resolve(
        'notificationCenterHeader.background',
        map.resolve(
          'button.background',
          dl(const Color(0xFF0E639C), const Color(0xFF007ACC)),
        ),
      ),
      notificationActionForeground: map.resolve(
        'button.foreground',
        const Color(0xFFFFFFFF),
      ),
      notificationActionHoverBackground: map.resolve(
        'button.hoverBackground',
        dl(const Color(0xFF1177BB), const Color(0xFF0062A3)),
      ),
      notificationProgressTrack: map
          .resolve('notifications.border', panelBorder)
          .withValues(alpha: 0.3),
      notificationProgressFill: map.resolve('progressBar.background', accentFg),
      // HCT tone of the canonical chrome surface (editor background).
      // A host's domain theme reads this to pick contrasting palette
      // tones — see SPEC §spec:hct-tonal-resolution.
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
    Color? sideBarSectionHeaderBackground,
    Color? sideBarSectionHeaderBorder,
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
    Color? buttonSecondaryBackground,
    Color? buttonSecondaryForeground,
    Color? buttonBorder,
    Color? inputOptionActiveBackground,
    Color? inputOptionActiveBorder,
    Color? foreground,
    Color? descriptionForeground,
    Color? accentForeground,
    Color? iconForeground,
    Color? errorForeground,
    Color? warningForeground,
    Color? successForeground,
    Color? infoForeground,
    Color? listHoverBackground,
    Color? listActiveSelectionBackground,
    Color? focusBorder,
    Color? sashHoverBorder,
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
    String? chromeFontFamily,
    String? editorFontFamily,
    double? editorFontSize,
    TextStyle? editorStyle,
    Color? tabBarLabelColor,
    Color? tabBarUnselectedLabelColor,
    Color? tabBarIndicatorColor,
    Color? tabBarDividerColor,
    Color? badgeBackground,
    Color? badgeForeground,
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
    TextStyle? loglineMessage,
    TokenTheme? tokenTheme,
    Color? notificationBackground,
    Color? notificationBorder,
    Color? notificationForeground,
    Color? notificationCloseForeground,
    Color? notificationActionBackground,
    Color? notificationActionForeground,
    Color? notificationActionHoverBackground,
    Color? notificationProgressTrack,
    Color? notificationProgressFill,
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
      sideBarSectionHeaderBackground:
          sideBarSectionHeaderBackground ?? this.sideBarSectionHeaderBackground,
      sideBarSectionHeaderBorder:
          sideBarSectionHeaderBorder ?? this.sideBarSectionHeaderBorder,
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
      buttonSecondaryBackground:
          buttonSecondaryBackground ?? this.buttonSecondaryBackground,
      buttonSecondaryForeground:
          buttonSecondaryForeground ?? this.buttonSecondaryForeground,
      buttonBorder: buttonBorder ?? this.buttonBorder,
      inputOptionActiveBackground:
          inputOptionActiveBackground ?? this.inputOptionActiveBackground,
      inputOptionActiveBorder:
          inputOptionActiveBorder ?? this.inputOptionActiveBorder,
      foreground: foreground ?? this.foreground,
      descriptionForeground:
          descriptionForeground ?? this.descriptionForeground,
      accentForeground: accentForeground ?? this.accentForeground,
      iconForeground: iconForeground ?? this.iconForeground,
      errorForeground: errorForeground ?? this.errorForeground,
      warningForeground: warningForeground ?? this.warningForeground,
      successForeground: successForeground ?? this.successForeground,
      infoForeground: infoForeground ?? this.infoForeground,
      listHoverBackground: listHoverBackground ?? this.listHoverBackground,
      listActiveSelectionBackground:
          listActiveSelectionBackground ?? this.listActiveSelectionBackground,
      focusBorder: focusBorder ?? this.focusBorder,
      sashHoverBorder: sashHoverBorder ?? this.sashHoverBorder,
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
      chromeFontFamily: chromeFontFamily ?? this.chromeFontFamily,
      editorFontFamily: editorFontFamily ?? this.editorFontFamily,
      editorFontSize: editorFontSize ?? this.editorFontSize,
      editorStyle: editorStyle ?? this.editorStyle,
      tabBarLabelColor: tabBarLabelColor ?? this.tabBarLabelColor,
      tabBarUnselectedLabelColor:
          tabBarUnselectedLabelColor ?? this.tabBarUnselectedLabelColor,
      tabBarIndicatorColor: tabBarIndicatorColor ?? this.tabBarIndicatorColor,
      tabBarDividerColor: tabBarDividerColor ?? this.tabBarDividerColor,
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeForeground: badgeForeground ?? this.badgeForeground,
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
      loglineMessage: loglineMessage ?? this.loglineMessage,
      tokenTheme: tokenTheme ?? this.tokenTheme,
      notificationBackground:
          notificationBackground ?? this.notificationBackground,
      notificationBorder: notificationBorder ?? this.notificationBorder,
      notificationForeground:
          notificationForeground ?? this.notificationForeground,
      notificationCloseForeground:
          notificationCloseForeground ?? this.notificationCloseForeground,
      notificationActionBackground:
          notificationActionBackground ?? this.notificationActionBackground,
      notificationActionForeground:
          notificationActionForeground ?? this.notificationActionForeground,
      notificationActionHoverBackground:
          notificationActionHoverBackground ??
          this.notificationActionHoverBackground,
      notificationProgressTrack:
          notificationProgressTrack ?? this.notificationProgressTrack,
      notificationProgressFill:
          notificationProgressFill ?? this.notificationProgressFill,
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
      sideBarSectionHeaderBackground: cn(
        sideBarSectionHeaderBackground,
        other.sideBarSectionHeaderBackground,
      ),
      sideBarSectionHeaderBorder: cn(
        sideBarSectionHeaderBorder,
        other.sideBarSectionHeaderBorder,
      ),
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
      buttonSecondaryBackground: c(
        buttonSecondaryBackground,
        other.buttonSecondaryBackground,
      ),
      buttonSecondaryForeground: c(
        buttonSecondaryForeground,
        other.buttonSecondaryForeground,
      ),
      buttonBorder: c(buttonBorder, other.buttonBorder),
      inputOptionActiveBackground: c(
        inputOptionActiveBackground,
        other.inputOptionActiveBackground,
      ),
      inputOptionActiveBorder: c(
        inputOptionActiveBorder,
        other.inputOptionActiveBorder,
      ),
      foreground: c(foreground, other.foreground),
      descriptionForeground: c(
        descriptionForeground,
        other.descriptionForeground,
      ),
      accentForeground: c(accentForeground, other.accentForeground),
      iconForeground: c(iconForeground, other.iconForeground),
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
      sashHoverBorder: c(sashHoverBorder, other.sashHoverBorder),
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
      chromeFontFamily: t < 0.5 ? chromeFontFamily : other.chromeFontFamily,
      editorFontFamily: t < 0.5 ? editorFontFamily : other.editorFontFamily,
      editorFontSize:
          editorFontSize + (other.editorFontSize - editorFontSize) * t,
      editorStyle: ts(editorStyle, other.editorStyle),
      tabBarLabelColor: c(tabBarLabelColor, other.tabBarLabelColor),
      tabBarUnselectedLabelColor: c(
        tabBarUnselectedLabelColor,
        other.tabBarUnselectedLabelColor,
      ),
      tabBarIndicatorColor: c(tabBarIndicatorColor, other.tabBarIndicatorColor),
      tabBarDividerColor: c(tabBarDividerColor, other.tabBarDividerColor),
      badgeBackground: c(badgeBackground, other.badgeBackground),
      badgeForeground: c(badgeForeground, other.badgeForeground),
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
      loglineMessage: ts(loglineMessage, other.loglineMessage),
      tokenTheme: t < 0.5 ? tokenTheme : other.tokenTheme,
      notificationBackground: c(
        notificationBackground,
        other.notificationBackground,
      ),
      notificationBorder: c(notificationBorder, other.notificationBorder),
      notificationForeground: c(
        notificationForeground,
        other.notificationForeground,
      ),
      notificationCloseForeground: c(
        notificationCloseForeground,
        other.notificationCloseForeground,
      ),
      notificationActionBackground: c(
        notificationActionBackground,
        other.notificationActionBackground,
      ),
      notificationActionForeground: c(
        notificationActionForeground,
        other.notificationActionForeground,
      ),
      notificationActionHoverBackground: c(
        notificationActionHoverBackground,
        other.notificationActionHoverBackground,
      ),
      notificationProgressTrack: c(
        notificationProgressTrack,
        other.notificationProgressTrack,
      ),
      notificationProgressFill: c(
        notificationProgressFill,
        other.notificationProgressFill,
      ),
      surfaceTone: surfaceTone + (other.surfaceTone - surfaceTone) * t,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbenchTheme &&
          activityBarBackground == other.activityBarBackground &&
          activityBarBorder == other.activityBarBorder &&
          activityBarForeground == other.activityBarForeground &&
          activityBarInactiveForeground ==
              other.activityBarInactiveForeground &&
          sideBarBackground == other.sideBarBackground &&
          sideBarBorder == other.sideBarBorder &&
          sideBarForeground == other.sideBarForeground &&
          sideBarSectionHeaderBackground ==
              other.sideBarSectionHeaderBackground &&
          sideBarSectionHeaderBorder == other.sideBarSectionHeaderBorder &&
          editorBackground == other.editorBackground &&
          panelBackground == other.panelBackground &&
          panelBorder == other.panelBorder &&
          panelTitleActiveForeground == other.panelTitleActiveForeground &&
          panelTitleInactiveForeground == other.panelTitleInactiveForeground &&
          statusBarBackground == other.statusBarBackground &&
          statusBarBorder == other.statusBarBorder &&
          statusBarForeground == other.statusBarForeground &&
          tabActiveBackground == other.tabActiveBackground &&
          tabInactiveBackground == other.tabInactiveBackground &&
          tabActiveForeground == other.tabActiveForeground &&
          tabInactiveForeground == other.tabInactiveForeground &&
          tabBorder == other.tabBorder &&
          inputBackground == other.inputBackground &&
          inputForeground == other.inputForeground &&
          inputBorder == other.inputBorder &&
          inputPlaceholderForeground == other.inputPlaceholderForeground &&
          dropdownBackground == other.dropdownBackground &&
          buttonBackground == other.buttonBackground &&
          buttonForeground == other.buttonForeground &&
          buttonHoverBackground == other.buttonHoverBackground &&
          buttonSecondaryBackground == other.buttonSecondaryBackground &&
          buttonSecondaryForeground == other.buttonSecondaryForeground &&
          buttonBorder == other.buttonBorder &&
          inputOptionActiveBackground == other.inputOptionActiveBackground &&
          inputOptionActiveBorder == other.inputOptionActiveBorder &&
          foreground == other.foreground &&
          descriptionForeground == other.descriptionForeground &&
          accentForeground == other.accentForeground &&
          iconForeground == other.iconForeground &&
          errorForeground == other.errorForeground &&
          warningForeground == other.warningForeground &&
          successForeground == other.successForeground &&
          infoForeground == other.infoForeground &&
          listHoverBackground == other.listHoverBackground &&
          listActiveSelectionBackground ==
              other.listActiveSelectionBackground &&
          focusBorder == other.focusBorder &&
          sashHoverBorder == other.sashHoverBorder &&
          menuBarBackground == other.menuBarBackground &&
          menuBarForeground == other.menuBarForeground &&
          menuBarHoverBackground == other.menuBarHoverBackground &&
          menuBarBorder == other.menuBarBorder &&
          focusBorderSubtle == other.focusBorderSubtle &&
          focusBorderMuted == other.focusBorderMuted &&
          focusBorderProminent == other.focusBorderProminent &&
          descriptionBadgeBackground == other.descriptionBadgeBackground &&
          descriptionDisabledBackground ==
              other.descriptionDisabledBackground &&
          descriptionMuted == other.descriptionMuted &&
          descriptionSecondary == other.descriptionSecondary &&
          errorBorderMuted == other.errorBorderMuted &&
          warningBackgroundSubtle == other.warningBackgroundSubtle &&
          warningBorderMuted == other.warningBorderMuted &&
          infoBackgroundSubtle == other.infoBackgroundSubtle &&
          infoBorderMuted == other.infoBorderMuted &&
          successBackgroundSubtle == other.successBackgroundSubtle &&
          successBorderMuted == other.successBorderMuted &&
          sideBarBackgroundSubtle == other.sideBarBackgroundSubtle &&
          sideBarBackgroundMuted == other.sideBarBackgroundMuted &&
          editorBackgroundOverlay == other.editorBackgroundOverlay &&
          chromeFontFamily == other.chromeFontFamily &&
          editorFontFamily == other.editorFontFamily &&
          editorFontSize == other.editorFontSize &&
          editorStyle == other.editorStyle &&
          tabBarLabelColor == other.tabBarLabelColor &&
          tabBarUnselectedLabelColor == other.tabBarUnselectedLabelColor &&
          tabBarIndicatorColor == other.tabBarIndicatorColor &&
          tabBarDividerColor == other.tabBarDividerColor &&
          badgeBackground == other.badgeBackground &&
          badgeForeground == other.badgeForeground &&
          subsectionTitleStyle == other.subsectionTitleStyle &&
          bodyStyle == other.bodyStyle &&
          helperStyle == other.helperStyle &&
          borderColor == other.borderColor &&
          focusBorderColor == other.focusBorderColor &&
          sectionTitle == other.sectionTitle &&
          labelText == other.labelText &&
          bodyText == other.bodyText &&
          captionText == other.captionText &&
          smallText == other.smallText &&
          buttonTextStyle == other.buttonTextStyle &&
          statusText == other.statusText &&
          statusBarTextStyle == other.statusBarTextStyle &&
          valueText == other.valueText &&
          sidebarOrPanelHeading == other.sidebarOrPanelHeading &&
          loglineMessage == other.loglineMessage &&
          tokenTheme == other.tokenTheme &&
          notificationBackground == other.notificationBackground &&
          notificationBorder == other.notificationBorder &&
          notificationForeground == other.notificationForeground &&
          notificationCloseForeground == other.notificationCloseForeground &&
          notificationActionBackground == other.notificationActionBackground &&
          notificationActionForeground == other.notificationActionForeground &&
          notificationActionHoverBackground ==
              other.notificationActionHoverBackground &&
          notificationProgressTrack == other.notificationProgressTrack &&
          notificationProgressFill == other.notificationProgressFill &&
          surfaceTone == other.surfaceTone;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    activityBarBackground,
    activityBarBorder,
    activityBarForeground,
    activityBarInactiveForeground,
    sideBarBackground,
    sideBarBorder,
    sideBarForeground,
    sideBarSectionHeaderBackground,
    sideBarSectionHeaderBorder,
    editorBackground,
    panelBackground,
    panelBorder,
    panelTitleActiveForeground,
    panelTitleInactiveForeground,
    statusBarBackground,
    statusBarBorder,
    statusBarForeground,
    tabActiveBackground,
    tabInactiveBackground,
    tabActiveForeground,
    tabInactiveForeground,
    tabBorder,
    inputBackground,
    inputForeground,
    inputBorder,
    inputPlaceholderForeground,
    dropdownBackground,
    buttonBackground,
    buttonForeground,
    buttonHoverBackground,
    buttonSecondaryBackground,
    buttonSecondaryForeground,
    buttonBorder,
    inputOptionActiveBackground,
    inputOptionActiveBorder,
    foreground,
    descriptionForeground,
    accentForeground,
    iconForeground,
    errorForeground,
    warningForeground,
    successForeground,
    infoForeground,
    listHoverBackground,
    listActiveSelectionBackground,
    focusBorder,
    sashHoverBorder,
    menuBarBackground,
    menuBarForeground,
    menuBarHoverBackground,
    menuBarBorder,
    focusBorderSubtle,
    focusBorderMuted,
    focusBorderProminent,
    descriptionBadgeBackground,
    descriptionDisabledBackground,
    descriptionMuted,
    descriptionSecondary,
    errorBorderMuted,
    warningBackgroundSubtle,
    warningBorderMuted,
    infoBackgroundSubtle,
    infoBorderMuted,
    successBackgroundSubtle,
    successBorderMuted,
    sideBarBackgroundSubtle,
    sideBarBackgroundMuted,
    editorBackgroundOverlay,
    chromeFontFamily,
    editorFontFamily,
    editorFontSize,
    editorStyle,
    tabBarLabelColor,
    tabBarUnselectedLabelColor,
    tabBarIndicatorColor,
    tabBarDividerColor,
    badgeBackground,
    badgeForeground,
    subsectionTitleStyle,
    bodyStyle,
    helperStyle,
    borderColor,
    focusBorderColor,
    sectionTitle,
    labelText,
    bodyText,
    captionText,
    smallText,
    buttonTextStyle,
    statusText,
    statusBarTextStyle,
    valueText,
    sidebarOrPanelHeading,
    loglineMessage,
    tokenTheme,
    notificationBackground,
    notificationBorder,
    notificationForeground,
    notificationCloseForeground,
    notificationActionBackground,
    notificationActionForeground,
    notificationActionHoverBackground,
    notificationProgressTrack,
    notificationProgressFill,
    surfaceTone,
  ]);
}

/// VS Code's `EDITOR_FONT_DEFAULTS` primary family per platform —
/// mirrors `DEFAULT_MAC_FONT_FAMILY`, `DEFAULT_WINDOWS_FONT_FAMILY`,
/// and `DEFAULT_LINUX_FONT_FAMILY` in
/// `src/vs/editor/common/config/fontInfo.ts`. The CSS `font-family`
/// list includes secondary fallbacks (`Monaco`, `'Courier New'`,
/// `monospace`); Flutter's `TextStyle.fontFamily` takes a single name
/// and falls back to the platform monospace if the primary is missing,
/// which matches the upstream intent.
String _platformEditorFontFamily() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.iOS:
      return 'Menlo';
    case TargetPlatform.windows:
      return 'Consolas';
    case TargetPlatform.linux:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return 'Droid Sans Mono';
  }
}

/// VS Code's `isMacintosh ? 12 : 14` size selector for the editor.
/// Mirrored from `EDITOR_FONT_DEFAULTS.fontSize` in
/// `src/vs/editor/common/config/fontInfo.ts`.
double _platformEditorFontSize() {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.iOS:
      return 12;
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
      return 14;
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

/// Severity-keyed accents for notification cards. Reuses the
/// existing semantic-status tokens
/// ([WorkbenchTheme.infoForeground], etc.) so notification chrome
/// stays consistent with other severity-aware surfaces (gutter
/// icons, problems panel, etc.).
extension WorkbenchThemeNotificationSeverity on WorkbenchTheme {
  /// Foreground/icon color for [severity].
  Color severityForeground(NotificationSeverity severity) {
    switch (severity) {
      case NotificationSeverity.info:
        return infoForeground;
      case NotificationSeverity.success:
        return successForeground;
      case NotificationSeverity.warning:
        return warningForeground;
      case NotificationSeverity.error:
        return errorForeground;
      case NotificationSeverity.progress:
        // Progress cards reuse the determinate progress bar's fill
        // colour for their accent stripe so the stripe and the
        // progress indicator inside the card visually agree.
        return notificationProgressFill;
    }
  }
}

import 'package:flutter/painting.dart';

/// Geometry constants for the VS Code-style workbench layout.
///
/// Layout dimensions, not theme colors. Constant regardless of
/// which color theme is active.
class WorkbenchLayoutConstants {
  WorkbenchLayoutConstants._();

  // ==================== STRUCTURAL GEOMETRY ====================

  /// Activity bar width.
  static const double activityBarWidth = 48.0;

  /// Sidebar default width.
  static const double sidebarDefaultWidth = 300.0;

  /// Sidebar minimum width. VS Code `sidebarPart.ts` `minimumWidth = 170`.
  static const double sidebarMinWidth = 170.0;

  /// Sidebar maximum width.
  static const double sidebarMaxWidth = 600.0;

  /// Bottom panel default height.
  static const double panelDefaultHeight = 200.0;

  /// Bottom panel minimum height. VS Code `panelPart.ts`
  /// `minimumHeight = 77`.
  static const double panelMinHeight = 77.0;

  /// Bottom panel maximum height.
  static const double panelMaxHeight = 400.0;

  /// Status bar height. VS Code `statusbarpart.css` `height: 22px`.
  static const double statusBarHeight = 22.0;

  /// Centered-layout default margin ratio per side (§spec:editing-modes). VS
  /// Code's `centeredViewLayout.ts` `defaultState` uses `leftMarginRatio =
  /// rightMarginRatio = 0.1909` — the golden-ratio split that leaves the editor
  /// ~61.8% of the width, with proportional margins that scale with the window.
  /// The margins are draggable; this is the reset value.
  static const double centeredLayoutMarginRatio = 0.1909;

  /// Smallest centered editor width (§spec:editing-modes). Below this the
  /// column is too narrow to center usefully, so the editor fills it and the
  /// margins/hairlines are suppressed (VS Code's `centeredLayoutAutoResize`).
  static const double centeredLayoutMinEditorWidth = 400.0;

  // ==================== SPACING RAMP ====================
  //
  // VS Code registers a fixed spacing ramp for padding, margins and gaps in
  // [`baseSizes.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/platform/theme/common/sizes/baseSizes.ts)
  // (§spec:design-size-ladders). Each numeric token encodes its value in
  // tenths of a pixel, so `spacingSize160` is 16px. Upstream owns the
  // values; a gap the package needs picks the nearest registered step
  // rather than inventing a literal.

  static const double spacingNone = 0.0;
  static const double spacingSize20 = 2.0;
  static const double spacingSize40 = 4.0;
  static const double spacingSize60 = 6.0;
  static const double spacingSize80 = 8.0;
  static const double spacingSize100 = 10.0;
  static const double spacingSize120 = 12.0;
  static const double spacingSize160 = 16.0;
  static const double spacingSize200 = 20.0;
  static const double spacingSize240 = 24.0;
  static const double spacingSize280 = 28.0;
  static const double spacingSize320 = 32.0;
  static const double spacingSize360 = 36.0;
  static const double spacingSize400 = 40.0;

  // ==================== ICON SIZES ====================

  /// 12px — status bar inline icons.
  static const double iconXs = 12.0;

  /// 14px — small status/indicator icons.
  static const double iconSm = 14.0;

  /// 16px — standard inline icons (buttons, list items).
  static const double iconMd = 16.0;

  /// 20px — medium icons (action buttons).
  static const double iconLg = 20.0;

  /// 24px — activity bar icons, primary actions.
  static const double iconXl = 24.0;

  // ==================== SHELL CHROME GEOMETRY ====================

  /// Activity bar icon optical size (30px for Material Symbols at
  /// 48px bar width).
  static const double iconActivityBar = 30.0;

  /// Status bar icon size (17px — between iconMd and iconLg for
  /// optical balance in the 22px-tall status bar).
  static const double iconStatusBar = 17.0;

  /// Sidebar heading row height.
  static const double sidebarHeadingHeight = 35.0;

  /// View-pane header row height — the band each stacked view pane header
  /// occupies. VS Code's Modern UI treatment raises the base
  /// `paneview.ts` `DEFAULT_PANE_HEADER_SIZE = 22` to the spacing ramp's 28px
  /// step:
  /// [`paneHeaders.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/modernUI/browser/media/paneHeaders.css)
  /// sets `--pane-header-size: var(--vscode-spacing-size280)` and keeps it in
  /// sync with the layout code's `MODERN_UI_PANE_HEADER_SIZE`
  /// (§spec:modern-ui-surfaces). The inset top rule is drawn inside this
  /// height, so a header sits at this height, not this height + 1.
  ///
  /// Read at VS Code 1.138.0. The treatment ships behind an experiment, so
  /// this value is the one most likely to be reverted upstream; the pin is
  /// what makes such a reversal a diff rather than silent drift
  /// (§spec:layout-constants-canon).
  static const double viewPaneHeaderHeight = spacingSize280;

  /// View-pane minimum body height. The floor below which an expanded pane's
  /// apportioned body never shrinks (§spec:view-stack). VS Code's view pane
  /// registers `minimumBodySize = 120` (`viewPane.ts`); the splitview keeps an
  /// expanded body at least this tall and, when the expanded panes cannot all
  /// fit at this floor, scrolls the whole stack as the overflow fallback.
  static const double viewPaneMinBodyHeight = 120.0;

  /// Tab strip row height inside the bottom panel. Shares VS Code's
  /// `.part > .title { height: 35px }` (`part.css`) with
  /// [sidebarHeadingHeight]. The strip's `Row` flex-centres its children
  /// inside this single container — VS Code lays the tab strip out the
  /// same way, with no separate vertical padding constants.
  static const double panelTabStripHeight = 35.0;

  /// Cross-axis thickness of a resize sash's hit target — VS Code's
  /// `--vscode-sash-size`. Owned by `WorkbenchSash` so every seam is identical.
  static const double sashSize = 4.0;

  /// Cross-axis thickness of a sash's hover/drag highlight band, centered in
  /// the hit target — VS Code's `--vscode-sash-hover-size`.
  static const double sashHoverSize = 4.0;

  /// Active-indicator border width on activity bar icons.
  static const double activityBarIndicatorWidth = 2.0;

  // ==================== CORNER RADIUS LADDER ====================
  //
  // VS Code registers a six-tier corner-radius ladder in
  // [`baseSizes.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/platform/theme/common/sizes/baseSizes.ts).
  // [`roundedCorners.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/modernUI/browser/media/roundedCorners.css)
  // records the doctrine for choosing among the tiers: pick by the role a
  // surface plays, not by how large it looks (§spec:design-size-ladders).
  //
  //   - Controls tier ([cornerRadiusSmall]) — interactable controls: text
  //     inputs, selects, list/tree rows, scrollbar sliders, buttons.
  //   - Inner tier ([cornerRadiusMedium]) — non-control containers that sit
  //     within the workbench.
  //   - Outer tier ([cornerRadiusLarge]) — overlays floating above the
  //     workbench: quick input, hovers, menus, dialogs.
  //
  // Upstream owns the values; the package owns only the tier assignment at
  // each call site. The registrations hold constant across every shipped
  // theme, so these stay constants rather than `WorkbenchTheme` tokens.

  /// 2px — `cornerRadius.xSmall`. Very compact UI elements.
  static const double cornerRadiusXSmall = 2.0;

  /// 4px — `cornerRadius.small`. The controls tier: compact, interactable
  /// UI elements.
  static const double cornerRadiusSmall = 4.0;

  /// 6px — `cornerRadius.medium`. The inner tier: non-control containers
  /// within the workbench.
  static const double cornerRadiusMedium = 6.0;

  /// 8px — `cornerRadius.large`. The outer tier: prominent surfaces and
  /// overlays floating above the workbench.
  static const double cornerRadiusLarge = 8.0;

  /// 12px — `cornerRadius.xLarge`. Very prominent UI elements.
  static const double cornerRadiusXLarge = 12.0;

  /// 9999px — `cornerRadius.circle`. Fully rounded elements; the radius
  /// clamps to half the shorter side, so a short badge reads as a dot.
  static const double cornerRadiusCircle = 9999.0;

  // ==================== STROKE THICKNESS ====================

  /// 1px — `strokeThickness`. Base thickness for chrome borders and
  /// outlines (§spec:design-size-ladders).
  static const double strokeThickness = 1.0;

  // ==================== BUTTONS ====================

  /// The controls tier as a `BorderRadius`. Every all-corners surface on that
  /// tier — pane headers, notification cards, the ink splash behind a header —
  /// composes the same shape from [cornerRadiusSmall], so it is named once
  /// here. The ladder itself stays scalar because upstream assigns tiers per
  /// corner (§spec:design-size-ladders); this is the all-corners case that
  /// every current call site actually wants, and `BorderRadius.circular` is
  /// not a const constructor, so composing it inline allocates per rebuild.
  static const BorderRadius controlsRadius = BorderRadius.all(
    Radius.circular(cornerRadiusSmall),
  );

  /// Button shape — applied to the app-level Material button themes
  /// (Filled/Text, §spec:chrome-material-theming). De-pills Material 3's
  /// default `StadiumBorder` to match VS Code's rectangular buttons. A
  /// button is an interactable control, so it takes the controls tier;
  /// upstream's `button.css` renders `.monaco-text-button` at the same 4px.
  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(cornerRadiusSmall)),
  );

  /// 32px — button height. VS Code's `.monaco-button` is a compact
  /// ~26-28px control, but this shell targets more button-heavy UIs than
  /// VS Code, so it trades a little density for a less cramped label;
  /// Material 3's button family defaults to 40px in a 48px tap target. The
  /// §spec:chrome-material-theming button themes set this as the minimum height with
  /// `MaterialTapTargetSize.shrinkWrap` so the rendered button matches the
  /// shell's density rather than Material's touch sizing. Single source of
  /// truth — every chrome-themed button moves together when it changes.
  static const double buttonHeight = 32;

  /// Button horizontal padding. VS Code's `.monaco-text-button` pads
  /// ~14px on each side; height is governed by [buttonHeight], so the
  /// vertical component is zero.
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: 14);

  /// 300px — welcome-view button width cap (§spec:structural-primitives).
  /// VS Code's `welcomeView.css` caps `.monaco-button` at `max-width: 300px`;
  /// a welcome button stretches full width in a narrow pane and centers at
  /// this cap in a wider one.
  static const double viewWelcomeButtonMaxWidth = 300.0;

  // ==================== NOTIFICATION CENTER (§spec:notification-center) ====================

  /// 450px — notification card width. VS Code `notificationsToasts.ts`
  /// `MAX_WIDTH = 450`. Wide enough to fit a couple of action buttons
  /// on one row; matches VS Code's observable toast layout.
  static const double notificationCardWidth = 450.0;

  /// Gap between the notification stack and the workbench edge (bottom
  /// and right). Takes the ramp's 16px step so the stack sits on the same
  /// grid as sidebar content.
  static const double notificationStackInset = spacingSize160;

  /// Vertical gap between cards in the stack. Tighter than
  /// [notificationStackInset] so the cards read as one group rather than
  /// as separate overlays.
  static const double notificationStackGap = spacingSize80;

  /// 5 — visible card budget. When more cards exist, the oldest
  /// non-persistent ones collapse into a "+N more" summary card
  /// occupying the top slot (SPEC §spec:notification-center).
  static const int notificationMaxVisible = 5;

  /// Auto-dismiss duration for info/success cards (SPEC §spec:notification-center
  /// "Dismissal policy by severity").
  static const Duration notificationAutoDismissDuration = Duration(seconds: 6);

  /// 4px — progress bar track height inside a notification card.
  static const double notificationProgressBarHeight = 4.0;
}

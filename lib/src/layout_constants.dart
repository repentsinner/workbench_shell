import 'package:flutter/painting.dart';

/// Geometry constants for the VS Code-style workbench layout.
///
/// Layout dimensions, not theme colors. Constant regardless of
/// which color theme is active.
class WorkbenchLayoutConstants {
  WorkbenchLayoutConstants._();

  // ==================== STRUCTURAL GEOMETRY ====================

  /// Activity bar layout allocation at the default density. VS Code's
  /// `ActivitybarPart.minimumWidth` is `baseWidth + floatingHorizontalGutter`,
  /// which under the Modern UI treatment is [activityBarRailWidth] +
  /// [activityBarLane] + [floatingCardPerimeter] — the rail card plus the
  /// cluster's perimeter gutter (§spec:modern-ui-surfaces). The rail frames
  /// itself inside this allocation, so the row measures the same 48px it
  /// always did. This is the default density's allocation, which is the value
  /// upstream states; a narrower lane derives its own via [railWidthForLane].
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

  /// View-pane header row height with the Modern UI treatment off
  /// (§spec:modern-ui-surfaces). VS Code `paneview.ts`
  /// `DEFAULT_PANE_HEADER_SIZE = 22` — the band the treatment raises to
  /// [viewPaneHeaderHeight]. The full-width top rule the base treatment draws
  /// is absorbed within this height (`box-sizing: border-box`), so a header
  /// sits at this height, not this height + 1.
  static const double baseViewPaneHeaderHeight = 22.0;

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

  /// Active-indicator border width on activity bar icons with the Modern UI
  /// treatment off (§spec:modern-ui-surfaces). VS Code `activitybarpart.css`
  /// `.action-item.checked .active-item-indicator:before { border-left-width:
  /// 2px }`; `activityBar.css` drops it for the filled background
  /// [activityBarItemIndicatorSize] names.
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

  // ==================== MODERN UI SURFACE TREATMENT ====================
  //
  // VS Code frames the side bars, bottom panel, editor and activity bar as
  // bordered, rounded cards separated by a gap (§spec:modern-ui-surfaces).
  // Values come from
  // [`layoutService.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/services/layout/browser/layoutService.ts),
  // [`floatingPanels.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/media/floatingPanels.css),
  // [`editorBorder.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/modernUI/browser/media/editorBorder.css),
  // [`activityBar.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/modernUI/browser/media/activityBar.css)
  // and
  // [`activitybarPart.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/activitybar/activitybarPart.ts),
  // and are expressed through the ladders above wherever a step names them.
  // Read against VS Code 1.138.0.
  //
  // Every gutter here is consumed from the part's own layout allocation, so
  // the drag-resize arithmetic (§spec:resize-geometry) and the min/max floors
  // (§spec:layout-constants) keep measuring the quantities they always did.

  /// Gap between two adjacent cards at the default density. VS Code
  /// `layoutService.ts` `FLOATING_PANEL_MARGIN = 4`, published to CSS as
  /// `--modern-ui-floating-card-margin` (`spacing.size40`). Each card owns the
  /// gap on its leading edge, so a trailing edge carries one only where no
  /// card follows it.
  ///
  /// Distinct from [floatingCardPerimeter], which the two densities resolve
  /// differently: this gap closes under compact, the perimeter does not.
  static const double floatingCardGap = spacingSize40;

  /// The same gap at the compact density: closed, so adjacent cards meet
  /// edge-to-edge. VS Code `layoutService.ts`
  /// `COMPACT_FLOATING_PANEL_MARGIN = 0`, published as
  /// `--modern-ui-floating-card-margin` (`spacing.sizeNone`).
  static const double compactFloatingCardGap = spacingNone;

  /// Gutter a card reserves on an edge that faces window chrome rather than
  /// another card — the cluster's perimeter. VS Code `layoutService.ts`
  /// `getFloatingPanelOuterMargin` resolves `FLOATING_PANEL_MARGIN` at the
  /// default density and `COMPACT_FLOATING_PANEL_OUTER_MARGIN = 4` at compact,
  /// so the perimeter is density-invariant. `floatingPanels.css` states the
  /// rule on `--modern-ui-floating-card-outer-margin`: the cluster perimeter
  /// is the same in both densities, and only the gap *between* cards differs.
  ///
  /// Equal to [floatingCardGap] at the default density. The two are separate
  /// constants because they measure different quantities and diverge under
  /// compact, not because they differ today.
  static const double floatingCardPerimeter = spacingSize40;

  /// Corner radius of a floating card at the default density. Both
  /// `floatingPanels.css` and `editorBorder.css` round every card at
  /// `cornerRadius.large` — the outer tier, since a card is a prominent
  /// surface rather than a control.
  static const double floatingCardRadius = cornerRadiusLarge;

  /// The same radius at the compact density: squared, so the parts meet
  /// edge-to-edge. `floatingPanels.css` sets `border-radius: 0` on every
  /// compact card and `editorBorder.css` does the same for the editor frame.
  static const double compactFloatingCardRadius = 0.0;

  /// Icon-column width inside the activity bar card. VS Code
  /// `activitybarPart.ts` `FLOATING_ACTIVITYBAR_WIDTH = 36`, published as
  /// `--activity-bar-width` and applied to every `.action-item`.
  static const double activityBarRailWidth = 36.0;

  /// Space inside the activity bar card beside the icon column — the rail's
  /// own horizontal padding, doubled. VS Code `activitybarPart.ts`
  /// `FLOATING_LANE = 8` / `--modern-ui-activitybar-lane` (`spacing.size80`).
  /// Independent of the cluster perimeter, so the icons keep their inset
  /// whatever the gutter is.
  static const double activityBarLane = spacingSize80;

  /// The same lane at the compact density. VS Code `activitybarPart.ts`
  /// `FLOATING_COMPACT_LANE = 4`, published as `--modern-ui-activitybar-lane`
  /// (`spacing.size40`) from the `.modern-ui-compact .part.activitybar` rule.
  static const double compactActivityBarLane = spacingSize40;

  /// Height of one activity bar item. VS Code `activitybarPart.ts`
  /// `FLOATING_ACTION_HEIGHT = 36`.
  static const double activityBarItemHeight = 36.0;

  /// Vertical gap between two adjacent activity bar items. VS Code
  /// `activitybarPart.ts` `FLOATING_ACTION_GAP = 8`, published as
  /// `--activity-bar-action-gap` (`spacing.size80`) so the stylesheet and the
  /// overflow computation cannot drift apart.
  static const double activityBarItemGap = spacingSize80;

  /// The same item gap at the compact density. VS Code `activitybarPart.ts`
  /// `FLOATING_COMPACT_ACTION_GAP = 4` (`spacing.size40`), tightening the
  /// rail's rhythm to match the closed card gaps. The item *height* does not
  /// change: `FLOATING_COMPACT_ACTIVITYBAR_WIDTH` and `COMPACT_ACTION_HEIGHT`
  /// belong to the activity bar's own size setting (`_isCompact`), not to the
  /// Modern UI density.
  static const double compactActivityBarItemGap = spacingSize40;

  /// Side of the filled background behind an active or hovered activity bar
  /// icon. `activityBar.css` sizes it
  /// `calc(var(--activity-bar-action-height) - 4px)`.
  static const double activityBarItemIndicatorSize =
      activityBarItemHeight - spacingSize40;

  /// Corner radius of that background. `activityBar.css` rounds it at
  /// `cornerRadius.small` — the controls tier, since the indicator marks an
  /// interactable target rather than a surface.
  static const double activityBarItemIndicatorRadius = cornerRadiusSmall;

  /// Inset from the activity bar card's content box to the icon column, on
  /// every side, at the default density. `floatingPanels.css` centres the
  /// column with `calc((var(--modern-ui-activitybar-lane) - 2px) / 2)` — the
  /// lane less the card's two strokes, halved. Taking the strokes off before
  /// halving is what keeps the icons optically centred instead of a pixel off.
  /// A density that narrows the lane calls [iconInsetForLane] instead.
  static const double activityBarIconInset =
      (activityBarLane - 2 * strokeThickness) / 2;

  /// [activityBarIconInset] for an arbitrary lane, so a density that narrows
  /// the lane derives its inset from the same rule rather than restating it.
  static double iconInsetForLane(double lane) =>
      (lane - 2 * strokeThickness) / 2;

  /// The rail's whole allocation for an arbitrary lane — the icon column, the
  /// lane beside it, and the cluster's perimeter gutter (VS Code
  /// `ActivitybarPart.minimumWidth`). At the default lane this resolves to
  /// [activityBarWidth], which stays a literal because upstream states it as
  /// one.
  static double railWidthForLane(double lane) =>
      activityBarRailWidth + lane + floatingCardPerimeter;

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

  /// Popup menu row height. VS Code's
  /// [`menu.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/base/browser/ui/menu/menu.ts)
  /// sizes `.monaco-menu .monaco-action-bar.vertical .action-menu-item` at
  /// 24px. Material's `MenuItemButton` defaults far taller, so the
  /// §spec:chrome-material-theming menu themes set this as the row's minimum
  /// height with `MaterialTapTargetSize.shrinkWrap`.
  static const double menuRowHeight = 24;

  /// Popup menu row horizontal inset. The same rule carries `margin: 0 4px`,
  /// which the panel supplies as horizontal padding so each row's rounded
  /// fill stops short of the panel edge.
  static const double menuRowInset = spacingSize40;

  /// Popup menu panel vertical padding. `.monaco-action-bar.vertical` pads
  /// `4px 0`, so the first and last rows clear the panel's rounded corners.
  static const double menuPanelVerticalPadding = spacingSize40;

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

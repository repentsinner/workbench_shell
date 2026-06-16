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

  /// Splitter width (drag handle for sidebar/panel resizers).
  static const double splitterWidth = 2.0;

  // ==================== SPACING SCALE ====================

  /// 2px — hairline gaps (e.g. between axis label and value).
  static const double spacingXxs = 2.0;

  /// 4px — tight gaps (e.g. icon-to-text in status bar items).
  static const double spacingXs = 4.0;

  /// 8px — standard small gap (e.g. between buttons in a row).
  static const double spacingSm = 8.0;

  /// 12px — medium gap (e.g. section heading to content).
  static const double spacingMd = 12.0;

  /// 16px — standard section gap (e.g. between sidebar sections).
  static const double spacingLg = 16.0;

  /// 24px — large section gap (e.g. between major sidebar sections).
  static const double spacingXl = 24.0;

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

  /// 32px — large decorative/placeholder icons.
  static const double iconXxl = 32.0;

  // ==================== SHELL CHROME GEOMETRY ====================

  /// Activity bar icon optical size (30px for Material Symbols at
  /// 48px bar width).
  static const double iconActivityBar = 30.0;

  /// Status bar icon size (17px — between iconMd and iconLg for
  /// optical balance in the 22px-tall status bar).
  static const double iconStatusBar = 17.0;

  /// Sidebar heading row height.
  static const double sidebarHeadingHeight = 35.0;

  /// View-pane header row height. VS Code `paneview.css` /
  /// `splitview` `HEADER_SIZE = 22` — the band each stacked view pane
  /// header occupies. The 1px top rule (§spec:view-stack) is absorbed
  /// within this height (box-sizing border-box), so a header sits at
  /// this height, not this height + 1.
  static const double viewPaneHeaderHeight = 22.0;

  /// Tab strip row height inside the bottom panel. Shares VS Code's
  /// `.part > .title { height: 35px }` (`part.css`) with
  /// [sidebarHeadingHeight]. The strip's `Row` flex-centres its children
  /// inside this single container — VS Code lays the tab strip out the
  /// same way, with no separate vertical padding constants.
  static const double panelTabStripHeight = 35.0;

  /// Width/height of the resizer drag-target zone.
  static const double resizerHitTargetSize = 4.0;

  /// Active-indicator border width on activity bar icons.
  static const double activityBarIndicatorWidth = 2.0;

  /// Switch container width (scaled to compact Material size).
  static const double switchWidth = 28.0;

  /// Switch container height (scaled to compact Material size).
  static const double switchHeight = 16.0;

  // ==================== BORDER RADIUS ====================

  /// 4px — standard container border radius.
  static const BorderRadius containerRadius = BorderRadius.all(
    Radius.circular(4),
  );

  /// 4px — button border radius. Sourced from VS Code's `button.css`
  /// (`.monaco-text-button { border-radius: 4px; }`). Same scale as
  /// [containerRadius] today; tokenized separately so a future visual
  /// revision of button shape can diverge without touching every other
  /// rounded surface (mirrors [containerRadius]/[notificationCardRadius]).
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(4));

  /// Button shape — applied to the app-level Material button themes
  /// (Filled/Text, §spec:chrome-material-theming). De-pills Material 3's default `StadiumBorder`
  /// to match VS Code's rectangular-with-4px buttons.
  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: buttonRadius,
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

  // ==================== NOTIFICATION CENTER (§spec:notification-center) ====================

  /// 4px — notification card border radius. Same scale as
  /// [containerRadius]; named separately so a future visual revision
  /// of notification cards (rounder pill, square, etc.) can change
  /// without touching every other card surface.
  static const BorderRadius notificationCardRadius = BorderRadius.all(
    Radius.circular(4),
  );

  /// 450px — notification card width. VS Code `notificationsToasts.ts`
  /// `MAX_WIDTH = 450`. Wide enough to fit a couple of action buttons
  /// on one row; matches VS Code's observable toast layout.
  static const double notificationCardWidth = 450.0;

  /// 16px — gap between the notification stack and the workbench
  /// edge (bottom and right). Aligns with [spacingLg] so the stack
  /// sits on the same grid as sidebar content.
  static const double notificationStackInset = 16.0;

  /// 8px — vertical gap between cards in the stack. One step below
  /// [spacingMd] so cards feel grouped rather than separated.
  static const double notificationStackGap = 8.0;

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

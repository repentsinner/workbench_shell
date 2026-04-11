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

  /// Sidebar minimum width.
  static const double sidebarMinWidth = 200.0;

  /// Sidebar maximum width.
  static const double sidebarMaxWidth = 600.0;

  /// Bottom panel default height.
  static const double panelDefaultHeight = 200.0;

  /// Bottom panel minimum height.
  static const double panelMinHeight = 100.0;

  /// Bottom panel maximum height.
  static const double panelMaxHeight = 400.0;

  /// Status bar height.
  static const double statusBarHeight = 25.0;

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
  /// optical balance in the 25px-tall status bar).
  static const double iconStatusBar = 17.0;

  /// Sidebar heading row height.
  static const double sidebarHeadingHeight = 35.0;

  /// Tab strip row height inside the bottom panel.
  static const double panelTabStripHeight = 22.0;

  /// Vertical padding above and below the tab strip.
  static const double panelTabStripPaddingY = 6.0;

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
}

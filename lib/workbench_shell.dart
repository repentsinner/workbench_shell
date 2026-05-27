/// VS Code-style workbench layout shell.
///
/// Provides the activity-bar + sidebar + editor-area + bottom-panel +
/// status-bar chrome. Consumer fills content via builder callbacks.
/// Depends only on Flutter — no GetIt, no application packages.
library;

export 'src/activity_bar_item.dart';
export 'src/layout_constants.dart';
// Notification center (§10): service, value types, progress
// controller, and host overlay widget.
export 'src/notifications/notification.dart';
export 'src/notifications/notification_host.dart';
export 'src/notifications/notification_progress_controller.dart';
export 'src/notifications/notification_service.dart';
// UI extension slots (consumed by apps to extend the shell)
export 'src/slots/sidebar_slot.dart';
export 'src/slots/sidebar_zone.dart';
export 'src/slots/slot_id.dart';
export 'src/slots/slot_registry.dart';
export 'src/theming/token_theme.dart';
export 'src/theming/vscode_color_map.dart';
export 'src/workbench_content.dart';
export 'src/workbench_intents.dart';
export 'src/workbench_layout.dart';
export 'src/workbench_panel.dart';
export 'src/workbench_panel_host.dart';
export 'src/workbench_status_bar.dart';
export 'src/workbench_tabbed_panel.dart';
export 'src/workbench_theme.dart';
export 'src/workbench_theme_controller.dart';
export 'src/workbench_view_menu.dart';

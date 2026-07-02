/// VS Code-style workbench layout shell.
///
/// Provides the activity-bar + sidebar + editor-area + bottom-panel +
/// status-bar chrome. Consumer fills content via builder callbacks.
/// Depends only on Flutter — no GetIt, no application packages.
library;

export 'src/activity_bar_item.dart';
export 'src/layout_constants.dart';
// Notification center (§spec:notification-center): service, value types, progress
// controller, and host overlay widget.
export 'src/notifications/notification.dart';
export 'src/notifications/notification_host.dart';
export 'src/notifications/notification_progress_controller.dart';
export 'src/notifications/notification_service.dart';
export 'src/theming/token_theme.dart';
export 'src/theming/vscode_color_map.dart';
export 'src/theming/workbench_chrome_theme.dart';
export 'src/workbench_content.dart';
export 'src/workbench_intents.dart';
export 'src/workbench_layout.dart';
export 'src/workbench_layout_state.dart';
export 'src/workbench_panel.dart';
export 'src/workbench_panel_host.dart';
export 'src/workbench_status_bar.dart';
export 'src/workbench_tabbed_panel.dart';
export 'src/workbench_theme.dart';
export 'src/workbench_theme_controller.dart';
export 'src/workbench_view_container.dart';
export 'src/workbench_view_menu.dart';

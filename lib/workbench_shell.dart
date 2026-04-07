/// VS Code-style workbench layout shell.
///
/// Provides the activity-bar + sidebar + editor-area + bottom-panel +
/// status-bar chrome. Consumer fills content via builder callbacks.
/// Depends only on Flutter — no GetIt, no application packages.
library;

export 'src/activity_bar_item.dart';
export 'src/layout_constants.dart';
export 'src/workbench_content.dart';
export 'src/workbench_layout.dart';
export 'src/workbench_theme.dart';

import 'package:flutter/material.dart';

import 'layout_constants.dart';
import 'workbench_theme.dart';

/// Container for status-bar items at the bottom of the workbench.
///
/// The shell owns the container chrome: height, background, top
/// border, padding, and the left/right alignment of items. Apps
/// populate [leading] and [trailing] with [WorkbenchStatusBarItem]
/// or [WorkbenchStatusBarAction] children carrying domain data.
///
/// The status bar shall not carry panel-visibility toggles —
/// those are a View-menu concern (see SPEC.md §9.14 item 5).
class WorkbenchStatusBar extends StatelessWidget {
  /// Items aligned to the left edge of the status bar.
  final List<Widget> leading;

  /// Items aligned to the right edge of the status bar.
  final List<Widget> trailing;

  const WorkbenchStatusBar({
    super.key,
    this.leading = const [],
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Container(
      height: WorkbenchLayoutConstants.statusBarHeight,
      decoration: BoxDecoration(
        color: theme.statusBarBackground,
        border: Border(top: BorderSide(color: theme.statusBarBorder)),
      ),
      child: Row(children: [...leading, const Spacer(), ...trailing]),
    );
  }
}

/// Read-only status indicator: optional [icon] + [label].
///
/// Renders inside [WorkbenchStatusBar]. For tappable affordances
/// use [WorkbenchStatusBarAction] instead.
class WorkbenchStatusBarItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? iconColor;
  final TextStyle? textStyle;

  const WorkbenchStatusBarItem({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? theme.helperStyle.color),
            const SizedBox(width: 4),
          ],
          Text(label, style: textStyle ?? theme.helperStyle),
        ],
      ),
    );
  }
}

/// Tappable status-bar affordance: optional [icon] + [label] +
/// [onTap]. Use for items that trigger an action (e.g. open a
/// dialog, focus a tab) — never for panel-visibility toggles.
class WorkbenchStatusBarAction extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? iconColor;
  final TextStyle? textStyle;

  const WorkbenchStatusBarAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tooltip,
    this.iconColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? theme.helperStyle.color),
            const SizedBox(width: 4),
          ],
          Text(label, style: textStyle ?? theme.helperStyle),
        ],
      ),
    );
    final tappable = InkWell(onTap: onTap, child: child);
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: tappable);
    }
    return tappable;
  }
}

/// VS Code-style "Problems" status-bar indicator: three role-coloured
/// counts (errors, warnings, info) sharing a single tap target.
///
/// The host supplies three ints plus an [onTap] callback that opens
/// (or focuses) whatever bottom-panel tab holds the underlying
/// diagnostics. Icons, colours, spacing, and typography all resolve
/// from [WorkbenchTheme] — the shell owns the visual contract so
/// every host renders a consistent indicator.
///
/// Matching VS Code, all three counts render unconditionally
/// (including zeros). The indicator is always visible so its
/// position does not shift as task counts change.
class WorkbenchStatusBarProblemsItem extends StatelessWidget {
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final VoidCallback onTap;

  /// Optional tooltip override. Defaults to
  /// `"E errors, W warnings, I info"`.
  final String? tooltip;

  const WorkbenchStatusBarProblemsItem({
    super.key,
    required this.errorCount,
    required this.warningCount,
    required this.infoCount,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(theme, icon: Icons.error_outline, count: errorCount),
          const SizedBox(width: 8),
          _badge(
            theme,
            icon: Icons.warning_amber_outlined,
            count: warningCount,
          ),
          const SizedBox(width: 8),
          _badge(theme, icon: Icons.info_outline, count: infoCount),
        ],
      ),
    );
    return Tooltip(
      message:
          tooltip ??
          '$errorCount errors, $warningCount warnings, $infoCount info',
      child: InkWell(onTap: onTap, child: child),
    );
  }

  Widget _badge(
    WorkbenchTheme theme, {
    required IconData icon,
    required int count,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.helperStyle.color),
        const SizedBox(width: 4),
        Text('$count', style: theme.helperStyle),
      ],
    );
  }
}

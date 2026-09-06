import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

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
/// those are a View-menu concern (see SPEC §spec:status-bar).
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
    // No top hairline: `floatingPanels.css` hides the classic
    // `status-border-top` rule under the floating-panels treatment, so the bar
    // meets the band above it on its own fill (§spec:modern-ui-surfaces).
    // `statusBar.border` stays on [WorkbenchTheme] — it is a registered token a
    // host may read, and base VS Code still draws it — but nothing paints it
    // while the package renders the Modern UI treatment.
    return Container(
      height: WorkbenchLayoutConstants.statusBarHeight,
      decoration: BoxDecoration(color: theme.statusBarBackground),
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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkbenchLayoutConstants.spacingSize80,
      ),
      child: _StatusBarLabel(
        icon: icon,
        label: label,
        iconColor: iconColor,
        textStyle: textStyle,
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
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkbenchLayoutConstants.spacingSize80,
      ),
      child: _StatusBarLabel(
        icon: icon,
        label: label,
        iconColor: iconColor,
        textStyle: textStyle,
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
/// Matching VS Code, the error and warning counts render
/// unconditionally (including zero) so the indicator holds its
/// position; the info count renders only when greater than zero —
/// VS Code's markers status contribution appends info "only if any"
/// (SPEC §spec:status-bar).
class WorkbenchStatusBarProblemsItem extends StatelessWidget {
  final int errorCount;
  final int warningCount;
  final int infoCount;
  final VoidCallback onTap;

  /// Optional tooltip override. Defaults to
  /// `"E errors, W warnings"`, with `", I info"` appended only when
  /// [infoCount] is greater than zero.
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
    final child = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkbenchLayoutConstants.spacingSize80,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusBarLabel(icon: Symbols.error_rounded, label: '$errorCount'),
          const SizedBox(width: WorkbenchLayoutConstants.spacingSize80),
          _StatusBarLabel(
            icon: Symbols.warning_rounded,
            label: '$warningCount',
          ),
          if (infoCount > 0) ...[
            const SizedBox(width: WorkbenchLayoutConstants.spacingSize80),
            _StatusBarLabel(icon: Symbols.info_rounded, label: '$infoCount'),
          ],
        ],
      ),
    );
    final infoSuffix = infoCount > 0 ? ', $infoCount info' : '';
    return Tooltip(
      message:
          tooltip ?? '$errorCount errors, $warningCount warnings$infoSuffix',
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// Icon + label row shared by status-bar leaf widgets.
///
/// Renders an optional [icon] followed by [label], both resolving to
/// [WorkbenchTheme.statusBarTextStyle] unless overridden. Centralizes the
/// icon size, gap, and colour fallback the status-bar widgets share.
class _StatusBarLabel extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? iconColor;
  final TextStyle? textStyle;

  const _StatusBarLabel({
    required this.label,
    this.icon,
    this.iconColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: WorkbenchLayoutConstants.iconStatusBar,
            color: iconColor ?? theme.statusBarTextStyle.color,
          ),
          const SizedBox(width: WorkbenchLayoutConstants.spacingSize40),
        ],
        Text(label, style: textStyle ?? theme.statusBarTextStyle),
      ],
    );
  }
}

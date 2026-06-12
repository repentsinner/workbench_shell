import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'layout_constants.dart';
import 'workbench_theme.dart';

/// Structural primitives for sidebars and bottom panels.
///
/// `workbench_shell` deliberately scopes this surface to structural
/// grouping (sections, subsections, cards, toggle cards, empty states).
/// Form controls — text fields, dropdowns, toggles, action buttons —
/// live in the host application as application helpers. See SPEC
/// §spec:form-controls-excluded for rationale and the re-promotion gate.

/// Resolve a content-primitive border side from the theme's nullable
/// [WorkbenchTheme.borderColor]. When the theme suppresses the border,
/// fall through to [BorderSide.none] so the content primitive draws
/// without a visible edge. Callers that need to skip the wrapping
/// decoration entirely should branch on `theme.borderColor == null`.
BorderSide _contentBorderSide(WorkbenchTheme theme) => theme.borderColor == null
    ? BorderSide.none
    : BorderSide(color: theme.borderColor!);

/// Top-level grouping inside a sidebar or panel. Renders [title]
/// uppercased — the shell owns the transform so consumers cannot
/// diverge (§spec:capability-boundary canon enforcement, §spec:chrome-typography-canon pane-header semantics) — in
/// [WorkbenchTheme.sectionTitle] with an optional info tooltip icon.
class WorkbenchSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? infoTooltip;

  const WorkbenchSection({
    super.key,
    required this.title,
    required this.child,
    this.infoTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title.toUpperCase(), style: theme.sectionTitle),
            ),
            if (infoTooltip != null) ...[
              const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
              Tooltip(
                message: infoTooltip!,
                child: Icon(
                  Symbols.info_rounded,
                  size: WorkbenchLayoutConstants.iconMd,
                  color: theme.descriptionForeground,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: WorkbenchLayoutConstants.spacingMd),
        child,
      ],
    );
  }
}

/// Second-level grouping inside a section. Visually subordinate to
/// [WorkbenchSection] but still acts as a header.
class WorkbenchSubsection extends StatelessWidget {
  final String title;
  final Widget child;

  const WorkbenchSubsection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.subsectionTitleStyle),
        const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
        child,
      ],
    );
  }
}

/// Bordered container for an inline list item or grouped fields.
/// No implicit heading.
class WorkbenchCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WorkbenchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WorkbenchLayoutConstants.spacingMd),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(_contentBorderSide(theme)),
        borderRadius: WorkbenchLayoutConstants.containerRadius,
      ),
      child: child,
    );
  }
}

/// Bordered card whose header row contains a leading toggle and a
/// subsection-style title. When [enabled] is false, [child] is dimmed
/// and input is suppressed, but layout does not reflow. The toggle
/// itself remains interactive so callers can re-enable.
class WorkbenchToggleCard extends StatelessWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WorkbenchToggleCard({
    super.key,
    required this.title,
    required this.enabled,
    required this.onChanged,
    required this.child,
    this.padding = const EdgeInsets.all(WorkbenchLayoutConstants.spacingMd),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(_contentBorderSide(theme)),
        borderRadius: WorkbenchLayoutConstants.containerRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: WorkbenchLayoutConstants.switchWidth,
                height: WorkbenchLayoutConstants.switchHeight,
                child: FittedBox(
                  child: Switch(
                    value: enabled,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
              Expanded(child: Text(title, style: theme.subsectionTitleStyle)),
            ],
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(opacity: enabled ? 1.0 : 0.4, child: child),
          ),
        ],
      ),
    );
  }
}

/// Centered icon + title + subtitle + optional action.
class WorkbenchEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const WorkbenchEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: WorkbenchLayoutConstants.iconXxl,
              color: theme.descriptionForeground,
            ),
            const SizedBox(height: WorkbenchLayoutConstants.spacingMd),
            Text(title, style: theme.sectionTitle, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: WorkbenchLayoutConstants.spacingXs),
              Text(
                subtitle!,
                style: theme.helperStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: WorkbenchLayoutConstants.spacingMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

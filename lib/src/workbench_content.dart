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
///
/// Opt-in disclosure (§spec:section-disclosure): set [collapsible] to add a
/// leading twistie chevron and let the header toggle body visibility. The
/// shell owns the chevron, the gesture, and the state — disclosure is not a
/// host widget slot. Two control modes mirror §spec:workbench-layout:
///
/// - *Uncontrolled*: omit [expanded]; the pane holds its own state, seeded
///   by [initiallyExpanded] (the `ExpansionTile` pattern).
/// - *Controlled*: pass [expanded] and [onExpandedChanged]; the host drives
///   the value and the pane reflects it, reporting each requested toggle.
///
/// A non-collapsible pane renders its body unconditionally, exactly as a
/// plain title + child — disclosure adds nothing to existing call sites.
class WorkbenchViewPane extends StatefulWidget {
  final String title;
  final Widget child;
  final String? infoTooltip;

  /// When true, the header shows a leading twistie and toggles the body.
  /// Off by default: a non-collapsible pane renders its body always.
  final bool collapsible;

  /// Initial expansion for uncontrolled (no [expanded]) collapsible panes.
  final bool initiallyExpanded;

  /// Controlled expansion. When non-null the host drives the state and the
  /// pane reflects this value rather than holding its own.
  final bool? expanded;

  /// Fired when header activation requests a new expanded state. In
  /// uncontrolled mode the pane has already applied the change; in
  /// controlled mode the host must push the new [expanded] value to apply it.
  final ValueChanged<bool>? onExpandedChanged;

  const WorkbenchViewPane({
    super.key,
    required this.title,
    required this.child,
    this.infoTooltip,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.expanded,
    this.onExpandedChanged,
  });

  @override
  State<WorkbenchViewPane> createState() => _WorkbenchViewPaneState();
}

class _WorkbenchViewPaneState extends State<WorkbenchViewPane> {
  late bool _expanded = widget.initiallyExpanded;

  /// The expansion the pane renders: the host's value when controlled,
  /// otherwise the internal state.
  bool get _isExpanded => widget.expanded ?? _expanded;

  void _handleToggle() {
    final next = !_isExpanded;
    // Uncontrolled panes apply the change themselves; controlled panes wait
    // for the host to push the new value.
    if (widget.expanded == null) {
      setState(() => _expanded = next);
    }
    widget.onExpandedChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    // Header order follows VS Code's pane header: twisty → title → metadata
    // (§spec:section-header-actions). Actions are a separate, later concern.
    final header = Row(
      children: [
        if (widget.collapsible) ...[
          Icon(
            _isExpanded
                ? Symbols.expand_more_rounded
                : Symbols.chevron_right_rounded,
            size: WorkbenchLayoutConstants.iconMd,
            color: theme.descriptionForeground,
          ),
          const SizedBox(width: WorkbenchLayoutConstants.spacingXs),
        ],
        Expanded(
          child: Text(widget.title.toUpperCase(), style: theme.sectionTitle),
        ),
        if (widget.infoTooltip != null) ...[
          const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
          Tooltip(
            message: widget.infoTooltip!,
            child: Icon(
              Symbols.info_rounded,
              size: WorkbenchLayoutConstants.iconMd,
              color: theme.descriptionForeground,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.collapsible)
          // Pointer + keyboard toggle with an expanded/collapsed a11y state.
          // A mouse-only disclosure control is not canon-complete
          // (§spec:section-disclosure).
          Semantics(
            button: true,
            expanded: _isExpanded,
            child: InkWell(
              onTap: _handleToggle,
              child: header,
            ),
          )
        else
          header,
        if (!widget.collapsible || _isExpanded) ...[
          const SizedBox(height: WorkbenchLayoutConstants.spacingMd),
          widget.child,
        ],
      ],
    );
  }
}

/// Second-level grouping inside a section. Visually subordinate to
/// [WorkbenchViewPane] but still acts as a header.
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

import 'package:flutter/material.dart';

import 'workbench_theme.dart';

// ---- Spacing constants internal to content primitives ----

const double _spaceXs = 4.0;
const double _spaceSm = 8.0;
const double _spaceMd = 12.0;
const double _spaceLg = 16.0;
const Radius _radius = Radius.circular(4);
const BorderRadius _borderRadius = BorderRadius.all(_radius);

/// Top-level grouping inside a sidebar or panel. Renders [title]
/// using [WorkbenchTheme.sectionTitleStyle] with an optional info
/// tooltip icon.
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
            Expanded(child: Text(title, style: theme.sectionTitleStyle)),
            if (infoTooltip != null) ...[
              const SizedBox(width: _spaceSm),
              Tooltip(
                message: infoTooltip!,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.descriptionForeground,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: _spaceMd),
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
        const SizedBox(height: _spaceSm),
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
    this.padding = const EdgeInsets.all(_spaceMd),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: theme.borderColor)),
        borderRadius: _borderRadius,
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
    this.padding = const EdgeInsets.all(_spaceMd),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(BorderSide(color: theme.borderColor)),
        borderRadius: _borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 16,
                child: FittedBox(
                  child: Switch(
                    value: enabled,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: _spaceSm),
              Expanded(child: Text(title, style: theme.subsectionTitleStyle)),
            ],
          ),
          const SizedBox(height: _spaceSm),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(opacity: enabled ? 1.0 : 0.4, child: child),
          ),
        ],
      ),
    );
  }
}

/// Label + text input with consistent decoration and optional helper
/// text. Controller-based to match the rest of the app's idiom.
class WorkbenchTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hintText;
  final String? helperText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const WorkbenchTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hintText,
    this.helperText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: theme.borderColor),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.bodyStyle),
        const SizedBox(height: _spaceXs),
        TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: theme.bodyStyle,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: theme.inputBackground,
            hintText: hintText,
            hintStyle: theme.helperStyle,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: _spaceSm,
              vertical: _spaceSm,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.focusBorderColor),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: _spaceXs),
          Text(helperText!, style: theme.helperStyle),
        ],
      ],
    );
  }
}

/// Entry for a [WorkbenchDropdown].
class WorkbenchDropdownItem<T> {
  final T value;
  final String label;
  const WorkbenchDropdownItem({required this.value, required this.label});
}

/// Label + bordered dropdown with consistent decoration.
class WorkbenchDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<WorkbenchDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? helperText;

  const WorkbenchDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    final border = OutlineInputBorder(
      borderSide: BorderSide(color: theme.borderColor),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.bodyStyle),
        const SizedBox(height: _spaceXs),
        DropdownButtonFormField<T>(
          initialValue: value,
          style: theme.bodyStyle,
          dropdownColor: theme.inputBackground,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: theme.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: _spaceSm,
              vertical: _spaceSm,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.focusBorderColor),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item.value,
                  child: Text(item.label, style: theme.bodyStyle),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
        if (helperText != null) ...[
          const SizedBox(height: _spaceXs),
          Text(helperText!, style: theme.helperStyle),
        ],
      ],
    );
  }
}

/// Label + optional description + switch row.
class WorkbenchToggle extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const WorkbenchToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.bodyStyle),
              if (description != null) ...[
                const SizedBox(height: _spaceXs),
                Text(description!, style: theme.helperStyle),
              ],
            ],
          ),
        ),
        const SizedBox(width: _spaceSm),
        SizedBox(
          width: 28,
          height: 16,
          child: FittedBox(
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon + label button with consistent border and padding.
class WorkbenchActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onPressed;

  const WorkbenchActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: _spaceMd,
          vertical: _spaceSm,
        ),
        side: BorderSide(color: theme.borderColor),
        shape: const RoundedRectangleBorder(borderRadius: _borderRadius),
        textStyle: theme.bodyStyle,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: _spaceXs),
          ],
          Text(label, style: theme.bodyStyle),
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
        padding: const EdgeInsets.all(_spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: theme.descriptionForeground),
            const SizedBox(height: _spaceMd),
            Text(
              title,
              style: theme.sectionTitleStyle,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: _spaceXs),
              Text(
                subtitle!,
                style: theme.helperStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: _spaceMd), action!],
          ],
        ),
      ),
    );
  }
}

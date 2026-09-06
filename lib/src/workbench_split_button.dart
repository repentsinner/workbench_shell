import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'layout_constants.dart';
import 'workbench_theme.dart';
import 'workbench_view_menu.dart';

/// Vertical inset of the separator pipe inside the control
/// (`button.css`: `.monaco-button-dropdown-separator { padding: 4px 0 }`).
const double _separatorInset = WorkbenchLayoutConstants.spacingSize40;

/// Width of the pipe itself (`.monaco-button-dropdown-separator > div`).
const double _separatorWidth = WorkbenchLayoutConstants.strokeThickness;

/// Shape of each half. Canon rounds only the control's outer corners —
/// the primary its left pair, the disclosure its right — so the two read as
/// one control (`button.css`: `border-radius: 4px 0 0 4px` / `0 4px 4px 0`).
/// Hoisted as constants: the halves rebuild on every menu toggle, and these
/// carry no runtime input.
const WidgetStatePropertyAll<OutlinedBorder> _primaryShape =
    WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(WorkbenchLayoutConstants.cornerRadiusSmall),
          bottomLeft: Radius.circular(
            WorkbenchLayoutConstants.cornerRadiusSmall,
          ),
        ),
      ),
    );

const WidgetStatePropertyAll<OutlinedBorder> _disclosureShape =
    WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(WorkbenchLayoutConstants.cornerRadiusSmall),
          bottomRight: Radius.circular(
            WorkbenchLayoutConstants.cornerRadiusSmall,
          ),
        ),
      ),
    );

const WidgetStatePropertyAll<EdgeInsetsGeometry> _primaryPadding =
    WidgetStatePropertyAll(WorkbenchLayoutConstants.buttonPadding);

const WidgetStatePropertyAll<EdgeInsetsGeometry> _disclosurePaddingProperty =
    WidgetStatePropertyAll(_disclosurePadding);

/// Horizontal padding of the disclosure half
/// (`.monaco-dropdown-button { padding: 0 4px }`).
const EdgeInsets _disclosurePadding = EdgeInsets.symmetric(
  horizontal: WorkbenchLayoutConstants.spacingSize40,
);

/// Dim applied to the whole control when it is disabled
/// (`.monaco-button-dropdown.disabled` — one rule covering both halves and
/// the separator, so they dim together rather than independently).
const double _disabledOpacity = 0.4;

/// The disclosure half's title, from `button.ts`
/// (`localize('button dropdown more actions', 'More Actions...')`).
const String _disclosureTooltip = 'More Actions...';

/// VS Code's split button — a primary action, a hairline pipe, and a
/// disclosure that opens a menu of related actions (§spec:split-button).
/// Upstream's `ButtonWithDropdown`
/// ([`button.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/base/browser/ui/button/button.ts)),
/// the control the Commit and Run/Debug buttons are built from.
///
/// The shell owns this one control because Flutter ships no equivalent, so
/// the chrome has nothing to theme (§spec:form-controls-not-owned). It is
/// **one** control, not two buttons in a row: the halves share a single outer
/// outline, drop the stroke where they meet, and dim together when disabled.
///
/// Colours, radii and metrics come from the ambient [WorkbenchTheme] — a host
/// supplies none, and a theme switch moves the control with the rest of the
/// chrome. The primary tier paints the `button.*` family; [secondary] paints
/// `button.secondary*`.
///
/// The disclosure opens the shell's own menu surface — the one the View menu
/// and the view-container title overflow use (§spec:menu-model) — so a host
/// gets one menu treatment across the workbench. Its rows are
/// [WorkbenchMenuEntry] descriptors, dispatched through the host's registered
/// `Action<Intent>` like every other shell menu.
///
/// Passing a null [onPressed] disables the control.
class WorkbenchSplitButton extends StatefulWidget {
  /// Label on the primary half, and on the menu's first row when
  /// [addPrimaryActionToDropdown] is set.
  final String label;

  /// The default action. Null disables the whole control — both halves and
  /// the pipe, as upstream's `enabled` setter does.
  final VoidCallback? onPressed;

  /// The related actions the disclosure lists, below the primary action.
  final List<WorkbenchMenuEntry> actions;

  /// Whether the control paints the `button.secondary*` tier.
  final bool secondary;

  /// Whether the menu carries [label] as its first row. Upstream prepends the
  /// primary action unless the caller opts out, so a pointer that has reached
  /// the menu can still invoke the default without closing it and re-aiming.
  final bool addPrimaryActionToDropdown;

  const WorkbenchSplitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.actions,
    this.secondary = false,
    this.addPrimaryActionToDropdown = true,
  });

  @override
  State<WorkbenchSplitButton> createState() => _WorkbenchSplitButtonState();
}

class _WorkbenchSplitButtonState extends State<WorkbenchSplitButton> {
  /// Mirrors the menu's open state onto the disclosure's semantics, as
  /// upstream mirrors it onto `aria-expanded`.
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    final enabled = widget.onPressed != null;
    final fill = widget.secondary
        ? theme.buttonSecondaryBackground
        : theme.buttonBackground;
    final hoverFill = widget.secondary
        ? theme.buttonSecondaryHoverBackground
        : theme.buttonHoverBackground;
    final foreground = widget.secondary
        ? theme.buttonSecondaryForeground
        : theme.buttonForeground;
    // Both halves take one tier stroke, so the control reads as a single
    // outline (`button.css`: `.monaco-text-button.secondary` and
    // `.monaco-dropdown-button.secondary` both take `button.secondaryBorder`).
    final outline = widget.secondary
        ? theme.buttonSecondaryBorder
        : theme.buttonBorder;

    final control = SizedBox(
      height: WorkbenchLayoutConstants.buttonHeight,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: WorkbenchLayoutConstants.controlsRadius,
          // Width is left to Flutter's default, which equals
          // [WorkbenchLayoutConstants.strokeThickness]; stating it trips
          // `avoid_redundant_argument_values`.
          border: Border.all(color: outline),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final primary = _buildPrimary(
              theme: theme,
              fill: fill,
              hoverFill: hoverFill,
              foreground: foreground,
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // `.monaco-text-button` is `width: 100%`, so the primary half
                // absorbs an allocation the host has already sized. Under a
                // loose constraint the control shrink-wraps its label instead.
                if (constraints.hasTightWidth)
                  Expanded(child: primary)
                else
                  primary,
                _buildSeparator(theme: theme, fill: fill),
                _buildDisclosure(
                  theme: theme,
                  fill: fill,
                  hoverFill: hoverFill,
                  foreground: foreground,
                ),
              ],
            );
          },
        ),
      ),
    );

    // One dim over the whole control, so the halves and the pipe fade
    // together rather than each resolving its own disabled treatment.
    return enabled
        ? control
        : Opacity(opacity: _disabledOpacity, child: control);
  }

  Widget _buildPrimary({
    required WorkbenchTheme theme,
    required Color fill,
    required Color hoverFill,
    required Color foreground,
  }) {
    return FilledButton(
      style: _halfStyle(
        theme: theme,
        fill: fill,
        hoverFill: hoverFill,
        foreground: foreground,
        // Rounds its left corners only; the disclosure rounds the right.
        shape: _primaryShape,
        padding: _primaryPadding,
      ),
      onPressed: widget.onPressed,
      child: Text(widget.label),
    );
  }

  /// The pipe and the fill it sits in: a `button.separator` rule inset from
  /// the top and bottom edges, over the tier's own background, so the seam
  /// reads as a rule inside one control rather than as a border between two.
  Widget _buildSeparator({
    required WorkbenchTheme theme,
    required Color fill,
  }) {
    return ColoredBox(
      color: fill,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: _separatorInset),
        child: SizedBox(
          width: _separatorWidth,
          child: ColoredBox(color: theme.buttonSeparator),
        ),
      ),
    );
  }

  Widget _buildDisclosure({
    required WorkbenchTheme theme,
    required Color fill,
    required Color hoverFill,
    required Color foreground,
  }) {
    final enabled = widget.onPressed != null;
    return Theme(
      data: workbenchMenuThemeData(context),
      child: MenuAnchor(
        onOpen: () => setState(() => _menuOpen = true),
        onClose: () => setState(() => _menuOpen = false),
        menuChildren: [
          if (widget.addPrimaryActionToDropdown)
            MenuItemButton(
              onPressed: widget.onPressed,
              child: Text(widget.label),
            ),
          ...buildMaterialMenuChildren(context, widget.actions),
        ],
        builder: (context, controller, child) => Semantics(
          expanded: _menuOpen,
          child: Tooltip(
            message: _disclosureTooltip,
            child: FilledButton(
              style: _halfStyle(
                theme: theme,
                fill: fill,
                hoverFill: hoverFill,
                foreground: foreground,
                shape: _disclosureShape,
                padding: _disclosurePaddingProperty,
              ),
              onPressed: enabled
                  ? () => controller.isOpen
                        ? controller.close()
                        : controller.open()
                  : null,
              child: const Icon(
                Symbols.expand_more_rounded,
                size: WorkbenchLayoutConstants.iconMd,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Styling shared by the two halves. Every value is pinned from
  /// [WorkbenchTheme], so the control renders the same whether or not the
  /// host composed `applyWorkbenchChrome` onto its `ThemeData`.
  ///
  /// The halves carry no stroke of their own: the outline is drawn once
  /// around both, which is how upstream avoids a doubled stroke at the seam
  /// (it drops the primary's right border and the disclosure's left).
  ///
  /// Disabled resolves the resting colours rather than Material's disabled
  /// pair — the single [Opacity] over the control supplies the dim.
  ButtonStyle _halfStyle({
    required WorkbenchTheme theme,
    required Color fill,
    required Color hoverFill,
    required Color foreground,
    required WidgetStatePropertyAll<OutlinedBorder> shape,
    required WidgetStatePropertyAll<EdgeInsetsGeometry> padding,
  }) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => _isHovered(states) ? hoverFill : fill,
      ),
      foregroundColor: WidgetStatePropertyAll(foreground),
      iconColor: WidgetStatePropertyAll(foreground),
      // The tokens are the whole story; a Material state layer over them
      // would tint a colour upstream paints flat.
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      side: const WidgetStatePropertyAll(BorderSide.none),
      shape: shape,
      padding: padding,
      textStyle: WidgetStatePropertyAll(theme.buttonTextStyle),
      // The control fixes its own height; a Material minimum would fight the
      // row it is stretched into.
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Whether a half paints its hover fill. `button.ts` moves to the hover
/// background on pointer-over and, for the same feedback, on focus.
bool _isHovered(Set<WidgetState> states) =>
    states.contains(WidgetState.hovered) ||
    states.contains(WidgetState.focused);

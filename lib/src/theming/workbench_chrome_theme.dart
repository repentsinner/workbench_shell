import 'package:flutter/material.dart';

import '../layout_constants.dart';
import '../workbench_theme.dart';
import '../workbench_view_menu.dart';

/// Compose the workbench chrome's Material theming onto a host's
/// [base] [ThemeData].
///
/// `workbench_shell` does not merely expose chrome tokens — it
/// **applies** them. This helper returns a [ThemeData] that carries:
///
/// - the [chrome] [WorkbenchTheme] as a [ThemeExtension], replacing any
///   stale [WorkbenchTheme] already on [base] while keeping every other
///   host extension (e.g. a domain theme) intact;
/// - VS Code's three flat button tiers, all de-pilled to
///   [WorkbenchLayoutConstants.buttonShape] (4px rectangle) and sized to
///   VS Code's compact [WorkbenchLayoutConstants.buttonHeight]:
///   - [FilledButton] (primary): fill `button.background`, label
///     `button.foreground`, via the `primary` / `onPrimary` roles;
///   - [FilledButton.tonal] (secondary): fill `button.secondaryBackground`,
///     label `button.secondaryForeground`, via the `secondaryContainer` /
///     `onSecondaryContainer` roles;
///   - [TextButton] (text / link): label the link accent.
/// - a [SegmentedButtonThemeData] for the single-select jog selectors
///   (mode toggle, distance ladders, percent), inheriting the same 4px
///   shape and compact height with a **neutral** selected-segment fill
///   (`button.secondaryBackground`) that reads as "chosen" without
///   competing with the primary-action blue (§spec:layout-constants-canon).
/// - an [IconButtonThemeData] for bare [IconButton]s, glyph color from
///   the `iconForeground` token (VS Code `icon.foreground`) at the same
///   flat compact sizing (§spec:chrome-material-theming).
/// - the menu and select family — [MenuThemeData], [MenuButtonThemeData],
///   [MenuBarThemeData] and [DropdownMenuThemeData] — so a host's stock
///   [MenuAnchor] and [DropdownMenu] read the `menu.*` and `dropdown.*`
///   token families without per-widget wiring.
///
/// All three are flat — elevation pinned to 0 across every state. The
/// helper keeps [FilledButton]'s hover/pressed state-layer *overlay* (the
/// color highlight) but drops its 1dp hover *elevation*: that elevation
/// renders the button through a PhysicalShape, which paints a transparent
/// resting fill as opaque black, flashing black on the un-hover
/// animation in themes whose secondary fill is transparent. Flat-always
/// removes the flash and matches VS Code, which never elevates buttons.
/// Hover colour is left to FilledButton — not a pixel-perfect VS Code
/// hover recreation. The border is transparent in themes that
/// omit `button.border`; modern themes (Dark Modern, Dark 2026) set a
/// transparent secondary fill and rely on the border to keep the
/// secondary tier visible.
///
/// Resting fills are driven through **color-scheme roles**, not an
/// explicit `backgroundColor` on a button theme. A single shared
/// [FilledButtonThemeData] styles both [FilledButton] and its
/// `.tonal` variant, so an explicit `backgroundColor` there would
/// collapse the two tiers to one fill. Instead the helper points the
/// `primary` role at `button.background` (which [FilledButton] reads)
/// and the `secondaryContainer` role at `button.secondaryBackground`
/// (which [FilledButton.tonal] reads), so the variants render distinct
/// fills from one composable call. The shared theme carries only shape
/// and size — properties both tiers share.
///
/// The helper **composes onto** [base] rather than replacing it: the
/// host keeps its own brightness and domain widget themes while
/// inheriting VS Code chrome. It does repurpose the `primary` /
/// `onPrimary` color-scheme roles to the button accent, so other
/// primary-driven Material controls (switches, sliders, focus rings)
/// adopt the VS Code accent — the coherent mapping for a VS Code chrome.
/// A host obtains VS Code Material theming with one call instead of
/// hand-wiring each widget theme. See SPEC §spec:chrome-material-theming.
///
/// Extensible by design: button theming and shape are the first Material
/// surfaces the chrome owns. Input decoration and other surfaces can be
/// added here later without changing call sites.
ThemeData applyWorkbenchChrome(ThemeData base, WorkbenchTheme chrome) {
  // Drop any prior WorkbenchTheme, keep all other host extensions,
  // then install the supplied chrome theme.
  final extensions = [
    ...base.extensions.values.where((e) => e is! WorkbenchTheme),
    chrome,
  ];

  // Compact, flat sizing shared by every button tier — VS Code height
  // and shape, without Material's 48px touch target.
  const buttonShape = WorkbenchLayoutConstants.buttonShape;
  const buttonMinSize = Size(0, WorkbenchLayoutConstants.buttonHeight);
  const buttonPadding = WorkbenchLayoutConstants.buttonPadding;

  // The popup panel the shell's own menus paint (§spec:menu-model). The
  // select's open list derives from it below, so both popup surfaces share
  // one elevation, shape and surface tint and differ only in the token
  // family they fill from.
  final menuPanelStyle = workbenchMenuPanelStyle(chrome);

  // Select trigger hairline. `dropdown.border` chains to
  // `dropdown.background` in dark themes, so an unstyled dark theme draws
  // a hairline the colour of the fill — invisible, exactly as upstream
  // renders it. VS Code draws no distinct focus border on the select
  // trigger (`selectBox.css` styles only radius and cursor; the focus ring
  // lives on the open list's rows), so every state takes one side.
  //
  // The corner radius is the controls tier VS Code gives the select
  // (`selectBox.css`: `--vscode-cornerRadius-small`), which
  // [OutlineInputBorder] already defaults to; a test pins the two together
  // so a change to the tier cannot drift this border away from it.
  final dropdownBorder = OutlineInputBorder(
    borderSide: BorderSide(color: chrome.dropdownBorder),
  );

  return base.copyWith(
    extensions: extensions,
    // Drive both filled tiers through color-scheme roles: FilledButton
    // reads primary/onPrimary, FilledButton.tonal reads
    // secondaryContainer/onSecondaryContainer. A shared
    // FilledButtonThemeData cannot give them different fills, so an
    // explicit backgroundColor would collapse the two tiers.
    colorScheme: base.colorScheme.copyWith(
      primary: chrome.buttonBackground,
      onPrimary: chrome.buttonForeground,
      secondaryContainer: chrome.buttonSecondaryBackground,
      onSecondaryContainer: chrome.buttonSecondaryForeground,
    ),
    // Filled tiers: shape, compact size, and the VS Code button border.
    // Fill comes from the color-scheme roles above; the hover/pressed
    // state-layer overlay is left to FilledButton. The border is
    // transparent in themes without `button.border`; in modern themes
    // (Dark Modern, Dark 2026) it is what keeps the secondary tier —
    // transparent-filled at rest — visible.
    //
    // Elevation is pinned to 0 across all states. FilledButton's default
    // 1dp hover elevation renders the button through a PhysicalShape,
    // which paints a transparent fill (modern themes' resting secondary
    // background) as opaque black — a black flash on the un-hover
    // elevation animation. Flat-always removes it, and VS Code buttons
    // never elevate regardless.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        shape: buttonShape,
        side: BorderSide(color: chrome.buttonBorder),
        textStyle: chrome.buttonTextStyle,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    // Text / link tier: link accent label, 4px corners, compact size.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: chrome.accentForeground,
        shape: buttonShape,
        textStyle: chrome.buttonTextStyle,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    // Single-select segmented control — the jog mode toggle, distance
    // ladders, and percent selector (§spec:layout-constants-canon). The control inherits the
    // same 4px shape, compact height, and text style as the button
    // tiers so the dense ladders stay aligned with the rest of the
    // chrome.
    //
    // The selected segment fills with the **neutral** secondary token
    // (`button.secondaryBackground`), NOT the primary-action blue
    // (`button.background`). Driving the selected fill from the primary
    // accent — as the old `jogButtonStyle(selected: true)` did via
    // `focusBorder` — makes "this option is chosen" compete with "this
    // is the primary action": two blues, one meaning. The neutral fill
    // reads as a selection highlight without that collision (§spec:chrome-material-theming).
    // Call sites suppress the default checkmark (`showSelectedIcon:
    // false`) so the 5-up ladders aren't crowded.
    // Single-select jog selectors (§spec:chrome-material-theming). The selected segment uses VS
    // Code's active-toggle treatment — a subtle accent tint plus a solid
    // accent border (`inputOption.active*`) — an *active* colour distinct
    // from both the primary-action fill and a dimmed-disabled segment.
    // Disabled segments dim their label (descriptionForeground) so a
    // capped distance reads clearly as unavailable, not merely unselected.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? chrome.inputOptionActiveBackground
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? chrome.descriptionForeground
              : chrome.foreground,
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: chrome.inputOptionActiveBorder)
              : BorderSide(color: chrome.panelBorderOrTransparent),
        ),
        shape: const WidgetStatePropertyAll(buttonShape),
        textStyle: WidgetStatePropertyAll(chrome.buttonTextStyle),
        minimumSize: const WidgetStatePropertyAll(buttonMinSize),
        // Dense ladders pack 5–6 segments across a sidebar (jog distances,
        // the G54–G59 WCS row). Flutter's default segment padding is sized
        // for a handful of wide segments and squeezes a 6-up cell below its
        // label width, wrapping "G54" to two lines. A tight horizontal pad
        // keeps short labels single-line; the equal-width distribution and
        // [buttonMinSize] still give every segment a comfortable tap target.
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(
            horizontal: WorkbenchLayoutConstants.spacingSize40,
          ),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    // Bare IconButton — glyph color from the dedicated iconForeground
    // token (VS Code icon.foreground), at the shared flat compact sizing.
    // Without this, an IconButton placed under the chrome falls back to
    // the host base ThemeData's onSurfaceVariant — a role the chrome
    // leaves unset, rendering the glyph near-invisible against the chrome
    // background (§spec:chrome-material-theming). Hover is left to Material's default IconButton
    // state-layer overlay, matching VS Code, which signals icon-button
    // hover with a background, not a foreground shift.
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: chrome.iconForeground,
        shape: buttonShape,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
    // Popup menu panel and rows, from the `menu.*` family. These are the
    // same builders the shell's own popups use through
    // `workbenchMenuThemeData`, so a host's bare [MenuAnchor] and the View
    // menu render identically. Both paths intentionally drive one pair of
    // builders: `workbenchMenuThemeData` themes the shell's own subtree
    // whether or not the host called this helper, and this helper reaches
    // the host's own menus, which that subtree never wraps.
    menuTheme: MenuThemeData(style: menuPanelStyle),
    menuButtonTheme: MenuButtonThemeData(
      style: workbenchMenuButtonStyle(chrome),
    ),
    // A host's own bare [MenuBar] strip. Flutter exposes no
    // `SubmenuButtonTheme`: a menu bar's top-level [SubmenuButton]s resolve
    // through [MenuButtonTheme], the same theme that carries popup-row
    // styling, so installing rows globally already lands `menu.*` on the
    // strip's buttons. Leaving the strip's own panel at Material's surface
    // would then be exactly the partial coverage the parity invariant
    // forbids (§spec:chrome-material-theming), so the chrome paints it from
    // the `menubar.*` family it belongs to. The shell's own strip goes one
    // better and overrides its buttons with a widget-level style, which a
    // host can do too; a theme alone cannot separate the two roles.
    menuBarTheme: MenuBarThemeData(style: workbenchMenuBarStyle(chrome)),
    // Select (§spec:chrome-material-theming). The trigger is a text field:
    // its fill, hairline and height come from a decoration theme scoped to
    // [DropdownMenu] rather than from `ThemeData.inputDecorationTheme`,
    // which would repaint every text field in the host app with the select
    // family.
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: chrome.helperStyle.copyWith(color: chrome.dropdownForeground),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: chrome.dropdownBackground,
        // Flat: no Material hover or focus tint over the VS Code fill.
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        isDense: true,
        constraints: const BoxConstraints(
          minHeight: WorkbenchLayoutConstants.buttonHeight,
        ),
        contentPadding: buttonPadding,
        border: dropdownBorder,
        enabledBorder: dropdownBorder,
        focusedBorder: dropdownBorder,
        disabledBorder: dropdownBorder,
        hintStyle: chrome.helperStyle.copyWith(
          color: chrome.descriptionForeground,
        ),
        labelStyle: chrome.helperStyle.copyWith(
          color: chrome.dropdownForeground,
        ),
      ),
      // The open list. `dropdown.listBackground` registers null outside
      // high contrast and upstream paints the list with that token
      // defaulted to the trigger fill, so the token already resolves
      // through `dropdown.background` — the list never falls through to
      // Material's surface. Rows come from the [MenuButtonTheme] above, so
      // the select's list and a popup menu share one row height.
      menuStyle: menuPanelStyle.copyWith(
        backgroundColor: WidgetStatePropertyAll(chrome.dropdownListBackground),
        side: WidgetStatePropertyAll(BorderSide(color: chrome.dropdownBorder)),
      ),
    ),
  );
}

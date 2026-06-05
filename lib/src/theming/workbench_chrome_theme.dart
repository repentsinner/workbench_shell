import 'package:flutter/material.dart';

import '../layout_constants.dart';
import '../workbench_theme.dart';

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
///
/// All three are flat — elevation pinned to 0 across every state. The
/// helper keeps [FilledButton]'s hover/pressed state-layer *overlay* (the
/// color highlight) but drops its 1dp hover *elevation*: that elevation
/// renders the button through a PhysicalShape, which paints a transparent
/// resting fill as opaque black, flashing black on the un-hover
/// animation in themes whose secondary fill is transparent. Flat-always
/// removes the flash and matches VS Code, which never elevates buttons.
/// Hover colour is left to FilledButton — not a pixel-perfect VS Code
/// hover recreation (§9.20). The border is transparent in themes that
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
/// hand-wiring each widget theme. See SPEC §9.20.
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
  );
}

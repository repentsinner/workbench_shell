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
/// - Elevated/Outlined/Text button themes whose shape is
///   [WorkbenchLayoutConstants.buttonShape] (VS Code's rectangular
///   4px corners), de-pilling Material 3's default [StadiumBorder].
///
/// The helper **composes onto** [base] rather than replacing it: the
/// host keeps its own color scheme, brightness, and domain widget
/// themes while inheriting VS Code chrome. A host obtains VS Code
/// Material theming with one call instead of hand-wiring each widget
/// theme. See SPEC §9.19.
///
/// Extensible by design: button shape is the first Material surface
/// the chrome owns. Input decoration and other surfaces can be added
/// here later without changing call sites.
ThemeData applyWorkbenchChrome(ThemeData base, WorkbenchTheme chrome) {
  // Drop any prior WorkbenchTheme, keep all other host extensions,
  // then install the supplied chrome theme.
  final extensions = [
    ...base.extensions.values.where((e) => e is! WorkbenchTheme),
    chrome,
  ];

  return base.copyWith(
    extensions: extensions,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: WorkbenchLayoutConstants.buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: WorkbenchLayoutConstants.buttonShape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: WorkbenchLayoutConstants.buttonShape),
    ),
  );
}

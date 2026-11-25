import 'package:material_ui/material_ui.dart';

import '../workbench_theme.dart';

/// The hover VS Code paints on a toolbar action, as a [ButtonStyle] layer
/// for an [IconButton] whose glyph is [foreground].
///
/// A hovered button fills `toolbar.hoverBackground` with no state layer
/// over it (workbench `style.css`). Press and focus keep the overlay
/// [IconButton.styleFrom] derives from [foreground]. The chrome's
/// `iconButtonTheme` and the shell's own icon buttons share this layer, so
/// a shell button hovers to canon even under a host theme the chrome never
/// composed onto (§spec:hover-canon).
ButtonStyle toolbarHoverStyle(
  WorkbenchTheme chrome, {
  required Color foreground,
}) {
  final pressOverlay = IconButton.styleFrom(
    foregroundColor: foreground,
  ).overlayColor;
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered)
          ? chrome.toolbarHoverBackground
          : null,
    ),
    overlayColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.hovered) &&
              !states.contains(WidgetState.pressed)
          ? const Color(0x00000000)
          : pressOverlay?.resolve(states),
    ),
  );
}

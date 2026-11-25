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
  return ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.hovered)
          ? chrome.toolbarHoverBackground
          : null,
    ),
    overlayColor: withoutHoverLayer(
      IconButton.styleFrom(foregroundColor: foreground).overlayColor,
    ),
  );
}

/// [overlay] with its hover state layer dropped.
///
/// VS Code paints hover as a token, a fill or a label colour, never as a
/// translucent layer over the control (§spec:hover-canon). A hover that is
/// not also a press therefore resolves transparent, and every other state
/// keeps [overlay]'s value, so a press still reads.
WidgetStateProperty<Color?> withoutHoverLayer(
  WidgetStateProperty<Color?>? overlay,
) {
  return WidgetStateProperty.resolveWith(
    (states) =>
        states.contains(WidgetState.hovered) &&
            !states.contains(WidgetState.pressed)
        ? Colors.transparent
        : overlay?.resolve(states),
  );
}

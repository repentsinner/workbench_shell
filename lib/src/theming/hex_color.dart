import 'package:flutter/painting.dart';

/// Parse a VS Code hex color string: `#RRGGBB` or `#RRGGBBAA`.
///
/// VS Code writes `#RRGGBBAA`; Dart's [Color] expects `0xAARRGGBB`, so
/// the alpha byte moves to the high byte. Returns `null` for null or
/// structurally invalid input.
Color? parseVscodeHexColor(String? hex) {
  if (hex == null || !hex.startsWith('#')) return null;
  final stripped = hex.substring(1);
  switch (stripped.length) {
    case 6:
      final value = int.tryParse(stripped, radix: 16);
      if (value == null) return null;
      return Color(0xFF000000 | value);
    case 8:
      final rgb = int.tryParse(stripped.substring(0, 6), radix: 16);
      final alpha = int.tryParse(stripped.substring(6, 8), radix: 16);
      if (rgb == null || alpha == null) return null;
      return Color((alpha << 24) | rgb);
    default:
      return null;
  }
}

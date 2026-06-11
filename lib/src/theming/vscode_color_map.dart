import 'dart:convert';

import 'package:flutter/services.dart';

import 'hex_color.dart';
import 'token_theme.dart';

/// Parsed representation of a VS Code color theme JSON file.
///
/// Contains the theme metadata, a flat map of workbench color tokens
/// to [Color] values, and a [TokenTheme] for syntax highlighting.
/// Unspecified tokens are filled with defaults computed from the
/// [baseType] (`vs-dark` or `vs`).
class VscodeColorMap {
  /// Theme display name (e.g. "Dark Modern").
  final String name;

  /// Base theme type: `vs-dark` for dark themes, `vs` for light themes.
  final String baseType;

  /// Flat map of VS Code color token names to resolved [Color] values.
  ///
  /// Includes both explicitly specified tokens and computed defaults.
  final Map<String, Color> colors;

  /// Token theme for syntax highlighting, parsed from `tokenColors`.
  ///
  /// Null when constructed with defaults (e.g. in tests or fallback paths).
  /// Use [resolvedTokenTheme] to get a non-null theme with sensible defaults.
  final TokenTheme? tokenTheme;

  const VscodeColorMap({
    required this.name,
    required this.baseType,
    required this.colors,
    this.tokenTheme,
  });

  /// Token theme, falling back to an empty theme using editor foreground.
  TokenTheme get resolvedTokenTheme =>
      tokenTheme ??
      TokenTheme.empty(
        defaultForeground:
            colors['editor.foreground'] ??
            colors['foreground'] ??
            (isDark ? const Color(0xFFCCCCCC) : const Color(0xFF000000)),
      );

  /// Whether this is a dark theme.
  bool get isDark => baseType == 'vs-dark';

  /// Look up a color token, returning `null` if absent.
  Color? operator [](String token) => colors[token];

  /// Look up a color token with a fallback.
  Color resolve(String token, Color fallback) => colors[token] ?? fallback;
}

/// Parses VS Code color theme JSON into a [VscodeColorMap].
///
/// Handles `#RRGGBB` and `#RRGGBBAA` hex formats. Computes defaults for
/// unspecified tokens based on the `type` field (`vs-dark` or `vs`).
class VscodeColorThemeLoader {
  const VscodeColorThemeLoader();

  /// Load a bundled theme asset by filename (e.g. `dark_modern.json`).
  ///
  /// Assets ship with the `workbench_shell` package at
  /// `assets/themes/`. Flutter rewrites package assets to
  /// `packages/workbench_shell/assets/themes/<filename>` at runtime.
  Future<VscodeColorMap> loadAsset(String filename) async {
    final jsonStr = await rootBundle.loadString(
      'packages/workbench_shell/assets/themes/$filename',
    );
    return parse(jsonStr);
  }

  /// Parse a VS Code color theme JSON string.
  ///
  /// Throws [FormatException] if the JSON root is not an object.
  /// Structurally invalid fields below the root (wrong-typed colors,
  /// token rules, metadata) are skipped or defaulted rather than
  /// throwing, so a single malformed entry in a community theme does
  /// not abort the whole parse.
  VscodeColorMap parse(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('theme JSON root must be an object');
    }
    return parseJson(decoded);
  }

  /// Parse a decoded JSON map.
  VscodeColorMap parseJson(Map<String, dynamic> json) {
    final nameValue = json['name'];
    final name = nameValue is String ? nameValue : 'Untitled';
    final baseType = _resolveBaseType(json);
    final colorsJson = json['colors'];

    final colors = <String, Color>{};
    if (colorsJson is Map<String, dynamic>) {
      for (final entry in colorsJson.entries) {
        final value = entry.value;
        if (value is! String) continue;
        final color = parseHexColor(value);
        if (color != null) {
          colors[entry.key] = color;
        }
      }
    }

    // Absent tokens stay absent. Consumers (primarily
    // [WorkbenchTheme.fromVscodeColorMap]) own the semantic fallback
    // chain — `sideBar.border → null`, `statusBar.foreground → #FFF`,
    // etc. — matching VS Code's color registry in
    // `src/vs/workbench/common/theme.ts`.

    final editorFg =
        colors['editor.foreground'] ??
        colors['foreground'] ??
        (baseType == 'vs-dark'
            ? const Color(0xFFCCCCCC)
            : const Color(0xFF000000));

    final tokenColorsValue = json['tokenColors'];
    final tokenColorsJson = tokenColorsValue is List<dynamic>
        ? tokenColorsValue
        : const <dynamic>[];
    final tokenTheme = TokenTheme.fromJson(
      tokenColorsJson,
      defaultForeground: editorFg,
    );

    return VscodeColorMap(
      name: name,
      baseType: baseType,
      colors: colors,
      tokenTheme: tokenTheme,
    );
  }

  /// Parse a hex color string: `#RRGGBB` or `#RRGGBBAA`.
  ///
  /// Returns `null` for invalid input. Delegates to the shared
  /// [parseVscodeHexColor].
  static Color? parseHexColor(String hex) => parseVscodeHexColor(hex);

  /// Determine the base type from the JSON.
  ///
  /// Normalizes `"dark"` → `"vs-dark"` and `"light"` → `"vs"` so
  /// community themes using short-form type values are handled.
  String _resolveBaseType(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is String) {
      if (type == 'dark' || type == 'vs-dark') return 'vs-dark';
      if (type == 'light' || type == 'vs') return 'vs';
      // Includes 'hc-black', 'hc-light' — fall through to infer
    }

    // Infer from uiTheme field (used in .vsix manifests).
    final uiTheme = json['uiTheme'];
    if (uiTheme is String) {
      if (uiTheme.contains('dark')) return 'vs-dark';
      return 'vs';
    }

    // Fallback: guess from name.
    final nameValue = json['name'];
    final name = (nameValue is String ? nameValue : '').toLowerCase();
    if (name.contains('light')) return 'vs';
    return 'vs-dark';
  }
}

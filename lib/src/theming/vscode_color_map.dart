import 'dart:convert';

import 'package:flutter/services.dart';

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
  VscodeColorMap parse(String jsonStr) {
    final Map<String, dynamic> json =
        jsonDecode(jsonStr) as Map<String, dynamic>;
    return parseJson(json);
  }

  /// Parse a decoded JSON map.
  VscodeColorMap parseJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Untitled';
    final baseType = _resolveBaseType(json);
    final colorsJson = json['colors'] as Map<String, dynamic>? ?? {};

    final colors = <String, Color>{};
    for (final entry in colorsJson.entries) {
      final color = parseHexColor(entry.value as String);
      if (color != null) {
        colors[entry.key] = color;
      }
    }

    // Apply defaults for unspecified tokens.
    final defaults = _defaultsForBaseType(baseType);
    for (final entry in defaults.entries) {
      colors.putIfAbsent(entry.key, () => entry.value);
    }

    final editorFg =
        colors['editor.foreground'] ??
        colors['foreground'] ??
        (baseType == 'vs-dark'
            ? const Color(0xFFCCCCCC)
            : const Color(0xFF000000));

    final tokenColorsJson = json['tokenColors'] as List<dynamic>? ?? [];
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
  /// Returns `null` for invalid input.
  static Color? parseHexColor(String hex) {
    if (!hex.startsWith('#')) return null;
    final stripped = hex.substring(1);
    switch (stripped.length) {
      case 6:
        final value = int.tryParse(stripped, radix: 16);
        if (value == null) return null;
        return Color(0xFF000000 | value);
      case 8:
        // VS Code uses #RRGGBBAA — Dart Color expects 0xAARRGGBB.
        final rgb = int.tryParse(stripped.substring(0, 6), radix: 16);
        final alpha = int.tryParse(stripped.substring(6, 8), radix: 16);
        if (rgb == null || alpha == null) return null;
        return Color((alpha << 24) | rgb);
      default:
        return null;
    }
  }

  /// Determine the base type from the JSON.
  ///
  /// Normalizes `"dark"` → `"vs-dark"` and `"light"` → `"vs"` so
  /// community themes using short-form type values are handled.
  String _resolveBaseType(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    if (type != null) {
      if (type == 'dark' || type == 'vs-dark') return 'vs-dark';
      if (type == 'light' || type == 'vs') return 'vs';
      // Includes 'hc-black', 'hc-light' — fall through to infer
    }

    // Infer from uiTheme field (used in .vsix manifests).
    final uiTheme = json['uiTheme'] as String?;
    if (uiTheme != null) {
      if (uiTheme.contains('dark')) return 'vs-dark';
      return 'vs';
    }

    // Fallback: guess from name.
    final name = (json['name'] as String? ?? '').toLowerCase();
    if (name.contains('light')) return 'vs';
    return 'vs-dark';
  }

  /// Default token values for dark and light base types.
  ///
  /// These match VS Code's built-in defaults for tokens that themes
  /// commonly omit. Covers the ~25 tokens that [RoveColorTheme] maps.
  static Map<String, Color> _defaultsForBaseType(String baseType) {
    if (baseType == 'vs-dark') {
      return const {
        'editor.background': Color(0xFF1E1E1E),
        'editor.foreground': Color(0xFFCCCCCC),
        'foreground': Color(0xFFCCCCCC),
        'focusBorder': Color(0xFF007ACC),
        'activityBar.background': Color(0xFF333333),
        'activityBar.foreground': Color(0xFFFFFFFF),
        'activityBar.inactiveForeground': Color(0xFF858585),
        'activityBar.border': Color(0xFF333333),
        'sideBar.background': Color(0xFF252526),
        'sideBar.foreground': Color(0xFFCCCCCC),
        'sideBar.border': Color(0xFF252526),
        'panel.background': Color(0xFF1E1E1E),
        'panel.border': Color(0xFF808080),
        'panelTitle.activeForeground': Color(0xFFCCCCCC),
        'panelTitle.inactiveForeground': Color(0xFF969696),
        'statusBar.background': Color(0xFF007ACC),
        'statusBar.foreground': Color(0xFFFFFFFF),
        'statusBar.border': Color(0xFF007ACC),
        'input.background': Color(0xFF3C3C3C),
        'input.foreground': Color(0xFFCCCCCC),
        'input.border': Color(0xFF3C3C3C),
        'input.placeholderForeground': Color(0xFF969696),
        'button.background': Color(0xFF0E639C),
        'button.foreground': Color(0xFFFFFFFF),
        'button.hoverBackground': Color(0xFF1177BB),
        'dropdown.background': Color(0xFF3C3C3C),
        'dropdown.foreground': Color(0xFFCCCCCC),
        'errorForeground': Color(0xFFF85149),
        'descriptionForeground': Color(0xFF969696),
        'tab.activeBackground': Color(0xFF1E1E1E),
        'tab.activeForeground': Color(0xFFFFFFFF),
        'tab.inactiveBackground': Color(0xFF2D2D2D),
        'tab.inactiveForeground': Color(0xFF969696),
        'tab.border': Color(0xFF252526),
      };
    }
    // Light (vs)
    return const {
      'editor.background': Color(0xFFFFFFFF),
      'editor.foreground': Color(0xFF000000),
      'foreground': Color(0xFF000000),
      'focusBorder': Color(0xFF0078D4),
      'activityBar.background': Color(0xFF2C2C2C),
      'activityBar.foreground': Color(0xFFFFFFFF),
      'activityBar.inactiveForeground': Color(0xFF858585),
      'activityBar.border': Color(0xFF2C2C2C),
      'sideBar.background': Color(0xFFF3F3F3),
      'sideBar.foreground': Color(0xFF000000),
      'sideBar.border': Color(0xFFE7E7E7),
      'panel.background': Color(0xFFFFFFFF),
      'panel.border': Color(0xFFE7E7E7),
      'panelTitle.activeForeground': Color(0xFF000000),
      'panelTitle.inactiveForeground': Color(0xFF969696),
      'statusBar.background': Color(0xFF007ACC),
      'statusBar.foreground': Color(0xFFFFFFFF),
      'statusBar.border': Color(0xFF007ACC),
      'input.background': Color(0xFFFFFFFF),
      'input.foreground': Color(0xFF000000),
      'input.border': Color(0xFFCECECE),
      'input.placeholderForeground': Color(0xFF767676),
      'button.background': Color(0xFF007ACC),
      'button.foreground': Color(0xFFFFFFFF),
      'button.hoverBackground': Color(0xFF0062A3),
      'dropdown.background': Color(0xFFFFFFFF),
      'dropdown.foreground': Color(0xFF000000),
      'errorForeground': Color(0xFFF85149),
      'descriptionForeground': Color(0xFF717171),
      'tab.activeBackground': Color(0xFFFFFFFF),
      'tab.activeForeground': Color(0xFF000000),
      'tab.inactiveBackground': Color(0xFFECECEC),
      'tab.inactiveForeground': Color(0xFF717171),
      'tab.border': Color(0xFFE7E7E7),
    };
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Visual style for a single syntax token scope.
///
/// Resolved from a VS Code theme's `tokenColors` array. Carries
/// foreground color and font style flags (bold, italic, underline,
/// strikethrough). All fields are nullable — `null` means the theme
/// did not specify a value for this property at this scope level.
class TokenStyle {
  /// Foreground text color, or null to inherit.
  final Color? foreground;

  /// Whether text is bold.
  final bool bold;

  /// Whether text is italic.
  final bool italic;

  /// Whether text is underlined.
  final bool underline;

  /// Whether text has strikethrough.
  final bool strikethrough;

  const TokenStyle({
    this.foreground,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
  });

  /// Apply this style to a [TextStyle].
  TextStyle apply(TextStyle base) {
    return base.copyWith(
      color: foreground ?? base.color,
      fontWeight: bold ? FontWeight.bold : null,
      fontStyle: italic ? FontStyle.italic : null,
      decoration: _decoration,
    );
  }

  TextDecoration? get _decoration {
    if (!underline && !strikethrough) return null;
    final decorations = <TextDecoration>[
      if (underline) TextDecoration.underline,
      if (strikethrough) TextDecoration.lineThrough,
    ];
    return TextDecoration.combine(decorations);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenStyle &&
          foreground == other.foreground &&
          bold == other.bold &&
          italic == other.italic &&
          underline == other.underline &&
          strikethrough == other.strikethrough;

  @override
  int get hashCode =>
      Object.hash(foreground, bold, italic, underline, strikethrough);

  @override
  String toString() =>
      'TokenStyle(fg: $foreground, bold: $bold, italic: $italic, '
      'underline: $underline, strikethrough: $strikethrough)';
}

/// Resolves TextMate scope strings to [TokenStyle] values.
///
/// Built from a VS Code theme's `tokenColors` array. Uses prefix
/// matching: a rule for `keyword` matches `keyword.control`, and a
/// more specific rule for `keyword.control` wins over `keyword`.
class TokenTheme {
  /// Rules sorted by scope specificity (most specific first).
  final List<_TokenRule> _rules;

  /// Default foreground color for unmatched scopes.
  final Color defaultForeground;

  TokenTheme._({
    required List<_TokenRule> rules,
    required this.defaultForeground,
  }) : _rules = rules;

  /// Parse `tokenColors` from a decoded VS Code theme JSON.
  ///
  /// [tokenColors] is the `tokenColors` array from the theme JSON.
  /// [defaultForeground] is the editor foreground color (fallback for
  /// scopes with no matching rule).
  factory TokenTheme.fromJson(
    List<dynamic> tokenColors, {
    required Color defaultForeground,
  }) {
    final rules = <_TokenRule>[];

    for (final entry in tokenColors) {
      if (entry is! Map<String, dynamic>) continue;
      final settings = entry['settings'] as Map<String, dynamic>?;
      if (settings == null) continue;

      final foreground = _parseColor(settings['foreground'] as String?);
      final fontStyle = settings['fontStyle'] as String? ?? '';
      final bold = fontStyle.contains('bold');
      final italic = fontStyle.contains('italic');
      final underline = fontStyle.contains('underline');
      final strikethrough = fontStyle.contains('strikethrough');

      final style = TokenStyle(
        foreground: foreground,
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
      );

      final scopeValue = entry['scope'];
      final scopes = <String>[];
      if (scopeValue is String) {
        // Comma-separated scope list.
        for (final s in scopeValue.split(',')) {
          final trimmed = s.trim();
          if (trimmed.isNotEmpty) scopes.add(trimmed);
        }
      } else if (scopeValue is List) {
        for (final s in scopeValue) {
          if (s is String && s.isNotEmpty) scopes.add(s);
        }
      }

      // Entries with no scope apply as a global default (scope "").
      if (scopes.isEmpty) {
        rules.add(_TokenRule('', style));
      } else {
        for (final scope in scopes) {
          rules.add(_TokenRule(scope, style));
        }
      }
    }

    // Sort by scope specificity: longer (more specific) scopes first.
    rules.sort((a, b) => b.scope.length.compareTo(a.scope.length));

    return TokenTheme._(rules: rules, defaultForeground: defaultForeground);
  }

  /// Construct an empty theme that returns [defaultForeground] for all scopes.
  factory TokenTheme.empty({required Color defaultForeground}) {
    return TokenTheme._(rules: const [], defaultForeground: defaultForeground);
  }

  /// Resolve a TextMate scope string to a [TokenStyle].
  ///
  /// Uses prefix matching: `keyword` matches `keyword.control`.
  /// The most specific (longest) matching scope wins for each property.
  TokenStyle resolve(String scope) {
    Color? foreground;
    bool? bold;
    bool? italic;
    bool? underline;
    bool? strikethrough;

    for (final rule in _rules) {
      if (!_matches(rule.scope, scope)) continue;

      // Each property resolves from the most specific rule that defines it.
      foreground ??= rule.style.foreground;
      bold ??= rule.style.bold ? true : null;
      italic ??= rule.style.italic ? true : null;
      underline ??= rule.style.underline ? true : null;
      strikethrough ??= rule.style.strikethrough ? true : null;

      // Once all properties are resolved, stop.
      if (foreground != null) break;
    }

    return TokenStyle(
      foreground: foreground ?? defaultForeground,
      bold: bold ?? false,
      italic: italic ?? false,
      underline: underline ?? false,
      strikethrough: strikethrough ?? false,
    );
  }

  /// Check if [ruleScope] matches [targetScope] via prefix matching.
  ///
  /// Empty rule scope matches everything. Otherwise, the target must
  /// equal the rule scope or start with it followed by a dot.
  static bool _matches(String ruleScope, String targetScope) {
    if (ruleScope.isEmpty) return true;
    if (targetScope == ruleScope) return true;
    return targetScope.startsWith('$ruleScope.');
  }

  /// Parse a hex color, or null for missing/invalid values.
  static Color? _parseColor(String? hex) {
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenTheme &&
          defaultForeground == other.defaultForeground &&
          listEquals(_rules, other._rules);

  @override
  int get hashCode => Object.hash(defaultForeground, Object.hashAll(_rules));
}

/// A scope → style rule from the theme's tokenColors array.
class _TokenRule {
  final String scope;
  final TokenStyle style;
  const _TokenRule(this.scope, this.style);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TokenRule && scope == other.scope && style == other.style;

  @override
  int get hashCode => Object.hash(scope, style);
}

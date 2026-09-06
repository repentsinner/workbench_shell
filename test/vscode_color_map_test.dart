import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  const loader = VscodeColorThemeLoader();

  group('VscodeColorThemeLoader.parseHexColor', () {
    test('parses #RRGGBB format', () {
      expect(
        VscodeColorThemeLoader.parseHexColor('#1F1F1F'),
        const Color(0xFF1F1F1F),
      );
    });

    test('parses #RRGGBBAA format', () {
      // #FFFFFF1A → RGBA(255,255,255, 0x1A alpha)
      // Dart Color: 0x1AFFFFFF
      expect(
        VscodeColorThemeLoader.parseHexColor('#FFFFFF1A'),
        const Color(0x1AFFFFFF),
      );
    });

    test('parses fully opaque #RRGGBBAA', () {
      expect(
        VscodeColorThemeLoader.parseHexColor('#FF0000FF'),
        const Color(0xFFFF0000),
      );
    });

    test('returns null for invalid input', () {
      expect(VscodeColorThemeLoader.parseHexColor('invalid'), isNull);
      expect(VscodeColorThemeLoader.parseHexColor('#GG0000'), isNull);
      expect(VscodeColorThemeLoader.parseHexColor('#12345'), isNull);
    });

    test('returns null for empty hash', () {
      expect(VscodeColorThemeLoader.parseHexColor('#'), isNull);
    });
  });

  group('VscodeColorThemeLoader.parse', () {
    test('parses minimal dark theme JSON', () {
      const json = '''
      {
        "name": "Test Dark",
        "type": "vs-dark",
        "colors": {
          "editor.background": "#1E1E1E",
          "editor.foreground": "#CCCCCC"
        }
      }
      ''';
      final map = loader.parse(json);

      expect(map.name, 'Test Dark');
      expect(map.baseType, 'vs-dark');
      expect(map.isDark, isTrue);
      expect(map['editor.background'], const Color(0xFF1E1E1E));
      expect(map['editor.foreground'], const Color(0xFFCCCCCC));
    });

    test('parses minimal light theme JSON', () {
      const json = '''
      {
        "name": "Test Light",
        "type": "vs",
        "colors": {
          "editor.background": "#FFFFFF"
        }
      }
      ''';
      final map = loader.parse(json);

      expect(map.name, 'Test Light');
      expect(map.baseType, 'vs');
      expect(map.isDark, isFalse);
    });

    test('absent tokens stay absent in the parsed map', () {
      // The loader records only what the theme JSON sets. Semantic
      // fallbacks live in [WorkbenchTheme.fromVscodeColorMap], not
      // in the loader — this matches VS Code's split between the
      // theme file and the color registry.
      const json = '''
      {
        "name": "Sparse",
        "type": "vs-dark",
        "colors": {}
      }
      ''';
      final map = loader.parse(json);

      expect(map['editor.background'], isNull);
      expect(map['activityBar.background'], isNull);
      expect(map['statusBar.background'], isNull);
    });

    test('explicit tokens round-trip through parse', () {
      const json = '''
      {
        "name": "Custom",
        "type": "vs-dark",
        "colors": {
          "editor.background": "#FF0000"
        }
      }
      ''';
      final map = loader.parse(json);

      expect(map['editor.background'], const Color(0xFFFF0000));
    });

    test('resolve returns fallback for missing tokens', () {
      const json = '''
      {
        "name": "Minimal",
        "type": "vs-dark",
        "colors": {}
      }
      ''';
      final map = loader.parse(json);

      expect(
        map.resolve('nonexistent.token', const Color(0xFFABCDEF)),
        const Color(0xFFABCDEF),
      );
    });

    test('infers base type from uiTheme field', () {
      const json = '''
      {
        "name": "VSIX Theme",
        "uiTheme": "vs-dark",
        "colors": {}
      }
      ''';
      final map = loader.parse(json);

      expect(map.baseType, 'vs-dark');
      expect(map.isDark, isTrue);
    });

    test('infers base type from name as fallback', () {
      const json = '''
      {
        "name": "My Light Theme",
        "colors": {}
      }
      ''';
      final map = loader.parse(json);

      expect(map.baseType, 'vs');
      expect(map.isDark, isFalse);
    });

    test('defaults to vs-dark when base type cannot be inferred', () {
      const json = '''
      {
        "name": "Ambiguous",
        "colors": {}
      }
      ''';
      final map = loader.parse(json);

      expect(map.baseType, 'vs-dark');
    });

    test('handles colors with alpha channel', () {
      const json = '''
      {
        "name": "Alpha Test",
        "type": "vs-dark",
        "colors": {
          "button.border": "#FFFFFF1A",
          "button.background": "#0078D4"
        }
      }
      ''';
      final map = loader.parse(json);

      final border = map['button.border']!;
      expect(border.a, closeTo(0x1A / 255.0, 0.01));

      final bg = map['button.background']!;
      expect(bg.a, closeTo(1.0, 0.01));
    });
  });

  group('VscodeColorThemeLoader.parse — malformed input', () {
    // A host loading community/user-supplied theme JSON must not crash
    // the app on structurally invalid input. Wrong-typed fields are
    // skipped or defaulted; only a non-object root is rejected, and with
    // a documented FormatException rather than a raw TypeError.

    test('throws FormatException (not TypeError) on a non-object root', () {
      expect(() => loader.parse('[]'), throwsFormatException);
      expect(() => loader.parse('42'), throwsFormatException);
      expect(() => loader.parse('"x"'), throwsFormatException);
    });

    test('non-string name falls back to Untitled', () {
      final map = loader.parse('{"name": 7, "type": "vs-dark", "colors": {}}');
      expect(map.name, 'Untitled');
    });

    test('non-object colors is treated as empty', () {
      final map = loader.parse('{"name": "X", "type": "vs-dark", "colors": []}');
      expect(map['editor.background'], isNull);
    });

    test('non-string color values are skipped, valid ones retained', () {
      final map = loader.parse('''
      {
        "name": "X",
        "type": "vs-dark",
        "colors": {
          "editor.foreground": 16777215,
          "editor.background": "#1E1E1E"
        }
      }''');
      expect(map['editor.foreground'], isNull);
      expect(map['editor.background'], const Color(0xFF1E1E1E));
    });

    test('non-list tokenColors is treated as empty', () {
      final map = loader.parse(
        '{"name": "X", "type": "vs-dark", "colors": {}, "tokenColors": {}}',
      );
      expect(map.tokenTheme, isNotNull);
    });

    test('non-string type field falls through to inference', () {
      final map = loader.parse(
        '{"name": "My Light", "type": 3, "colors": {}}',
      );
      expect(map.baseType, 'vs');
    });

    test('malformed token rule does not abort the parse', () {
      // A single bad rule (settings as a list, foreground as a number)
      // must not throw; valid rules in the same array still resolve.
      final map = loader.parse('''
      {
        "name": "X",
        "type": "vs-dark",
        "colors": {"editor.foreground": "#CCCCCC"},
        "tokenColors": [
          {"scope": "broken", "settings": []},
          {"scope": "number", "settings": {"foreground": 123}},
          {"scope": "comment", "settings": {"foreground": "#6A9955"}}
        ]
      }''');
      expect(
        map.resolvedTokenTheme.resolve('comment').foreground,
        const Color(0xFF6A9955),
      );
    });
  });
}

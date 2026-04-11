import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const loader = VscodeColorThemeLoader();

  group('WorkbenchTheme.hctToneFor', () {
    test('returns 0 for pure black', () {
      expect(WorkbenchTheme.hctToneFor(const Color(0xFF000000)), closeTo(0, 1));
    });

    test('returns 100 for pure white', () {
      expect(
        WorkbenchTheme.hctToneFor(const Color(0xFFFFFFFF)),
        closeTo(100, 1),
      );
    });

    test('matches Hct.fromInt(...).tone for arbitrary colors', () {
      const color = Color(0xFF1F1F1F);
      expect(
        WorkbenchTheme.hctToneFor(color),
        equals(Hct.fromInt(color.toARGB32()).tone),
      );
    });
  });

  group('WorkbenchTheme.surfaceTone', () {
    test('dark editor background yields a low tone', () {
      final map = loader.parse('''
      {
        "name": "Dark Test",
        "type": "vs-dark",
        "colors": {
          "editor.background": "#1F1F1F"
        }
      }
      ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.surfaceTone, lessThan(50));
    });

    test('light editor background yields a high tone', () {
      final map = loader.parse('''
      {
        "name": "Light Test",
        "type": "vs",
        "colors": {
          "editor.background": "#FFFFFF"
        }
      }
      ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.surfaceTone, greaterThan(50));
    });

    test('matches the HCT tone of editor.background exactly', () {
      const editorBg = Color(0xFF252526);
      final map = loader.parse('''
      {
        "name": "Spec Test",
        "type": "vs-dark",
        "colors": {
          "editor.background": "#252526"
        }
      }
      ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.surfaceTone, equals(Hct.fromInt(editorBg.toARGB32()).tone));
    });
  });

  group('WorkbenchTheme bundled assets', () {
    test(
      'every default theme produces a valid surfaceTone in [0, 100]',
      () async {
        // Verify the bundled assets all yield valid surface tones —
        // proves the field is computed regardless of theme JSON quirks.
        for (final entry in WorkbenchThemeController.defaultAvailableThemes) {
          final map = await loader.loadAsset(entry.filename);
          final theme = WorkbenchTheme.fromVscodeColorMap(map);
          expect(
            theme.surfaceTone,
            inInclusiveRange(0, 100),
            reason:
                '${entry.label} (${entry.filename}) surfaceTone should be in [0,100]',
          );
        }
      },
    );
  });

  group('WorkbenchTheme border fallbacks', () {
    // Themes like Nord and One Dark Pro set `panel.border` but omit
    // `activityBar.border` (and sometimes `sideBar.border`). The shell
    // still draws those borders, so they must fall back to a token
    // that matches the theme's palette — `panel.border` — rather than
    // to a hardcoded VS Code-ish default that clashes with non-VS
    // Code-derived palettes.
    test('activityBar.border falls back to panel.border when omitted', () {
      final map = loader.parse('''
        {
          "name": "Missing Activity Border",
          "type": "vs-dark",
          "colors": {
            "activityBar.background": "#2e3440",
            "sideBar.background": "#2e3440",
            "panel.border": "#3b4252"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.activityBarBorder, const Color(0xFF3b4252));
    });

    test('sideBar.border falls back to panel.border when omitted', () {
      final map = loader.parse('''
      {
        "name": "Missing Sidebar Border",
        "type": "vs-dark",
        "colors": {
          "panel.border": "#3b4252"
        }
      }
      ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.sideBarBorder, const Color(0xFF3b4252));
    });

    test('explicit border values are preserved over the fallback', () {
      final map = loader.parse('''
      {
        "name": "Explicit Borders",
        "type": "vs-dark",
        "colors": {
          "activityBar.border": "#112233",
          "sideBar.border": "#445566",
          "panel.border": "#778899"
        }
      }
      ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.activityBarBorder, const Color(0xFF112233));
      expect(theme.sideBarBorder, const Color(0xFF445566));
      expect(theme.panelBorder, const Color(0xFF778899));
    });
  });

  group('WorkbenchTheme.copyWith / lerp', () {
    final base = WorkbenchTheme.fromVscodeColorMap(
      const VscodeColorMap(name: 'Dark', baseType: 'vs-dark', colors: {}),
    );

    test('copyWith preserves surfaceTone when unspecified', () {
      final modified = base.copyWith(foreground: const Color(0xFFFF0000));
      expect(modified.surfaceTone, equals(base.surfaceTone));
    });

    test('copyWith overrides surfaceTone when specified', () {
      final modified = base.copyWith(surfaceTone: 42);
      expect(modified.surfaceTone, equals(42));
    });

    test('lerp interpolates surfaceTone linearly', () {
      final a = base.copyWith(surfaceTone: 0);
      final b = base.copyWith(surfaceTone: 100);
      final mid = a.lerp(b, 0.5);
      expect(mid.surfaceTone, closeTo(50, 1e-9));
    });
  });
}

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

  group('WorkbenchTheme border semantics', () {
    // VS Code's color registry treats activityBar.border and
    // sideBar.border as null by default for dark and light themes.
    // Modern themes (Dark+, Light+) omit them; Dark Modern sets them
    // explicitly. Propagate the absence as null so chrome widgets
    // skip painting instead of showing flat grey hairlines.
    test('activityBar.border resolves to null when omitted', () {
      final map = loader.parse('''
        {
          "name": "Dark+-like",
          "type": "vs-dark",
          "colors": {
            "activityBar.background": "#333333",
            "sideBar.background": "#252526",
            "editor.background": "#1E1E1E"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.activityBarBorder, isNull);
    });

    test('sideBar.border resolves to null when omitted', () {
      final map = loader.parse('''
        {
          "name": "Minimal Dark",
          "type": "vs-dark",
          "colors": {}
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.sideBarBorder, isNull);
    });

    test('panel.border resolves to translucent grey when omitted', () {
      // VS Code registry: PANEL_BORDER defaults to
      // `Color.fromHex('#808080').transparent(0.35)` → 0x59808080.
      final map = loader.parse('''
        {
          "name": "Minimal Dark",
          "type": "vs-dark",
          "colors": {}
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.panelBorder, const Color(0x59808080));
    });

    test('explicit border values are preserved', () {
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

    test('preserves alpha channel from #RRGGBBAA', () {
      // Spec §9.6: "Color tokens expressed as #RRGGBBAA retain their
      // alpha channel from parse through paint." Reject any
      // opaque-coercion downstream.
      final map = loader.parse('''
        {
          "name": "Translucent",
          "type": "vs-dark",
          "colors": {
            "panel.border": "#80808059"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.panelBorder, const Color(0x59808080));
    });
  });

  group('WorkbenchTheme border fallbacks (Plus asset)', () {
    test('Dark+ bundled theme leaves activity/side borders null', () async {
      final map = await loader.loadAsset('dark_plus.json');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.activityBarBorder, isNull);
      expect(theme.sideBarBorder, isNull);
      // panel.border absent in Dark+ too → registry default
      // (translucent grey).
      expect(theme.panelBorder, const Color(0x59808080));
      // Backgrounds come from the fromVscodeColorMap fallback chain.
      expect(theme.activityBarBackground, const Color(0xFF333333));
      expect(theme.sideBarBackground, const Color(0xFF252526));
      expect(theme.editorBackground, const Color(0xFF1E1E1E));
      expect(theme.statusBarBackground, const Color(0xFF007ACC));
    });

    test('Dark Modern sets all three border tokens explicitly', () async {
      final map = await loader.loadAsset('dark_modern.json');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.activityBarBorder, const Color(0xFF2B2B2B));
      expect(theme.sideBarBorder, const Color(0xFF2B2B2B));
      expect(theme.panelBorder, const Color(0xFF2B2B2B));
    });
  });

  group('WorkbenchTheme.statusBarTextStyle', () {
    // Primary status bar text matches the size/weight of helperStyle
    // (11pt, w400) but paints in statusBar.foreground so it reads
    // against the blue status bar background. The prior default
    // (helperStyle) used descriptionForeground and produced an
    // illegible grey on blue.
    test('uses statusBar.foreground and helperStyle metrics', () {
      final map = loader.parse('''
        {
          "name": "Dark Test",
          "type": "vs-dark",
          "colors": {
            "statusBar.foreground": "#FFFFFF",
            "descriptionForeground": "#969696"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.statusBarTextStyle.color, const Color(0xFFFFFFFF));
      expect(theme.statusBarTextStyle.fontSize, theme.helperStyle.fontSize);
      expect(theme.statusBarTextStyle.fontWeight, theme.helperStyle.fontWeight);
      // Regression guard: must not fall through to descriptionForeground.
      expect(
        theme.statusBarTextStyle.color,
        isNot(theme.descriptionForeground),
      );
    });

    test('Dark+ default resolves to white', () async {
      final map = await loader.loadAsset('dark_plus.json');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.statusBarTextStyle.color, const Color(0xFFFFFFFF));
      expect(theme.statusBarForeground, const Color(0xFFFFFFFF));
    });

    test('Dark Modern sets statusBar.foreground to #CCCCCC', () async {
      final map = await loader.loadAsset('dark_modern.json');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.statusBarTextStyle.color, const Color(0xFFCCCCCC));
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

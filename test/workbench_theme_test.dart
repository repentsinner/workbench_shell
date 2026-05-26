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

  group('WorkbenchTheme.tabBarIndicatorColor', () {
    // Active-tab underline and the inline PanelTabBadge pill share
    // VS Code's `panelTitle.activeBorder` token. Themes that omit it
    // fall back to the resolved foreground so older themes still
    // render a visible underline.
    test('resolves from panelTitle.activeBorder when defined', () {
      final map = loader.parse('''
        {
          "name": "Active Border Defined",
          "type": "vs-dark",
          "colors": {
            "panelTitle.activeBorder": "#0078D4",
            "foreground": "#CCCCCC"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.tabBarIndicatorColor, const Color(0xFF0078D4));
    });

    test('falls back to foreground when panelTitle.activeBorder absent', () {
      final map = loader.parse('''
        {
          "name": "No Active Border",
          "type": "vs-dark",
          "colors": {
            "foreground": "#CCCCCC"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.tabBarIndicatorColor, theme.foreground);
      expect(theme.tabBarIndicatorColor, const Color(0xFFCCCCCC));
    });
  });

  group('WorkbenchTheme notification tokens (§10)', () {
    test('fall back to chrome neighbours when notifications.* omitted', () {
      final map = loader.parse('''
        {
          "name": "Dark Minimal",
          "type": "vs-dark",
          "colors": {}
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      // Card background falls back through input.background.
      expect(theme.notificationBackground, theme.inputBackground);
      // Border falls back to the panel border (translucent grey).
      expect(theme.notificationBorder, theme.panelBorder);
      // Foreground/close colors mirror the chrome semantics.
      expect(theme.notificationForeground, theme.foreground);
      expect(theme.notificationCloseForeground, theme.descriptionForeground);
      // Action button reuses the chrome button accent chain.
      expect(theme.notificationActionBackground, theme.buttonBackground);
      expect(theme.notificationActionForeground, theme.buttonForeground);
      expect(
        theme.notificationActionHoverBackground,
        theme.buttonHoverBackground,
      );
      // Progress fill uses the focus accent when progressBar.background
      // is unset.
      expect(theme.notificationProgressFill, theme.focusBorder);
    });

    test('honour explicit notifications.* tokens when present', () {
      final map = loader.parse('''
        {
          "name": "Notif Test",
          "type": "vs-dark",
          "colors": {
            "notifications.background": "#112233",
            "notifications.border": "#445566",
            "notifications.foreground": "#778899",
            "notificationCenter.foreground": "#AABBCC",
            "notificationCenterHeader.background": "#DDEEFF",
            "progressBar.background": "#101010"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.notificationBackground, const Color(0xFF112233));
      expect(theme.notificationBorder, const Color(0xFF445566));
      expect(theme.notificationForeground, const Color(0xFF778899));
      expect(theme.notificationCloseForeground, const Color(0xFFAABBCC));
      expect(theme.notificationActionBackground, const Color(0xFFDDEEFF));
      expect(theme.notificationProgressFill, const Color(0xFF101010));
    });

    test('severityForeground reuses existing semantic-status tokens', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      expect(
        theme.severityForeground(NotificationSeverity.info),
        theme.infoForeground,
      );
      expect(
        theme.severityForeground(NotificationSeverity.success),
        theme.successForeground,
      );
      expect(
        theme.severityForeground(NotificationSeverity.warning),
        theme.warningForeground,
      );
      expect(
        theme.severityForeground(NotificationSeverity.error),
        theme.errorForeground,
      );
    });

    test('progress track is a translucent modulation of the border', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      // Track is dimmer than the border (alpha 0.3 fallback chain) —
      // the panel-border default has 0x59 alpha (~0.349); track
      // multiplies by 0.3 to 0x1A (~0.105).
      expect(
        theme.notificationProgressTrack.a,
        lessThan(theme.notificationBorder.a),
      );
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

    test('copyWith preserves notification tokens when unspecified', () {
      final modified = base.copyWith(foreground: const Color(0xFFFF0000));
      expect(
        modified.notificationBackground,
        equals(base.notificationBackground),
      );
      expect(modified.notificationBorder, equals(base.notificationBorder));
      expect(
        modified.notificationActionBackground,
        equals(base.notificationActionBackground),
      );
    });

    test('copyWith overrides notification tokens when specified', () {
      const accent = Color(0xFFAB1234);
      final modified = base.copyWith(notificationProgressFill: accent);
      expect(modified.notificationProgressFill, equals(accent));
      // Untouched fields keep their prior values.
      expect(
        modified.notificationBackground,
        equals(base.notificationBackground),
      );
    });

    test('lerp interpolates notification colours', () {
      final a = base.copyWith(notificationBackground: const Color(0xFF000000));
      final b = base.copyWith(notificationBackground: const Color(0xFFFFFFFF));
      final mid = a.lerp(b, 0.5);
      // Mid-grey on a linear lerp — exact midpoint depends on Flutter's
      // Color.lerp implementation, so just assert it's neither endpoint.
      expect(
        mid.notificationBackground,
        isNot(equals(a.notificationBackground)),
      );
      expect(
        mid.notificationBackground,
        isNot(equals(b.notificationBackground)),
      );
    });
  });
}

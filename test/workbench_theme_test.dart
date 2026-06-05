import 'package:flutter/foundation.dart';
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

    test('button.border resolves to transparent when omitted', () {
      // VS Code has no registry default for button.border; older themes
      // omit it and the §9.20 button border is transparent.
      final map = loader.parse('''
        {
          "name": "Minimal Dark",
          "type": "vs-dark",
          "colors": {}
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.buttonBorder, const Color(0x00000000));
    });

    test('button.border is preserved with alpha (Dark Modern case)', () {
      // Dark Modern pairs a transparent secondary fill with a translucent
      // border that keeps the secondary button visible at rest.
      final map = loader.parse('''
        {
          "name": "Modern-like",
          "type": "vs-dark",
          "colors": {
            "button.secondaryBackground": "#00000000",
            "button.border": "#ffffff1a"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.buttonSecondaryBackground, const Color(0x00000000));
      expect(theme.buttonBorder, const Color(0x1AFFFFFF));
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
    // (12pt, w400 per §7.6) but paints in statusBar.foreground so it
    // reads against the blue status bar background. The prior default
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

  group('WorkbenchTheme secondary button tokens (§9.20)', () {
    test('fall back to neutral surfaces when button.secondary* omitted', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      // VS Code registry: button.secondaryBackground defaults to
      // list.hoverBackground; button.secondaryForeground to foreground.
      expect(theme.buttonSecondaryBackground, theme.listHoverBackground);
      expect(theme.buttonSecondaryForeground, theme.foreground);
    });

    test('honour explicit button.secondary* tokens when present', () {
      final map = loader.parse('''
        {
          "name": "Secondary Test",
          "type": "vs-dark",
          "colors": {
            "button.secondaryBackground": "#3A3D41",
            "button.secondaryForeground": "#CCCCCC"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.buttonSecondaryBackground, const Color(0xFF3A3D41));
      expect(theme.buttonSecondaryForeground, const Color(0xFFCCCCCC));
    });

    test('copyWith preserves secondary button tokens when unspecified', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      final modified = base.copyWith(foreground: const Color(0xFFFF0000));
      expect(
        modified.buttonSecondaryBackground,
        equals(base.buttonSecondaryBackground),
      );
      expect(
        modified.buttonSecondaryForeground,
        equals(base.buttonSecondaryForeground),
      );
    });

    test('copyWith overrides secondary button tokens when specified', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      const bg = Color(0xFF112233);
      const fg = Color(0xFF445566);
      final modified = base.copyWith(
        buttonSecondaryBackground: bg,
        buttonSecondaryForeground: fg,
      );
      expect(modified.buttonSecondaryBackground, equals(bg));
      expect(modified.buttonSecondaryForeground, equals(fg));
    });

    test('lerp interpolates secondary button colours', () {
      final a = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'A', baseType: 'vs-dark', colors: {}),
      ).copyWith(buttonSecondaryBackground: const Color(0xFF000000));
      final b = a.copyWith(buttonSecondaryBackground: const Color(0xFFFFFFFF));
      final mid = a.lerp(b, 0.5);
      expect(mid.buttonSecondaryBackground, isNot(const Color(0xFF000000)));
      expect(mid.buttonSecondaryBackground, isNot(const Color(0xFFFFFFFF)));
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

  group('WorkbenchTheme chrome typography canon (§7.6)', () {
    // Source-cited literals mirror VS Code's workbench CSS. Pin every
    // chrome semantic token so a stray edit fails loudly — typography
    // drift was the failure mode the canon exists to remove.
    final theme = WorkbenchTheme.fromVscodeColorMap(
      const VscodeColorMap(name: 'Canon', baseType: 'vs-dark', colors: {}),
    );

    test('sidebarOrPanelHeading is 11 / w400 (part.css .title-label h2)', () {
      expect(theme.sidebarOrPanelHeading.fontSize, 11);
      expect(theme.sidebarOrPanelHeading.fontWeight, FontWeight.w400);
    });

    test('sectionTitle is 11 / w700 (paneview.css .pane-header)', () {
      expect(theme.sectionTitle.fontSize, 11);
      expect(theme.sectionTitle.fontWeight, FontWeight.w700);
    });

    test('bodyText is 13 / w400 (part.css .part > .content)', () {
      expect(theme.bodyText.fontSize, 13);
      expect(theme.bodyText.fontWeight, FontWeight.w400);
    });

    test('labelText is 13 / w500 (settingsEditor2.css)', () {
      expect(theme.labelText.fontSize, 13);
      expect(theme.labelText.fontWeight, FontWeight.w500);
    });

    test('statusText is 12 / w400 (statusbarpart.css)', () {
      expect(theme.statusText.fontSize, 12);
      expect(theme.statusText.fontWeight, FontWeight.w400);
    });

    test('statusBarTextStyle is 12 / w400 (statusbarpart.css)', () {
      expect(theme.statusBarTextStyle.fontSize, 12);
      expect(theme.statusBarTextStyle.fontWeight, FontWeight.w400);
    });

    test('buttonTextStyle is 12 / w400 (button.css)', () {
      expect(theme.buttonTextStyle.fontSize, 12);
      expect(theme.buttonTextStyle.fontWeight, FontWeight.w400);
    });

    test('captionText is 12 / w400 (inherits body)', () {
      expect(theme.captionText.fontSize, 12);
      expect(theme.captionText.fontWeight, FontWeight.w400);
    });

    test('helperStyle is 12 / w400 (caption tier)', () {
      expect(theme.helperStyle.fontSize, 12);
      expect(theme.helperStyle.fontWeight, FontWeight.w400);
    });

    test('smallText is 11 / w600 (paneCompositeBar badge tier)', () {
      expect(theme.smallText.fontSize, 11);
      expect(theme.smallText.fontWeight, FontWeight.w600);
    });

    test('chromeFontFamily default null → resolves to platform UI sans', () {
      // Family rule: chrome `fontFamily` defaults to null so Flutter
      // resolves to the platform's default UI font, matching VS Code's
      // `-apple-system` / `Segoe UI` / `system-ui` selectors.
      expect(theme.sectionTitle.fontFamily, isNull);
      expect(theme.bodyText.fontFamily, isNull);
      expect(theme.labelText.fontFamily, isNull);
      expect(theme.statusBarTextStyle.fontFamily, isNull);
      expect(theme.buttonTextStyle.fontFamily, isNull);
      expect(theme.helperStyle.fontFamily, isNull);
      expect(theme.smallText.fontFamily, isNull);
      expect(theme.sidebarOrPanelHeading.fontFamily, isNull);
    });

    test('chromeFontFamily override propagates uniformly', () {
      final overridden = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
        chromeFontFamily: 'Inter',
      );
      expect(overridden.sectionTitle.fontFamily, 'Inter');
      expect(overridden.bodyText.fontFamily, 'Inter');
      expect(overridden.labelText.fontFamily, 'Inter');
      expect(overridden.statusBarTextStyle.fontFamily, 'Inter');
      expect(overridden.buttonTextStyle.fontFamily, 'Inter');
      expect(overridden.helperStyle.fontFamily, 'Inter');
      expect(overridden.smallText.fontFamily, 'Inter');
      expect(overridden.sidebarOrPanelHeading.fontFamily, 'Inter');
    });
  });

  group('WorkbenchTheme editor-derived surfaces (§7.7)', () {
    // editor.fontFamily / editor.fontSize defaults mirror VS Code's
    // EDITOR_FONT_DEFAULTS per platform. Tests pin the host platform's
    // primary family so a drift fails loudly.
    test('macOS default editorFontFamily is Menlo (size 12)', () {
      final original = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = original);
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'Mac', baseType: 'vs-dark', colors: {}),
      );
      expect(theme.editorFontFamily, 'Menlo');
      expect(theme.editorFontSize, 12);
      expect(theme.editorStyle.fontFamily, 'Menlo');
      expect(theme.editorStyle.fontSize, 12);
    });

    test('Windows default editorFontFamily is Consolas (size 14)', () {
      final original = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = original);
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'Win', baseType: 'vs-dark', colors: {}),
      );
      expect(theme.editorFontFamily, 'Consolas');
      expect(theme.editorFontSize, 14);
      expect(theme.editorStyle.fontFamily, 'Consolas');
      expect(theme.editorStyle.fontSize, 14);
    });

    test('Linux default editorFontFamily is "Droid Sans Mono" (size 14)', () {
      final original = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = original);
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'Linux', baseType: 'vs-dark', colors: {}),
      );
      expect(theme.editorFontFamily, 'Droid Sans Mono');
      expect(theme.editorFontSize, 14);
    });

    test('editorFontFamily override flows through editorStyle', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
        editorFontFamily: 'Inconsolata',
      );
      expect(theme.editorFontFamily, 'Inconsolata');
      expect(theme.editorStyle.fontFamily, 'Inconsolata');
    });

    test('editorFontSize override flows through editorStyle', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
        editorFontSize: 16,
      );
      expect(theme.editorFontSize, 16);
      expect(theme.editorStyle.fontSize, 16);
    });

    test('loglineMessage derives from editorStyle (same family)', () {
      // §7.7: loglineMessage rebases on editorStyle.copyWith — the
      // family resolution lives in one place so a host override flows
      // through every editor-derived surface.
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
        editorFontFamily: 'Inconsolata',
      );
      expect(theme.loglineMessage.fontFamily, theme.editorStyle.fontFamily);
      expect(theme.loglineMessage.fontFamily, 'Inconsolata');
    });

    test('valueText derives from editorStyle (same family)', () {
      // §7.7: valueText sits in the editor canon alongside log lines
      // — DRO numerics inherit the editor family rather than a bespoke
      // chrome one.
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
        editorFontFamily: 'Inconsolata',
      );
      expect(theme.valueText.fontFamily, theme.editorStyle.fontFamily);
      expect(theme.valueText.fontFamily, 'Inconsolata');
    });
  });
}

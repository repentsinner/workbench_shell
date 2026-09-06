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
      // Spec §spec:vscode-theme-format: "Color tokens expressed as #RRGGBBAA retain their
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
      // omit it and the §spec:chrome-material-theming button border is transparent.
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

    test('inputOption.active* preserved, incl. alpha (Dark Modern case)', () {
      // The SegmentedButton selected segment reads from these — a subtle
      // translucent accent fill plus a solid accent border.
      final map = loader.parse('''
        {
          "name": "Modern-like",
          "type": "vs-dark",
          "colors": {
            "inputOption.activeBackground": "#2489DB82",
            "inputOption.activeBorder": "#2488DB"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.inputOptionActiveBackground, const Color(0x822489DB));
      expect(theme.inputOptionActiveBorder, const Color(0xFF2488DB));
    });

    test('sideBarSectionHeader tokens resolve from the colors map', () {
      // §spec:view-stack: the stacked-pane separator chrome (band + rule)
      // is mapped from VS Code's sideBarSectionHeader.background /
      // sideBarSectionHeader.border, retaining alpha.
      final map = loader.parse('''
        {
          "name": "Header Chrome",
          "type": "vs-dark",
          "colors": {
            "sideBarSectionHeader.background": "#181818",
            "sideBarSectionHeader.border": "#2B2B2BFF"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.sideBarSectionHeaderBackground, const Color(0xFF181818));
      expect(theme.sideBarSectionHeaderBorder, const Color(0xFF2B2B2B));
    });

    test('sideBarSectionHeader tokens are null when omitted', () {
      // Nullable like activityBar.border / sideBar.border: a theme that
      // omits the key suppresses the corresponding paint.
      final map = loader.parse('''
        {
          "name": "Minimal Dark",
          "type": "vs-dark",
          "colors": {}
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.sideBarSectionHeaderBackground, isNull);
      expect(theme.sideBarSectionHeaderBorder, isNull);
    });

    test('inputOption.active* fall back to the focusBorder accent', () {
      // Older themes (Dark+) omit inputOption.*; the selected segment still
      // gets an accent treatment from focusBorder rather than disappearing.
      final map = loader.parse('''
        {
          "name": "Minimal Dark",
          "type": "vs-dark",
          "colors": { "focusBorder": "#007ACC" }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.inputOptionActiveBorder, const Color(0xFF007ACC));
      expect(
        theme.inputOptionActiveBackground,
        const Color(0xFF007ACC).withValues(alpha: 0.25),
      );
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

    test('Dark Modern sets the section-header band and rule', () async {
      // The bundled themes carry sideBarSectionHeader.* so the example's
      // Explorer pane headers render the band + rule with no asset change.
      final map = await loader.loadAsset('dark_modern.json');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.sideBarSectionHeaderBackground, const Color(0xFF181818));
      expect(theme.sideBarSectionHeaderBorder, const Color(0xFF2B2B2B));
    });
  });

  group('WorkbenchTheme.statusBarTextStyle', () {
    // Primary status bar text matches the size/weight of helperStyle
    // (12pt, w400 per §spec:chrome-typography-canon) but paints in statusBar.foreground so it
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

  group('WorkbenchTheme notification tokens (§spec:notification-center)', () {
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

  group('WorkbenchTheme Modern UI tokens (§spec:modern-ui-surfaces)', () {
    test('surface.* fall back to the registry defaults when omitted', () {
      final dark = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      // VS Code registry: surface.background is sideBar.background in dark
      // themes and editor.background in light ones; surface.border is
      // `foreground` at 10% composited over it.
      expect(dark.surfaceBackground, dark.sideBarBackground);
      expect(
        dark.surfaceBorder,
        Color.alphaBlend(
          dark.foreground.withValues(alpha: 0.1),
          dark.surfaceBackground,
        ),
      );

      final light = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs', colors: {}),
      );
      expect(light.surfaceBackground, light.editorBackground);
    });

    test('surface.* honour explicit tokens when present', () {
      final map = loader.parse('''
        {
          "name": "Surface Test",
          "type": "vs-dark",
          "colors": {
            "surface.background": "#181818",
            "surface.border": "#2B2B2B"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.surfaceBackground, const Color(0xFF181818));
      expect(theme.surfaceBorder, const Color(0xFF2B2B2B));
    });

    test('activity bar item states chain through the modern tab family', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      // Registry chain ends at list.inactiveSelectionBackground (#37373D
      // dark) / list.hoverBackground, with foreground for both label colours.
      expect(base.activityBarItemActiveBackground, const Color(0xFF37373D));
      expect(base.activityBarItemActiveForeground, base.foreground);
      expect(base.activityBarItemHoverBackground, base.listHoverBackground);
      expect(base.activityBarItemHoverForeground, base.foreground);

      // A theme that styles only its modern tabs still gets a coherent rail.
      final tabbed = WorkbenchTheme.fromVscodeColorMap(
        loader.parse('''
        {
          "name": "Tabbed",
          "type": "vs-dark",
          "colors": {
            "modernTab.activeBackground": "#04395E",
            "modernTab.hoverBackground": "#2A2D2E"
          }
        }
        '''),
      );
      expect(tabbed.activityBarItemActiveBackground, const Color(0xFF04395E));
      expect(tabbed.activityBarItemHoverBackground, const Color(0xFF2A2D2E));

      // The dedicated keys win over the tab family.
      final explicit = WorkbenchTheme.fromVscodeColorMap(
        loader.parse('''
        {
          "name": "Explicit",
          "type": "vs-dark",
          "colors": {
            "modernTab.activeBackground": "#04395E",
            "modernActivityBarItem.activeBackground": "#0078D4",
            "modernActivityBarItem.activeForeground": "#FFFFFF"
          }
        }
        '''),
      );
      expect(explicit.activityBarItemActiveBackground, const Color(0xFF0078D4));
      expect(explicit.activityBarItemActiveForeground, const Color(0xFFFFFFFF));
    });

    test('workbenchBackdrop reads titleBar.activeBackground', () {
      // `floatingPanels.css` paints the ground behind the cards from
      // `titleBar.activeBackground`, which a theme may set two shades apart
      // from `editor.background` — the shade the gutters showed before.
      final map = loader.parse('''
        {
          "name": "Backdrop Test",
          "type": "vs-dark",
          "colors": {
            "editor.background": "#121314",
            "titleBar.activeBackground": "#191A1B"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.workbenchBackdrop, const Color(0xFF191A1B));
      expect(theme.workbenchBackdrop, isNot(theme.editorBackground));
    });

    test('workbenchBackdrop falls back to the title bar strip default', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      // Same key the menu bar strip already resolves, so the two cannot drift.
      expect(theme.workbenchBackdrop, theme.menuBarBackground);
    });

    test('copyWith and lerp carry the Modern UI tokens', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      expect(
        base.copyWith(foreground: const Color(0xFFFF0000)).surfaceBorder,
        base.surfaceBorder,
      );
      expect(
        base.copyWith(surfaceBorder: const Color(0xFF00FF00)).surfaceBorder,
        const Color(0xFF00FF00),
      );

      final other = base.copyWith(
        surfaceBackground: const Color(0xFF000000),
        activityBarItemActiveBackground: const Color(0xFF000000),
      );
      final mid = base.lerp(other, 0.5);
      expect(
        mid.surfaceBackground,
        Color.lerp(base.surfaceBackground, other.surfaceBackground, 0.5),
      );
      expect(
        mid.activityBarItemActiveBackground,
        Color.lerp(
          base.activityBarItemActiveBackground,
          other.activityBarItemActiveBackground,
          0.5,
        ),
      );
    });
  });

  group(
    'WorkbenchTheme secondary button tokens (§spec:chrome-material-theming)',
    () {
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
        final b = a.copyWith(
          buttonSecondaryBackground: const Color(0xFFFFFFFF),
        );
        final mid = a.lerp(b, 0.5);
        expect(mid.buttonSecondaryBackground, isNot(const Color(0xFF000000)));
        expect(mid.buttonSecondaryBackground, isNot(const Color(0xFFFFFFFF)));
      });
    },
  );

  group('WorkbenchTheme popup menu tokens (§spec:chrome-material-theming)', () {
    // Upstream registry, source-verified against
    // src/vs/platform/theme/common/colors/menuColors.ts: menu.background
    // defaults to dropdown.background, menu.foreground to
    // dropdown.foreground, menu.selectionBackground and
    // menu.selectionForeground to the list active-selection pair,
    // menu.separatorBackground to transparent(foreground, 0.2), and
    // menu.border / menu.selectionBorder to null outside high contrast.
    test('fall back to their upstream defaults when menu.* omitted', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      expect(theme.menuBackground, theme.dropdownBackground);
      expect(theme.menuForeground, const Color(0xFFF0F0F0));
      expect(theme.menuBorder, isNull);
      expect(
        theme.menuSelectionBackground,
        theme.listActiveSelectionBackground,
      );
      expect(theme.menuSelectionForeground, const Color(0xFFFFFFFF));
      expect(theme.menuSelectionBorder, isNull);
      expect(
        theme.menuSeparatorBackground,
        theme.foreground.withValues(alpha: 0.2),
      );
    });

    test('take foreground for dropdown.foreground in light themes', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs', colors: {}),
      );
      expect(theme.menuForeground, theme.foreground);
    });

    test('chain through dropdown.* and list.* before the literals', () {
      final map = loader.parse('''
        {
          "name": "Chain Test",
          "type": "vs-dark",
          "colors": {
            "dropdown.background": "#101112",
            "dropdown.foreground": "#131415",
            "list.activeSelectionBackground": "#161718",
            "list.activeSelectionForeground": "#191A1B"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.menuBackground, const Color(0xFF101112));
      expect(theme.menuForeground, const Color(0xFF131415));
      expect(theme.menuSelectionBackground, const Color(0xFF161718));
      expect(theme.menuSelectionForeground, const Color(0xFF191A1B));
    });

    test('honour explicit menu.* tokens when present', () {
      final map = loader.parse('''
        {
          "name": "Menu Test",
          "type": "vs-dark",
          "colors": {
            "dropdown.background": "#101112",
            "menu.background": "#1F1F1F",
            "menu.foreground": "#CCCCCC",
            "menu.border": "#454545",
            "menu.selectionBackground": "#0078D4",
            "menu.selectionForeground": "#FFFFFF",
            "menu.selectionBorder": "#00FF00",
            "menu.separatorBackground": "#2A2B2C"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.menuBackground, const Color(0xFF1F1F1F));
      expect(theme.menuForeground, const Color(0xFFCCCCCC));
      expect(theme.menuBorder, const Color(0xFF454545));
      expect(theme.menuSelectionBackground, const Color(0xFF0078D4));
      expect(theme.menuSelectionForeground, const Color(0xFFFFFFFF));
      expect(theme.menuSelectionBorder, const Color(0xFF00FF00));
      expect(theme.menuSeparatorBackground, const Color(0xFF2A2B2C));
    });

    test('Dark Modern separates the menu fill from the panel fill', () async {
      final map = await loader.loadAsset('dark_modern.json');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.menuBackground, isNot(equals(theme.panelBackground)));
    });

    test('copyWith preserves menu tokens when unspecified', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      final modified = base.copyWith(foreground: const Color(0xFFFF0000));
      expect(modified.menuBackground, equals(base.menuBackground));
      expect(modified.menuForeground, equals(base.menuForeground));
      expect(
        modified.menuSelectionBackground,
        equals(base.menuSelectionBackground),
      );
      expect(
        modified.menuSeparatorBackground,
        equals(base.menuSeparatorBackground),
      );
    });

    test('lerp interpolates menu colours', () {
      final a = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'A', baseType: 'vs-dark', colors: {}),
      ).copyWith(menuBackground: const Color(0xFF000000));
      final b = a.copyWith(menuBackground: const Color(0xFFFFFFFF));
      final mid = a.lerp(b, 0.5);
      expect(mid.menuBackground, isNot(equals(a.menuBackground)));
      expect(mid.menuBackground, isNot(equals(b.menuBackground)));
    });
  });

  group('WorkbenchTheme dropdown tokens (§spec:chrome-material-theming)', () {
    // Upstream registry, source-verified against
    // src/vs/platform/theme/common/colors/inputColors.ts:
    //   dropdown.background     → #3C3C3C dark / white light
    //   dropdown.foreground     → #F0F0F0 dark / foreground light
    //   dropdown.border         → dropdown.background dark / #CECECE light
    //   dropdown.listBackground → null dark and light
    // and against src/vs/base/browser/ui/selectBox/selectBoxCustom.ts, which
    // paints the open list with
    // `asCssValueWithDefault(selectListBackground, background)` — so the list
    // falls back to the trigger fill, never to a Material surface.
    test('fall back to their upstream defaults in a dark theme', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      expect(theme.dropdownBackground, const Color(0xFF3C3C3C));
      expect(theme.dropdownForeground, const Color(0xFFF0F0F0));
      expect(theme.dropdownBorder, theme.dropdownBackground);
      expect(theme.dropdownListBackground, theme.dropdownBackground);
    });

    test('fall back to their upstream defaults in a light theme', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs', colors: {}),
      );
      expect(theme.dropdownBackground, const Color(0xFFFFFFFF));
      expect(theme.dropdownForeground, theme.foreground);
      expect(theme.dropdownBorder, const Color(0xFFCECECE));
      expect(theme.dropdownListBackground, theme.dropdownBackground);
    });

    test('the list falls back to the trigger fill a theme does set', () {
      // The #30 defect: a theme that colours only `dropdown.background`
      // still gets a themed list, because upstream defaults the list token
      // to the trigger fill rather than leaving it unresolved.
      final map = loader.parse('''
        {
          "name": "Trigger Only",
          "type": "vs-dark",
          "colors": {"dropdown.background": "#101112"}
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.dropdownListBackground, const Color(0xFF101112));
      expect(theme.dropdownBorder, const Color(0xFF101112));
    });

    test('honour explicit dropdown.* tokens when present', () {
      final map = loader.parse('''
        {
          "name": "Dropdown Test",
          "type": "vs-dark",
          "colors": {
            "dropdown.background": "#101112",
            "dropdown.foreground": "#131415",
            "dropdown.border": "#161718",
            "dropdown.listBackground": "#191A1B"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.dropdownBackground, const Color(0xFF101112));
      expect(theme.dropdownForeground, const Color(0xFF131415));
      expect(theme.dropdownBorder, const Color(0xFF161718));
      expect(theme.dropdownListBackground, const Color(0xFF191A1B));
    });

    test('copyWith preserves dropdown tokens when unspecified', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      final modified = base.copyWith(foreground: const Color(0xFFFF0000));
      expect(modified.dropdownForeground, equals(base.dropdownForeground));
      expect(modified.dropdownBorder, equals(base.dropdownBorder));
      expect(
        modified.dropdownListBackground,
        equals(base.dropdownListBackground),
      );
    });

    test('lerp interpolates dropdown colours', () {
      final a = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'A', baseType: 'vs-dark', colors: {}),
      ).copyWith(dropdownListBackground: const Color(0xFF000000));
      final b = a.copyWith(dropdownListBackground: const Color(0xFFFFFFFF));
      final mid = a.lerp(b, 0.5);
      expect(
        mid.dropdownListBackground,
        isNot(equals(const Color(0xFF000000))),
      );
      expect(
        mid.dropdownListBackground,
        isNot(equals(const Color(0xFFFFFFFF))),
      );
    });

    test('a differing dropdown token breaks equality', () {
      final a = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'A', baseType: 'vs-dark', colors: {}),
      );
      expect(
        a.copyWith(dropdownListBackground: const Color(0xFF123456)),
        isNot(equals(a)),
      );
      expect(
        a.copyWith(dropdownForeground: const Color(0xFF123456)),
        isNot(equals(a)),
      );
      expect(
        a.copyWith(dropdownBorder: const Color(0xFF123456)),
        isNot(equals(a)),
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

  group(
    'WorkbenchTheme chrome typography canon (§spec:chrome-typography-canon)',
    () {
      // Source-cited literals mirror VS Code's workbench CSS. Pin every
      // chrome semantic token so a stray edit fails loudly — typography
      // drift was the failure mode the canon exists to remove.
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'Canon', baseType: 'vs-dark', colors: {}),
      );

      test(
        'sidebarOrPanelHeading is 12 / w600 '
        '(fontRamp.css .title-label h2)',
        () {
          expect(theme.sidebarOrPanelHeading.fontSize, 12);
          expect(theme.sidebarOrPanelHeading.fontWeight, FontWeight.w600);
        },
      );

      test(
        'baseSidebarOrPanelHeading is 11 / w400 (part.css .title-label h2)',
        () {
          expect(theme.baseSidebarOrPanelHeading.fontSize, 11);
          expect(theme.baseSidebarOrPanelHeading.fontWeight, FontWeight.w400);
        },
      );

      test('sectionTitle is 12 / w600 (fontRamp.css .pane-header .title)', () {
        expect(theme.sectionTitle.fontSize, 12);
        expect(theme.sectionTitle.fontWeight, FontWeight.w600);
      });

      test('baseSectionTitle is 11 / w700 (paneview.css .pane-header)', () {
        expect(theme.baseSectionTitle.fontSize, 11);
        expect(theme.baseSectionTitle.fontWeight, FontWeight.w700);
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
    },
  );

  group(
    'WorkbenchTheme editor-derived surfaces (§spec:editor-derived-surfaces)',
    () {
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
        // §spec:editor-derived-surfaces: loglineMessage rebases on editorStyle.copyWith — the
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
        // §spec:editor-derived-surfaces: valueText sits in the editor canon alongside log lines
        // — DRO numerics inherit the editor family rather than a bespoke
        // chrome one.
        final theme = WorkbenchTheme.fromVscodeColorMap(
          const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
          editorFontFamily: 'Inconsolata',
        );
        expect(theme.valueText.fontFamily, theme.editorStyle.fontFamily);
        expect(theme.valueText.fontFamily, 'Inconsolata');
      });
    },
  );

  group('WorkbenchTheme equality', () {
    const json = '''
    {
      "name": "Eq Test",
      "type": "vs-dark",
      "colors": {
        "editor.background": "#1F1F1F",
        "editor.foreground": "#CCCCCC",
        "statusBar.background": "#007ACC"
      },
      "tokenColors": [
        {"scope": "comment", "settings": {"foreground": "#6A9955", "fontStyle": "italic"}},
        {"scope": ["keyword", "storage"], "settings": {"foreground": "#569CD6"}}
      ]
    }''';

    test(
      'two themes built from separate parses of the same JSON are equal',
      () {
        // The host-rebuilds-each-frame path: independent parses produce
        // distinct TokenTheme instances, so value equality must compare
        // the token rules — not just object identity — for Flutter to
        // elide ThemeExtension-driven rebuilds.
        final a = WorkbenchTheme.fromVscodeColorMap(loader.parse(json));
        final b = WorkbenchTheme.fromVscodeColorMap(loader.parse(json));
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('copyWith with no changes preserves equality', () {
      final a = WorkbenchTheme.fromVscodeColorMap(loader.parse(json));
      expect(a.copyWith(), equals(a));
      expect(a.copyWith().hashCode, equals(a.hashCode));
    });

    test('changing a single field breaks equality', () {
      final a = WorkbenchTheme.fromVscodeColorMap(loader.parse(json));
      final b = a.copyWith(foreground: const Color(0xFF123456));
      expect(b, isNot(equals(a)));
    });

    test('differing token themes break equality', () {
      final a = WorkbenchTheme.fromVscodeColorMap(loader.parse(json));
      final other = loader.parse('''
      {
        "name": "Eq Test",
        "type": "vs-dark",
        "colors": {"editor.background": "#1F1F1F", "editor.foreground": "#CCCCCC", "statusBar.background": "#007ACC"},
        "tokenColors": [
          {"scope": "comment", "settings": {"foreground": "#FF0000"}}
        ]
      }''');
      final b = WorkbenchTheme.fromVscodeColorMap(other);
      expect(b, isNot(equals(a)));
    });
  });

  group('WorkbenchTheme split-button token family (§spec:split-button)', () {
    // Upstream registry, source-verified against
    // src/vs/platform/theme/common/colors/inputColors.ts: button.separator
    // defaults to transparent(button.foreground, .4), button.secondaryBorder
    // to transparent(foreground, 0.15) outside high contrast, and
    // button.secondaryHoverBackground to lighten(list.hoverBackground, 0.2).
    test('fall back to the registry chains when the theme omits them', () {
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      expect(
        theme.buttonSeparator,
        theme.buttonForeground.withValues(
          alpha: theme.buttonForeground.a * 0.4,
        ),
      );
      expect(
        theme.buttonSecondaryBorder,
        theme.foreground.withValues(alpha: theme.foreground.a * 0.15),
      );
      final hover = HSLColor.fromColor(theme.listHoverBackground);
      expect(
        theme.buttonSecondaryHoverBackground,
        hover.withLightness(clampDouble(hover.lightness * 1.2, 0, 1)).toColor(),
      );
    });

    test('the hover fallback is lighter than the surface it derives from', () {
      // `lighten` scales HSL lightness, so the fallback has to read as a
      // hover *state* rather than repeating the resting fill.
      final theme = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      expect(
        HSLColor.fromColor(theme.buttonSecondaryHoverBackground).lightness,
        greaterThan(HSLColor.fromColor(theme.listHoverBackground).lightness),
      );
    });

    test('honour explicit tokens when present, alpha included', () {
      final map = loader.parse('''
        {
          "name": "Split Test",
          "type": "vs-dark",
          "colors": {
            "button.separator": "#ffffff66",
            "button.secondaryBorder": "#3A3D41",
            "button.secondaryHoverBackground": "#45494E"
          }
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.buttonSeparator, const Color(0x66FFFFFF));
      expect(theme.buttonSecondaryBorder, const Color(0xFF3A3D41));
      expect(theme.buttonSecondaryHoverBackground, const Color(0xFF45494E));
    });

    test('the separator fallback follows an overridden button.foreground', () {
      // The registry chains the separator through button.foreground, so a
      // theme that restyles the label moves the pipe with it.
      final map = loader.parse('''
        {
          "name": "Separator Chain",
          "type": "vs-dark",
          "colors": {"button.foreground": "#112233"}
        }
        ''');
      final theme = WorkbenchTheme.fromVscodeColorMap(map);
      expect(theme.buttonSeparator, const Color(0x66112233));
    });

    test('copyWith preserves the family when unspecified', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      final modified = base.copyWith(foreground: const Color(0xFFFF0000));
      expect(modified.buttonSeparator, equals(base.buttonSeparator));
      expect(
        modified.buttonSecondaryBorder,
        equals(base.buttonSecondaryBorder),
      );
      expect(
        modified.buttonSecondaryHoverBackground,
        equals(base.buttonSecondaryHoverBackground),
      );
    });

    test('copyWith overrides the family when specified', () {
      final base = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'X', baseType: 'vs-dark', colors: {}),
      );
      const separator = Color(0xFF112233);
      const border = Color(0xFF445566);
      const hover = Color(0xFF778899);
      final modified = base.copyWith(
        buttonSeparator: separator,
        buttonSecondaryBorder: border,
        buttonSecondaryHoverBackground: hover,
      );
      expect(modified.buttonSeparator, equals(separator));
      expect(modified.buttonSecondaryBorder, equals(border));
      expect(modified.buttonSecondaryHoverBackground, equals(hover));
    });

    test('lerp interpolates the family', () {
      final a = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'A', baseType: 'vs-dark', colors: {}),
      ).copyWith(
        buttonSeparator: const Color(0xFF000000),
        buttonSecondaryBorder: const Color(0xFF000000),
        buttonSecondaryHoverBackground: const Color(0xFF000000),
      );
      final b = a.copyWith(
        buttonSeparator: const Color(0xFFFFFFFF),
        buttonSecondaryBorder: const Color(0xFFFFFFFF),
        buttonSecondaryHoverBackground: const Color(0xFFFFFFFF),
      );
      final mid = a.lerp(b, 0.5);
      for (final colour in [
        mid.buttonSeparator,
        mid.buttonSecondaryBorder,
        mid.buttonSecondaryHoverBackground,
      ]) {
        expect(colour, isNot(const Color(0xFF000000)));
        expect(colour, isNot(const Color(0xFFFFFFFF)));
      }
    });

    test('a differing family member breaks equality', () {
      final a = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'A', baseType: 'vs-dark', colors: {}),
      );
      expect(a.copyWith(buttonSeparator: const Color(0xFF010203)), isNot(a));
      expect(
        a.copyWith(buttonSecondaryBorder: const Color(0xFF010203)),
        isNot(a),
      );
      expect(
        a.copyWith(buttonSecondaryHoverBackground: const Color(0xFF010203)),
        isNot(a),
      );
    });
  });
}

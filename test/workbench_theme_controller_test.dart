import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

/// Build the synchronous placeholder theme a host app would pass as
/// `initialTheme` — an empty [VscodeColorMap] resolved through the
/// theme builder so the first frame has usable chrome before the real
/// asset loads.
WorkbenchTheme _placeholderTheme() => WorkbenchTheme.fromVscodeColorMap(
  const VscodeColorMap(name: 'Placeholder', baseType: 'vs-dark', colors: {}),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkbenchThemeController', () {
    test('selectTheme on the initial filename loads the bundled asset, '
        'not the placeholder', () async {
      // Regression: the constructor used to pre-populate the cache
      // with `_cache[initialFilename] = initialTheme`. That poisoned
      // the cache — `selectTheme(initialFilename)` would hit the
      // already-selected short-circuit and never load the real
      // bundled JSON. The app showed the placeholder palette
      // instead of Dark Modern (activityBar.background #333333
      // instead of #181818, panel.border #808080 instead of
      // #2B2B2B, etc.) for the default theme.
      final controller = WorkbenchThemeController(
        initialTheme: _placeholderTheme(),
        // Default initialFilename is 'dark_modern.json'.
      );
      addTearDown(controller.dispose);

      // Guard: placeholder palette differs from real Dark Modern
      // in every value we check below. If the placeholder ever
      // happens to match the real theme this test passes vacuously.
      expect(
        controller.theme.activityBarBackground,
        isNot(const Color(0xFF181818)),
        reason: 'placeholder should not already be Dark Modern',
      );

      await controller.selectTheme('dark_modern.json');

      // Real Dark Modern values from
      // packages/workbench_shell/assets/themes/dark_modern.json.
      expect(
        controller.theme.activityBarBackground,
        const Color(0xFF181818),
        reason:
            'activityBar.background should be the real '
            'Dark Modern value, not the placeholder fallback',
      );
      expect(controller.theme.sideBarBackground, const Color(0xFF181818));
      expect(controller.theme.editorBackground, const Color(0xFF1F1F1F));
      expect(controller.theme.panelBorder, const Color(0xFF2B2B2B));
    });

    test('switching away and back re-uses the real cached theme', () async {
      final controller = WorkbenchThemeController(
        initialTheme: _placeholderTheme(),
      );
      addTearDown(controller.dispose);

      await controller.selectTheme('dark_modern.json');
      final firstLoad = controller.theme;

      await controller.selectTheme('nord.json');
      expect(
        controller.theme.editorBackground,
        isNot(const Color(0xFF1F1F1F)),
        reason: 'Nord should have loaded a different editor background',
      );

      await controller.selectTheme('dark_modern.json');
      expect(
        controller.theme.activityBarBackground,
        const Color(0xFF181818),
        reason:
            'returning to dark_modern should resolve back to the '
            'real Dark Modern theme, not a stale placeholder',
      );
      // Same instance — cache hit on the previously loaded real theme.
      expect(identical(controller.theme, firstLoad), isTrue);
    });
  });
}

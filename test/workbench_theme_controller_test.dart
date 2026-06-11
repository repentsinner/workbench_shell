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

      await controller.selectTheme('light_modern.json');
      expect(
        controller.theme.editorBackground,
        isNot(const Color(0xFF1F1F1F)),
        reason: 'Light Modern should have a different editor background',
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

  group('WorkbenchThemeController brightness-paired selection', () {
    // Each test installs its own platform-brightness override so the
    // controller's `system`-mode resolver sees a deterministic value.
    // Tear-downs restore the binding's defaults.
    void setPlatformBrightness(Brightness b) {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.platformBrightnessTestValue = b;
    }

    void clearPlatformBrightness() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.clearPlatformBrightnessTestValue();
    }

    tearDown(clearPlatformBrightness);

    test('defaultAvailableThemes declares brightness for each entry', () {
      // The entry list is authoritative for pairing in `system` mode —
      // each entry must declare its brightness so the controller can
      // pick a slot without loading the asset.
      final entries = WorkbenchThemeController.defaultAvailableThemes;
      Brightness brightnessFor(String filename) =>
          entries.firstWhere((e) => e.filename == filename).brightness;

      expect(brightnessFor('dark_modern.json'), Brightness.dark);
      expect(brightnessFor('light_modern.json'), Brightness.light);
      expect(brightnessFor('dark_plus.json'), Brightness.dark);
      expect(brightnessFor('light_plus.json'), Brightness.light);
      expect(brightnessFor('solarized_dark.json'), Brightness.dark);
      expect(brightnessFor('solarized_light.json'), Brightness.light);
      expect(brightnessFor('monokai.json'), Brightness.dark);
      expect(brightnessFor('2026_dark.json'), Brightness.dark);
      expect(brightnessFor('2026_light.json'), Brightness.light);
    });

    test(
      'system mode selects preferredDark when OS brightness is dark',
      () async {
        // Defaults: themeMode=system, preferredLight=light_modern,
        // preferredDark=dark_modern. The dispatcher flag is the only
        // axis under test.
        setPlatformBrightness(Brightness.dark);

        final controller = WorkbenchThemeController(
          initialTheme: _placeholderTheme(),
        );
        addTearDown(controller.dispose);

        await controller.resolveActiveTheme();
        expect(controller.selectedFilename, 'dark_modern.json');
        expect(controller.brightness, Brightness.dark);
      },
    );

    test(
      'system mode selects preferredLight when OS brightness is light',
      () async {
        setPlatformBrightness(Brightness.light);

        final controller = WorkbenchThemeController(
          initialTheme: _placeholderTheme(),
        );
        addTearDown(controller.dispose);

        await controller.resolveActiveTheme();
        expect(controller.selectedFilename, 'light_modern.json');
        expect(controller.brightness, Brightness.light);
      },
    );

    test(
      'system mode swaps the active theme when OS brightness flips',
      () async {
        setPlatformBrightness(Brightness.light);

        final controller = WorkbenchThemeController(
          initialTheme: _placeholderTheme(),
        );
        addTearDown(controller.dispose);
        await controller.resolveActiveTheme();
        expect(controller.selectedFilename, 'light_modern.json');

        // Flip OS to dark and synthesise the platform callback the way
        // the binding does in production. The controller subscribes to
        // `onPlatformBrightnessChanged` in its constructor.
        setPlatformBrightness(Brightness.dark);
        final binding = TestWidgetsFlutterBinding.ensureInitialized();
        binding.platformDispatcher.onPlatformBrightnessChanged?.call();
        // The handler kicks off an async asset load.
        await controller.pendingResolution;

        expect(controller.selectedFilename, 'dark_modern.json');
        expect(controller.brightness, Brightness.dark);
      },
    );

    test('light mode ignores OS brightness changes', () async {
      setPlatformBrightness(Brightness.dark);

      final controller = WorkbenchThemeController(
        initialTheme: _placeholderTheme(),
        themeMode: ThemeMode.light,
      );
      addTearDown(controller.dispose);

      await controller.resolveActiveTheme();
      expect(controller.selectedFilename, 'light_modern.json');

      // Flip OS to light then back to dark — neither should affect us.
      setPlatformBrightness(Brightness.light);
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.onPlatformBrightnessChanged?.call();
      await controller.pendingResolution;
      expect(controller.selectedFilename, 'light_modern.json');

      setPlatformBrightness(Brightness.dark);
      binding.platformDispatcher.onPlatformBrightnessChanged?.call();
      await controller.pendingResolution;
      expect(controller.selectedFilename, 'light_modern.json');
    });

    test(
      'selectTheme of opposite brightness in system mode flips themeMode',
      () async {
        setPlatformBrightness(Brightness.light);

        final controller = WorkbenchThemeController(
          initialTheme: _placeholderTheme(),
        );
        addTearDown(controller.dispose);
        await controller.resolveActiveTheme();
        expect(controller.themeMode, ThemeMode.system);
        expect(controller.brightness, Brightness.light);

        // Picking a Dark theme while the OS is light flips the mode.
        await controller.selectTheme('dark_modern.json');

        expect(controller.themeMode, ThemeMode.dark);
        expect(controller.selectedFilename, 'dark_modern.json');
        expect(controller.brightness, Brightness.dark);
      },
    );

    test('selectTheme matching current brightness in system mode updates the '
        'preferred slot for that brightness', () async {
      setPlatformBrightness(Brightness.light);

      final controller = WorkbenchThemeController(
        initialTheme: _placeholderTheme(),
      );
      addTearDown(controller.dispose);
      await controller.resolveActiveTheme();

      await controller.selectTheme('solarized_light.json');

      expect(controller.themeMode, ThemeMode.system);
      expect(controller.preferredLight, 'solarized_light.json');
      expect(controller.preferredDark, 'dark_modern.json');
      expect(controller.selectedFilename, 'solarized_light.json');
    });

    test(
      'changing preferredLight in system mode under light OS swaps active',
      () async {
        setPlatformBrightness(Brightness.light);

        final controller = WorkbenchThemeController(
          initialTheme: _placeholderTheme(),
        );
        addTearDown(controller.dispose);
        await controller.resolveActiveTheme();
        expect(controller.selectedFilename, 'light_modern.json');

        controller.preferredLight = 'solarized_light.json';
        await controller.pendingResolution;

        expect(controller.selectedFilename, 'solarized_light.json');
      },
    );

    test('setting themeMode emits notifyListeners', () async {
      setPlatformBrightness(Brightness.light);

      final controller = WorkbenchThemeController(
        initialTheme: _placeholderTheme(),
      );
      addTearDown(controller.dispose);
      await controller.resolveActiveTheme();

      var notifications = 0;
      controller.addListener(() => notifications += 1);

      controller.themeMode = ThemeMode.dark;
      await controller.pendingResolution;

      expect(notifications, greaterThanOrEqualTo(1));
      expect(controller.themeMode, ThemeMode.dark);
      expect(controller.selectedFilename, 'dark_modern.json');
    });
  });

  group('WorkbenchThemeController platform-brightness subscription', () {
    test('restores the dispatcher handler after out-of-order disposal', () {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final dispatcher = binding.platformDispatcher;
      final original = dispatcher.onPlatformBrightnessChanged;

      final a = WorkbenchThemeController(initialTheme: _placeholderTheme());
      final b = WorkbenchThemeController(initialTheme: _placeholderTheme());

      // Dispose in creation order (non-LIFO). Single-slot handler chaining
      // used to resurrect A's handler here, leaving the dispatcher pointing
      // at a disposed controller.
      a.dispose();
      b.dispose();

      expect(dispatcher.onPlatformBrightnessChanged, same(original));
    });

    test('a surviving controller still reacts after another is disposed', () async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      final dispatcher = binding.platformDispatcher;
      dispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(dispatcher.clearPlatformBrightnessTestValue);

      final a = WorkbenchThemeController(initialTheme: _placeholderTheme());
      addTearDown(a.dispose);
      final b = WorkbenchThemeController(initialTheme: _placeholderTheme());
      b.dispose();
      await a.pendingResolution;

      dispatcher.platformBrightnessTestValue = Brightness.dark;
      dispatcher.onPlatformBrightnessChanged?.call();
      await a.pendingResolution;

      expect(a.brightness, Brightness.dark);
    });
  });
}

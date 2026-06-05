import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('applyWorkbenchChrome', () {
    final base = ThemeData.dark();
    final result = applyWorkbenchChrome(base, testWorkbenchTheme);

    test('installs the WorkbenchTheme extension', () {
      expect(result.extension<WorkbenchTheme>(), same(testWorkbenchTheme));
    });

    test('preserves the host base brightness', () {
      expect(result.brightness, base.brightness);
    });

    test('filled (primary) button theme carries the 4px buttonShape', () {
      final shape = result.filledButtonTheme.style?.shape?.resolve({});
      expect(shape, WorkbenchLayoutConstants.buttonShape);
    });

    test('text button theme carries the 4px buttonShape', () {
      final shape = result.textButtonTheme.style?.shape?.resolve({});
      expect(shape, WorkbenchLayoutConstants.buttonShape);
    });

    test('primary fill drives the primary color-scheme role, not the '
        'shared filled-button theme', () {
      // FilledButton reads colorScheme.primary for its resting fill. The
      // shared FilledButtonThemeData must NOT pin a backgroundColor — that
      // would also recolor FilledButton.tonal (see the distinct-fills
      // widget test below).
      expect(result.colorScheme.primary, testWorkbenchTheme.buttonBackground);
      expect(result.colorScheme.onPrimary, testWorkbenchTheme.buttonForeground);
      expect(result.filledButtonTheme.style?.backgroundColor, isNull);
    });

    test('filled button theme carries the compact size and text style', () {
      final style = result.filledButtonTheme.style;
      expect(style?.textStyle?.resolve({}), testWorkbenchTheme.buttonTextStyle);
      expect(
        style?.minimumSize?.resolve({})?.height,
        WorkbenchLayoutConstants.buttonHeight,
      );
      expect(style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });

    test('text button foreground resolves from the link accent token', () {
      final fg = result.textButtonTheme.style?.foregroundColor?.resolve({});
      expect(fg, testWorkbenchTheme.accentForeground);
    });

    test('secondary resting fill resolves from the secondary token', () {
      // FilledButton.tonal reads colorScheme.secondaryContainer for its
      // resting fill; the helper drives that role from the secondary token
      // so the tonal tier renders the VS Code secondary background.
      expect(
        result.colorScheme.secondaryContainer,
        testWorkbenchTheme.buttonSecondaryBackground,
      );
      expect(
        result.colorScheme.onSecondaryContainer,
        testWorkbenchTheme.buttonSecondaryForeground,
      );
    });

    testWidgets(
      'FilledButton and FilledButton.tonal render distinct resting fills',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: result,
            home: Scaffold(
              body: Column(
                children: [
                  FilledButton(
                    key: const Key('primary'),
                    onPressed: () {},
                    child: const Text('Primary'),
                  ),
                  FilledButton.tonal(
                    key: const Key('secondary'),
                    onPressed: () {},
                    child: const Text('Secondary'),
                  ),
                ],
              ),
            ),
          ),
        );

        Color fillOf(Key key) => tester
            .widgetList<Material>(
              find.descendant(
                of: find.byKey(key),
                matching: find.byType(Material),
              ),
            )
            .first
            .color!;

        final primaryFill = fillOf(const Key('primary'));
        final secondaryFill = fillOf(const Key('secondary'));

        // The two tiers must not collapse to the same fill — the bug a
        // shared FilledButtonThemeData backgroundColor would reintroduce.
        expect(primaryFill, isNot(secondaryFill));
        expect(primaryFill, testWorkbenchTheme.buttonBackground);
        expect(secondaryFill, testWorkbenchTheme.buttonSecondaryBackground);
      },
    );

    test('filled tiers pin elevation to 0 across all states', () {
      // FilledButton's default 1dp hover elevation renders a transparent
      // resting fill as opaque black through a PhysicalShape (a black
      // flash on un-hover in modern themes). Flat-always avoids it.
      final elevation = result.filledButtonTheme.style?.elevation;
      for (final states in const [
        <WidgetState>{},
        {WidgetState.hovered},
        {WidgetState.pressed},
        {WidgetState.focused},
      ]) {
        expect(elevation?.resolve(states), 0, reason: 'states: $states');
      }
    });

    test('filled button theme applies buttonBorder as its side', () {
      final side = result.filledButtonTheme.style?.side?.resolve({});
      expect(side?.color, testWorkbenchTheme.buttonBorder);
    });

    test('secondary tier stays visible via the border when its fill is '
        'transparent', () {
      // Dark Modern / Dark 2026 set button.secondaryBackground transparent
      // and rely on button.border. The shared filled-button border keeps
      // the tonal tier visible despite the transparent secondaryContainer.
      final modern = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(
          name: 'Modern',
          baseType: 'vs-dark',
          colors: {
            'button.secondaryBackground': Color(0x00000000),
            'button.border': Color(0xFF808080),
          },
        ),
      );
      final composed = applyWorkbenchChrome(ThemeData.dark(), modern);
      expect(composed.colorScheme.secondaryContainer, const Color(0x00000000));
      final side = composed.filledButtonTheme.style?.side?.resolve({});
      expect(side?.color, modern.buttonBorder);
      expect(side?.color, isNot(composed.colorScheme.secondaryContainer));
    });

    test('elevated button theme carries buttonShape for the jog carve-out', () {
      // ElevatedButton is not a VS Code tier, but the jog-control grid is
      // the sole remaining consumer and relies on the chrome for its 4px
      // shape (else it reverts to Material 3's StadiumBorder pill). Shape
      // only — no colour, size, or elevation.
      final shape = result.elevatedButtonTheme.style?.shape?.resolve({});
      expect(shape, WorkbenchLayoutConstants.buttonShape);
      expect(result.elevatedButtonTheme.style?.backgroundColor, isNull);
    });

    test('does not set an outlined button theme', () {
      // §9.20 migrates every OutlinedButton to FilledButton.tonal, so the
      // helper leaves the host's own outlined theme untouched.
      expect(result.outlinedButtonTheme, base.outlinedButtonTheme);
    });

    test('preserves host extensions already on the base', () {
      final withDomain = base.copyWith(
        extensions: const [_FakeDomainExtension()],
      );
      final composed = applyWorkbenchChrome(withDomain, testWorkbenchTheme);
      expect(composed.extension<_FakeDomainExtension>(), isNotNull);
      expect(composed.extension<WorkbenchTheme>(), same(testWorkbenchTheme));
    });

    test('replaces a stale WorkbenchTheme already on the base', () {
      final stale = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'Stale', baseType: 'vs-dark', colors: {}),
      );
      final withStale = base.copyWith(extensions: [stale]);
      final composed = applyWorkbenchChrome(withStale, testWorkbenchTheme);
      expect(composed.extension<WorkbenchTheme>(), same(testWorkbenchTheme));
    });
  });
}

class _FakeDomainExtension extends ThemeExtension<_FakeDomainExtension> {
  const _FakeDomainExtension();

  @override
  _FakeDomainExtension copyWith() => this;

  @override
  _FakeDomainExtension lerp(_FakeDomainExtension? other, double t) => this;
}

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

    test('segmented button theme carries the 4px buttonShape', () {
      final shape = result.segmentedButtonTheme.style?.shape?.resolve({});
      expect(shape, WorkbenchLayoutConstants.buttonShape);
    });

    test('segmented button theme carries the compact size and text style', () {
      final style = result.segmentedButtonTheme.style;
      expect(style?.textStyle?.resolve({}), testWorkbenchTheme.buttonTextStyle);
      expect(
        style?.minimumSize?.resolve({})?.height,
        WorkbenchLayoutConstants.buttonHeight,
      );
      expect(style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });

    test('segmented selected segment uses the active-toggle accent, '
        'not the primary-action blue', () {
      // The selected segment reads as "active" via VS Code's
      // inputOption.active* toggle treatment — a subtle accent tint plus a
      // solid accent border — distinct from the primary-action FilledButton
      // blue (buttonBackground), so the two don't compete.
      final style = result.segmentedButtonTheme.style;
      final selectedFill = style?.backgroundColor?.resolve({
        WidgetState.selected,
      });
      expect(selectedFill, testWorkbenchTheme.inputOptionActiveBackground);
      expect(selectedFill, isNot(testWorkbenchTheme.buttonBackground));

      final selectedSide = style?.side?.resolve({WidgetState.selected});
      expect(selectedSide?.color, testWorkbenchTheme.inputOptionActiveBorder);
    });

    test('segmented disabled segment dims its label so it reads as '
        'unavailable, not merely unselected', () {
      // The capped distance ladders disable segments; a disabled segment
      // must look different from an enabled-unselected one. M3 dims
      // disabled foreground; our override preserves that via the muted
      // descriptionForeground (an earlier version clobbered it).
      final fg = result.segmentedButtonTheme.style?.foregroundColor;
      expect(
        fg?.resolve({WidgetState.disabled}),
        testWorkbenchTheme.descriptionForeground,
      );
      expect(fg?.resolve(<WidgetState>{}), testWorkbenchTheme.foreground);
      expect(
        fg?.resolve({WidgetState.disabled}),
        isNot(fg?.resolve(<WidgetState>{})),
      );
    });

    test('does not set elevated or outlined button themes', () {
      // §9.20 canonicalizes every button — including the jog grid — on
      // FilledButton, so no ElevatedButton or OutlinedButton remains in
      // the UI. The helper installs neither theme; the host's own are
      // left untouched. One button widget, one theme, no parallel styling
      // to drift out of sync.
      expect(result.elevatedButtonTheme, base.elevatedButtonTheme);
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

/// The flat elevation both popup surfaces share — `workbenchMenuPanelStyle`
/// sets it for the shell's own menus, and the dropdown list derives from that
/// same style (§spec:chrome-material-theming).
const double _menuElevation = 2;

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

    test('icon button theme carries the 4px buttonShape and compact size', () {
      final style = result.iconButtonTheme.style;
      expect(style?.shape?.resolve({}), WorkbenchLayoutConstants.buttonShape);
      expect(
        style?.minimumSize?.resolve({})?.height,
        WorkbenchLayoutConstants.buttonHeight,
      );
      expect(style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });

    test('bare IconButton resolves its foreground from iconForeground, '
        'not the base onSurfaceVariant', () {
      // The issue (#9) MCVE: a bare IconButton must read its glyph color
      // from the chrome's iconForeground token, never fall back to the
      // host base ThemeData's onSurfaceVariant — the role the chrome
      // leaves unset, which renders icons near-invisible against the
      // chrome background.
      final fg = result.iconButtonTheme.style?.foregroundColor?.resolve({});
      expect(fg, isNotNull);
      expect(fg, testWorkbenchTheme.iconForeground);
      expect(fg, isNot(base.colorScheme.onSurfaceVariant));
    });

    test(
      'iconForeground resolves icon.foreground when the theme defines it',
      () {
        // A theme that sets icon.foreground drives the token directly.
        final defined = WorkbenchTheme.fromVscodeColorMap(
          const VscodeColorMap(
            name: 'Defined',
            baseType: 'vs-dark',
            colors: {'icon.foreground': Color(0xFFCCCCCC)},
          ),
        );
        final composed = applyWorkbenchChrome(ThemeData.dark(), defined);
        final fg = composed.iconButtonTheme.style?.foregroundColor?.resolve({});
        expect(fg, const Color(0xFFCCCCCC));
      },
    );

    test('iconForeground falls back to the VS Code default when the theme '
        'omits icon.foreground', () {
      // A theme without icon.foreground falls back to VS Code's registered
      // default (#C5C5C5 dark), not a base ColorScheme role.
      final undefined = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(
          name: 'Undefined',
          baseType: 'vs-dark',
          colors: {},
        ),
      );
      final composed = applyWorkbenchChrome(ThemeData.dark(), undefined);
      final fg = composed.iconButtonTheme.style?.foregroundColor?.resolve({});
      expect(fg, const Color(0xFFC5C5C5));
    });

    test('does not set elevated or outlined button themes', () {
      // §spec:chrome-material-theming canonicalizes every button — including the jog grid — on
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

  group('applyWorkbenchChrome menu and select family '
      '(§spec:chrome-material-theming)', () {
    final base = ThemeData.dark();
    final result = applyWorkbenchChrome(base, testWorkbenchTheme);

    test('installs the popup panel theme from the menu.* family', () {
      final style = result.menuTheme.style;
      expect(
        style?.backgroundColor?.resolve({}),
        testWorkbenchTheme.menuBackground,
      );
      expect(style?.elevation?.resolve({}), _menuElevation);
      expect(style?.shape?.resolve({}), const RoundedRectangleBorder());
    });

    test('installs the popup row theme from the menu.* family', () {
      final style = result.menuButtonTheme.style;
      expect(
        style?.foregroundColor?.resolve({}),
        testWorkbenchTheme.menuForeground,
      );
      expect(
        style?.backgroundColor?.resolve({WidgetState.hovered}),
        testWorkbenchTheme.menuSelectionBackground,
      );
      expect(
        style?.foregroundColor?.resolve({WidgetState.hovered}),
        testWorkbenchTheme.menuSelectionForeground,
      );
    });

    test('installs the menu bar strip theme from the menubar.* family', () {
      // MenuButtonTheme lands on a host MenuBar's top-level SubmenuButtons
      // whether the chrome wants it or not (Flutter exposes no
      // SubmenuButtonTheme), so the strip is already inside the family the
      // chrome themes. Leaving its panel at Material's surface would be
      // exactly the partial coverage the parity invariant forbids.
      final style = result.menuBarTheme.style;
      expect(
        style?.backgroundColor?.resolve({}),
        testWorkbenchTheme.menuBarBackground,
      );
      expect(style?.elevation?.resolve({}), 0);
    });

    test('installs the menu separator hairline', () {
      // Flutter menus separate groups with a plain Divider and expose no
      // menu-scoped divider theme, so the token lands on DividerTheme.
      expect(
        result.dividerTheme.color,
        testWorkbenchTheme.menuSeparatorBackground,
      );
      expect(result.dividerTheme.color, isNot(base.colorScheme.outlineVariant));
    });

    testWidgets('a bare DropdownMenu paints the dropdown family in a light '
        'theme too', (tester) async {
      final chrome = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'Light', baseType: 'vs', colors: {}),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: applyWorkbenchChrome(ThemeData.light(), chrome),
          home: const Scaffold(
            body: DropdownMenu<String>(
              initialSelection: 'One',
              dropdownMenuEntries: [
                DropdownMenuEntry(value: 'One', label: 'One'),
                DropdownMenuEntry(value: 'Two', label: 'Two'),
              ],
            ),
          ),
        ),
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.fillColor, chrome.dropdownBackground);

      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();
      final panel = popupPanelOf(tester, 'Two');
      expect(panel.color, chrome.dropdownListBackground);
      expect(panel.color, isNot(ThemeData.light().colorScheme.surface));
    });

    test('the dropdown trigger fills from dropdown.background at the '
        "chrome's button height, flat and rippleless", () {
      final decoration = result.dropdownMenuTheme.inputDecorationTheme;
      expect(decoration?.filled, isTrue);
      expect(decoration?.fillColor, testWorkbenchTheme.dropdownBackground);
      expect(decoration?.hoverColor, Colors.transparent);
      expect(
        decoration?.constraints?.minHeight,
        WorkbenchLayoutConstants.buttonHeight,
      );
    });

    test('the dropdown trigger draws a dropdown.border hairline', () {
      final decoration = result.dropdownMenuTheme.inputDecorationTheme;
      for (final border in [
        decoration?.border,
        decoration?.enabledBorder,
        decoration?.focusedBorder,
      ]) {
        expect(border, isA<OutlineInputBorder>());
        expect(
          (border as OutlineInputBorder).borderSide.color,
          testWorkbenchTheme.dropdownBorder,
        );
      }
    });

    test('the dropdown trigger takes the controls corner tier', () {
      // VS Code rounds the select at `--vscode-cornerRadius-small`
      // (selectBox.css), the same tier the chrome's buttons take.
      final border =
          result.dropdownMenuTheme.inputDecorationTheme?.border
              as OutlineInputBorder?;
      expect(border?.borderRadius, WorkbenchLayoutConstants.controlsRadius);
    });

    test('the dropdown label reads dropdown.foreground', () {
      expect(
        result.dropdownMenuTheme.textStyle?.color,
        testWorkbenchTheme.dropdownForeground,
      );
    });

    test('the open list resolves dropdown.listBackground, never a '
        'ColorScheme role the chrome leaves unset', () {
      // The #30 defect: a Material-surface popup standing against flat
      // chrome. The list panel resolves the dropdown family's own token.
      final style = result.dropdownMenuTheme.menuStyle;
      expect(
        style?.backgroundColor?.resolve({}),
        testWorkbenchTheme.dropdownListBackground,
      );
      expect(
        style?.backgroundColor?.resolve({}),
        isNot(base.colorScheme.surface),
      );
      expect(
        style?.backgroundColor?.resolve({}),
        isNot(base.colorScheme.surfaceContainer),
      );
      expect(style?.surfaceTintColor?.resolve({}), Colors.transparent);
    });

    test("the shell's popups and a host's dropdown popup share the flat "
        'elevation, border treatment and row height', () {
      // Each panel paints from its own token family, at one geometry.
      final menuStyle = result.menuTheme.style;
      final dropdownStyle = result.dropdownMenuTheme.menuStyle;
      expect(
        dropdownStyle?.elevation?.resolve({}),
        menuStyle?.elevation?.resolve({}),
      );
      expect(dropdownStyle?.shape?.resolve({}), menuStyle?.shape?.resolve({}));
      expect(
        dropdownStyle?.side?.resolve({})?.color,
        testWorkbenchTheme.dropdownBorder,
      );
      // Both lists render MenuItemButtons, which read one MenuButtonTheme —
      // so the rows are the same height by construction.
      expect(result.menuButtonTheme.style, isNotNull);
    });

    testWidgets('a bare DropdownMenu paints the trigger fill and the '
        'list background from the dropdown family', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: applyWorkbenchChrome(ThemeData.dark(), testWorkbenchTheme),
          home: const Scaffold(
            body: DropdownMenu<String>(
              initialSelection: 'One',
              dropdownMenuEntries: [
                DropdownMenuEntry(value: 'One', label: 'One'),
                DropdownMenuEntry(value: 'Two', label: 'Two'),
              ],
            ),
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(
        field.decoration?.fillColor,
        testWorkbenchTheme.dropdownBackground,
      );
      // Flat at the chrome's button height, not Material's 48px icon slot.
      expect(
        tester.getSize(find.byType(TextField)).height,
        WorkbenchLayoutConstants.buttonHeight,
      );

      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();

      final panel = popupPanelOf(tester, 'Two');
      expect(panel.color, testWorkbenchTheme.dropdownListBackground);
      expect(panel.elevation, _menuElevation);
    });

    testWidgets('a bare MenuAnchor paints its panel from the menu family', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: applyWorkbenchChrome(ThemeData.dark(), testWorkbenchTheme),
          home: Scaffold(
            body: MenuAnchor(
              menuChildren: const [MenuItemButton(child: Text('Command'))],
              builder: (context, controller, child) => TextButton(
                onPressed: controller.open,
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final panel = popupPanelOf(tester, 'Command');
      expect(panel.color, testWorkbenchTheme.menuBackground);
      expect(panel.elevation, _menuElevation);
    });

    test('a theme that omits dropdown.listBackground gives the list the '
        'trigger fill, in dark and in light', () {
      for (final baseType in ['vs-dark', 'vs']) {
        final chrome = WorkbenchTheme.fromVscodeColorMap(
          VscodeColorMap(
            name: 'Trigger Only',
            baseType: baseType,
            colors: const {'dropdown.background': Color(0xFF101112)},
          ),
        );
        final composed = applyWorkbenchChrome(
          baseType == 'vs' ? ThemeData.light() : ThemeData.dark(),
          chrome,
        );
        expect(
          composed.dropdownMenuTheme.menuStyle?.backgroundColor?.resolve({}),
          const Color(0xFF101112),
          reason: 'the $baseType list falls back to the trigger fill',
        );
      }
    });

    test('a theme that sets dropdown.listBackground gives the list that '
        'colour', () {
      final chrome = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(
          name: 'Listed',
          baseType: 'vs-dark',
          colors: {
            'dropdown.background': Color(0xFF101112),
            'dropdown.listBackground': Color(0xFF191A1B),
          },
        ),
      );
      final composed = applyWorkbenchChrome(ThemeData.dark(), chrome);
      expect(
        composed.dropdownMenuTheme.menuStyle?.backgroundColor?.resolve({}),
        const Color(0xFF191A1B),
      );
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

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

/// The flat elevation both popup surfaces share — `workbenchMenuPanelStyle`
/// sets it for the shell's own menus, and the dropdown list derives from that
/// same style (§spec:chrome-material-theming).
const double _menuElevation = 2;

/// Pump a bare, unstyled [DropdownMenu] under the chrome composed from
/// [base] and [chrome] — the host-side case the contract exists to cover.
Future<void> pumpBareSelect(
  WidgetTester tester,
  ThemeData base,
  WorkbenchTheme chrome,
) {
  return tester.pumpWidget(
    MaterialApp(
      theme: applyWorkbenchChrome(base, chrome),
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
}

void main() {
  group('menu row metrics (§spec:chrome-material-theming)', () {
    testWidgets('a popup menu row renders at the canon row height', (
      tester,
    ) async {
      await pumpBareSelect(tester, ThemeData.dark(), testWorkbenchTheme);
      await tester.tap(find.byType(DropdownMenu<String>));
      await tester.pumpAndSettle();

      // VS Code sizes `.action-menu-item` at 24px; Material's MenuItemButton
      // defaults far taller.
      final row = tester.getSize(
        find.widgetWithText(MenuItemButton, 'Two').first,
      );
      expect(row.height, WorkbenchLayoutConstants.menuRowHeight);
    });

    testWidgets('the panel insets its rows from its own edge', (tester) async {
      await pumpBareSelect(tester, ThemeData.dark(), testWorkbenchTheme);
      final style = Theme.of(
        tester.element(find.byType(DropdownMenu<String>)),
      ).dropdownMenuTheme.menuStyle!;
      // VS Code gives each row `margin: 0 4px` and the panel `padding: 4px 0`,
      // so a row's rounded fill stops short of the panel edge and the end rows
      // clear its corners.
      expect(
        style.padding!.resolve({}),
        const EdgeInsets.symmetric(
          horizontal: WorkbenchLayoutConstants.menuRowInset,
          vertical: WorkbenchLayoutConstants.menuPanelVerticalPadding,
        ),
      );
    });
  });

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

    group('IconButton selected state is the VS Code toggle '
        '(§spec:chrome-material-theming)', () {
      final style = result.iconButtonTheme.style;
      const selected = {WidgetState.selected};
      const unselected = <WidgetState>{};

      test('a selected IconButton fills from inputOption.activeBackground', () {
        expect(
          style?.backgroundColor?.resolve(selected),
          testWorkbenchTheme.inputOptionActiveBackground,
        );
      });

      test('an unselected IconButton keeps no fill', () {
        expect(style?.backgroundColor?.resolve(unselected), isNull);
      });

      test('a selected IconButton draws its glyph in '
          'inputOption.activeForeground', () {
        expect(
          style?.foregroundColor?.resolve(selected),
          testWorkbenchTheme.inputOptionActiveForeground,
        );
      });

      test('a selected IconButton strokes inputOption.activeBorder', () {
        expect(
          style?.side?.resolve(selected)?.color,
          testWorkbenchTheme.inputOptionActiveBorder,
        );
      });

      test('a hovered IconButton fills toolbar.hoverBackground with no '
          'overlay', () {
        // VS Code paints a hovered toolbar action with a background fill
        // (workbench style.css), not a state layer over it.
        const hovered = {WidgetState.hovered};
        expect(
          style?.backgroundColor?.resolve(hovered),
          testWorkbenchTheme.toolbarHoverBackground,
        );
        expect(style?.overlayColor?.resolve(hovered)?.a ?? 0, 0);
      });

      test('a hovered selected IconButton keeps its active fill', () {
        // Upstream's Toggle sets the checked fill inline, which outranks
        // its :hover rule, so hovering a checked toggle changes nothing.
        const hoveredSelected = {WidgetState.hovered, WidgetState.selected};
        expect(
          style?.backgroundColor?.resolve(hoveredSelected),
          testWorkbenchTheme.inputOptionActiveBackground,
        );
        expect(style?.overlayColor?.resolve(hoveredSelected)?.a ?? 0, 0);
      });

      test('the press overlay still derives from iconForeground', () {
        // IconButton.styleFrom builds its press overlay from the
        // foregroundColor it is given; the hover override must keep it.
        final overlay = style?.overlayColor?.resolve({
          WidgetState.hovered,
          WidgetState.pressed,
        });
        expect(overlay, isNotNull);
        expect(overlay!.a, greaterThan(0));
        expect(overlay.r, testWorkbenchTheme.iconForeground.r);
        expect(overlay.g, testWorkbenchTheme.iconForeground.g);
        expect(overlay.b, testWorkbenchTheme.iconForeground.b);
      });

      test('an unselected IconButton draws no stroke', () {
        final side = style?.side?.resolve(unselected);
        expect(side == null || side.color.a == 0, isTrue);
      });

      testWidgets('the toggle tokens win over Material 3 selected defaults', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: result,
            home: Scaffold(
              body: IconButton(
                isSelected: true,
                icon: const Icon(Icons.abc),
                onPressed: () {},
              ),
            ),
          ),
        );
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byType(IconButton),
            matching: find.byType(Material),
          ),
        );
        expect(material.color, testWorkbenchTheme.inputOptionActiveBackground);
        expect(
          IconTheme.of(tester.element(find.byIcon(Icons.abc))).color,
          testWorkbenchTheme.inputOptionActiveForeground,
        );
      });
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
      await pumpBareSelect(tester, ThemeData.light(), chrome);
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
      await pumpBareSelect(tester, ThemeData.dark(), testWorkbenchTheme);

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
      // The list's own hairline, painted into the panel's shape.
      expect(
        (panel.shape! as OutlinedBorder).side.color,
        testWorkbenchTheme.dropdownBorder,
      );
      expect(panel.surfaceTintColor, Colors.transparent);
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

  group('applyWorkbenchChrome outlined and elevated buttons '
      '(§spec:chrome-material-theming)', () {
    final result = applyWorkbenchChrome(ThemeData.dark(), testWorkbenchTheme);
    final styles = {
      'OutlinedButton': result.outlinedButtonTheme.style,
      'ElevatedButton': result.elevatedButtonTheme.style,
    };

    for (final MapEntry(key: name, value: style) in styles.entries) {
      test('$name carries the shared flat compact sizing', () {
        expect(style?.shape?.resolve({}), WorkbenchLayoutConstants.buttonShape);
        expect(
          style?.minimumSize?.resolve({})?.height,
          WorkbenchLayoutConstants.buttonHeight,
        );
        expect(
          style?.padding?.resolve({}),
          WorkbenchLayoutConstants.buttonPadding,
        );
        expect(
          style?.textStyle?.resolve({}),
          testWorkbenchTheme.buttonTextStyle,
        );
        expect(style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
      });

      test('$name renders as the secondary tier', () {
        expect(
          style?.backgroundColor?.resolve({}),
          testWorkbenchTheme.buttonSecondaryBackground,
        );
        expect(
          style?.foregroundColor?.resolve({}),
          testWorkbenchTheme.buttonSecondaryForeground,
        );
        expect(
          style?.side?.resolve({})?.color,
          testWorkbenchTheme.buttonBorder,
        );
      });

      test('$name pins elevation to 0 across all states', () {
        for (final states in const [
          <WidgetState>{},
          {WidgetState.hovered},
          {WidgetState.pressed},
          {WidgetState.focused},
        ]) {
          expect(
            style?.elevation?.resolve(states),
            0,
            reason: 'states: $states',
          );
        }
      });
    }

    testWidgets('bare outlined and elevated buttons render flat, compact and '
        'filled like FilledButton.tonal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: result,
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilledButton.tonal(
                  key: const Key('tonal'),
                  onPressed: () {},
                  child: const Text('Tonal'),
                ),
                OutlinedButton(
                  key: const Key('outlined'),
                  onPressed: () {},
                  child: const Text('Outlined'),
                ),
                OutlinedButton.icon(
                  key: const Key('outlinedIcon'),
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Outlined icon'),
                ),
                ElevatedButton(
                  key: const Key('elevated'),
                  onPressed: () {},
                  child: const Text('Elevated'),
                ),
              ],
            ),
          ),
        ),
      );

      Material materialOf(String key) => tester
          .widgetList<Material>(
            find.descendant(
              of: find.byKey(Key(key)),
              matching: find.byType(Material),
            ),
          )
          .first;

      final tonal = materialOf('tonal');
      for (final key in ['outlined', 'outlinedIcon', 'elevated']) {
        final material = materialOf(key);
        expect(material.color, tonal.color, reason: key);
        expect(material.textStyle?.color, tonal.textStyle?.color, reason: key);
        expect(material.elevation, 0, reason: key);
        expect(
          (material.shape! as RoundedRectangleBorder).borderRadius,
          WorkbenchLayoutConstants.buttonShape.borderRadius,
          reason: key,
        );
        expect(
          tester.getSize(find.byKey(Key(key))).height,
          WorkbenchLayoutConstants.buttonHeight,
          reason: key,
        );
      }
    });
  });

  group('applyWorkbenchChrome text input (§spec:chrome-material-theming)', () {
    // Distinct colours so a leak between the input and dropdown families, or
    // between the resting and focused hairlines, shows up as a mismatch.
    final chrome = WorkbenchTheme.fromVscodeColorMap(
      const VscodeColorMap(
        name: 'Input',
        baseType: 'vs-dark',
        colors: {
          'input.background': Color(0xFF101010),
          'input.foreground': Color(0xFFE0E0E0),
          'input.border': Color(0xFF404040),
          'input.placeholderForeground': Color(0xFF808080),
          'focusBorder': Color(0xFF0078D4),
          'dropdown.background': Color(0xFF202020),
          'dropdown.border': Color(0xFF505050),
        },
      ),
    );
    final result = applyWorkbenchChrome(ThemeData.dark(), chrome);
    final decoration = result.inputDecorationTheme;

    test('fills from input.background, flat and dense, with no floating '
        'label', () {
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, chrome.inputBackground);
      expect(decoration.hoverColor, Colors.transparent);
      expect(decoration.focusColor, Colors.transparent);
      expect(decoration.isDense, isTrue);
      expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.never);
      expect(
        decoration.contentPadding,
        WorkbenchLayoutConstants.inputBoxPadding,
      );
    });

    test('draws an input.border hairline that focusBorder replaces on '
        'focus, at the controls corner tier', () {
      for (final border in [
        decoration.border,
        decoration.enabledBorder,
        decoration.disabledBorder,
      ]) {
        final outline = border! as OutlineInputBorder;
        expect(outline.borderSide.color, chrome.inputBorder);
        expect(outline.borderSide.width, 1);
        expect(outline.borderRadius, WorkbenchLayoutConstants.controlsRadius);
      }
      final focused = decoration.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.color, chrome.focusBorder);
      expect(focused.borderSide.width, 1);
      expect(focused.borderRadius, WorkbenchLayoutConstants.controlsRadius);
    });

    test('paints the placeholder from input.placeholderForeground', () {
      expect(decoration.hintStyle?.color, chrome.inputPlaceholderForeground);
      // A label never floats, so it stands in the box as a placeholder.
      expect(decoration.labelStyle?.color, chrome.inputPlaceholderForeground);
    });

    testWidgets('a bare TextField renders a dense input-family box whose '
        'hairline turns focusBorder on focus', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: result,
          home: const Scaffold(
            body: TextField(decoration: InputDecoration(hintText: 'Search')),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(TextField)).height,
        WorkbenchLayoutConstants.buttonHeight,
      );
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.color,
        chrome.inputForeground,
      );
      // The decorator draws its fill, then its hairline.
      final decorator = find.byType(InputDecorator);
      expect(
        decorator,
        paints
          ..rrect(color: chrome.inputBackground)
          ..rrect(color: chrome.inputBorder),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(
        decorator,
        paints
          ..rrect(color: chrome.inputBackground)
          ..rrect(color: chrome.focusBorder),
      );
    });

    testWidgets('the DropdownMenu trigger keeps its dropdown decoration', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: result,
          home: const Scaffold(
            body: DropdownMenu<String>(
              label: Text('Label'),
              initialSelection: 'One',
              dropdownMenuEntries: [
                DropdownMenuEntry(value: 'One', label: 'One'),
              ],
            ),
          ),
        ),
      );

      // The decoration the trigger's field renders with, after the field
      // has applied `ThemeData.inputDecorationTheme` over the select's own.
      final decorator = find.byType(InputDecorator);
      final rendered = tester.widget<InputDecorator>(decorator).decoration;
      expect(rendered.fillColor, chrome.dropdownBackground);
      expect(
        rendered.contentPadding,
        WorkbenchLayoutConstants.selectBoxPadding,
      );
      expect(rendered.floatingLabelBehavior, FloatingLabelBehavior.auto);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).style.color,
        chrome.dropdownForeground,
      );
      // The floated label opens a gap in the hairline, so it draws as a path.
      final dropdownPaint = paints
        ..rrect(color: chrome.dropdownBackground)
        ..path(color: chrome.dropdownBorder);
      expect(decorator, dropdownPaint);

      // The select draws no focus border of its own, as upstream's does not.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(decorator, dropdownPaint);
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

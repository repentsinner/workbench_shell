import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

/// A theme whose every `button.*` colour is distinct, so a finder that keys
/// on one token cannot match a surface painted from another.
final WorkbenchTheme splitTheme = WorkbenchTheme.fromVscodeColorMap(
  const VscodeColorMap(
    name: 'Split',
    baseType: 'vs-dark',
    colors: {
      'button.background': Color(0xFF101010),
      'button.hoverBackground': Color(0xFF202020),
      'button.foreground': Color(0xFF303030),
      'button.border': Color(0xFF404040),
      'button.separator': Color(0xFF505050),
      'button.secondaryBackground': Color(0xFF606060),
      'button.secondaryHoverBackground': Color(0xFF707070),
      'button.secondaryForeground': Color(0xFF808080),
      'button.secondaryBorder': Color(0xFF909090),
    },
  ),
);

class _StashIntent extends Intent {
  const _StashIntent();
}

void main() {
  final control = find.byType(WorkbenchSplitButton);
  final primary = find.widgetWithText(FilledButton, 'Commit');
  final disclosure = find.widgetWithIcon(
    FilledButton,
    Symbols.expand_more_rounded,
  );
  final pipe = find.byWidgetPredicate(
    (w) => w is ColoredBox && w.color == splitTheme.buttonSeparator,
  );
  final outline = find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null,
  );

  /// The `Material` a half fills, whose colour is the resolved background.
  Color fillOf(WidgetTester tester, Finder half) => tester
      .widgetList<Material>(
        find.descendant(of: half, matching: find.byType(Material)),
      )
      .first
      .color!;

  /// The stroke the control declares, read from its own decoration so the
  /// geometry assertions below measure against the outline actually drawn.
  double strokeWidth(WidgetTester tester) {
    final decoration =
        tester.widget<DecoratedBox>(outline).decoration as BoxDecoration;
    return decoration.border!.top.width;
  }

  List<String> menuLabels(WidgetTester tester) => tester
      .widgetList<MenuItemButton>(find.byType(MenuItemButton))
      .map((button) => (button.child! as Text).data!)
      .toList();

  Widget host({
    VoidCallback? onPressed,
    bool secondary = false,
    bool addPrimaryActionToDropdown = true,
    List<WorkbenchMenuEntry>? actions,
    VoidCallback? onStash,
    double? width,
  }) {
    Widget button = WorkbenchSplitButton(
      label: 'Commit',
      onPressed: onPressed,
      secondary: secondary,
      addPrimaryActionToDropdown: addPrimaryActionToDropdown,
      actions:
          actions ??
          const [
            WorkbenchViewMenuTab(intent: _StashIntent(), label: 'Stash'),
          ],
    );
    if (width != null) {
      button = SizedBox(width: width, child: button);
    }
    return MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: [splitTheme]),
      home: Scaffold(
        body: Actions(
          actions: {
            _StashIntent: CallbackAction<_StashIntent>(
              onInvoke: (_) {
                onStash?.call();
                return null;
              },
            ),
          },
          // Left-aligned so the control shrink-wraps unless a test hands it
          // a width of its own.
          child: Align(alignment: Alignment.topLeft, child: button),
        ),
      ),
    );
  }

  /// A control with no primary action, which is how a host disables it.
  Widget disabledHost() => host();

  group('WorkbenchSplitButton geometry (§spec:split-button)', () {
    testWidgets('stands one control high, at the canon button height', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      expect(
        tester.getSize(control).height,
        WorkbenchLayoutConstants.buttonHeight,
      );
    });

    testWidgets('draws one outline around both halves, not one each', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      // A single bordered box, and it frames the whole control rather than
      // either half.
      expect(outline, findsOneWidget);
      expect(tester.getRect(outline), tester.getRect(control));
      // Neither half carries a stroke of its own, so no doubled line forms
      // where they meet.
      for (final half in [primary, disclosure]) {
        final side = tester.widget<FilledButton>(half).style!.side!.resolve({});
        expect(side, BorderSide.none);
      }
    });

    testWidgets('the halves and the pipe tile the control with no gap', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      final stroke = strokeWidth(tester);
      final controlRect = tester.getRect(control);
      final primaryRect = tester.getRect(primary);
      final pipeRect = tester.getRect(pipe);
      final disclosureRect = tester.getRect(disclosure);

      expect(primaryRect.left, controlRect.left + stroke);
      expect(primaryRect.right, pipeRect.left);
      expect(pipeRect.right, disclosureRect.left);
      expect(disclosureRect.right, controlRect.right - stroke);
    });

    testWidgets('the pipe is inset from the top and bottom edges', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      final stroke = strokeWidth(tester);
      final controlRect = tester.getRect(control);
      final pipeRect = tester.getRect(pipe);
      const inset = WorkbenchLayoutConstants.spacingSize40;

      // `padding: 4px 0` inside the outline — a rule, not a full-height
      // border between two buttons.
      expect(pipeRect.top, controlRect.top + stroke + inset);
      expect(pipeRect.bottom, controlRect.bottom - stroke - inset);
      expect(pipeRect.height, lessThan(controlRect.height));
      expect(pipeRect.width, 1.0);
    });

    testWidgets('the pipe paints button.separator, not the outline stroke', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      expect(pipe, findsOneWidget);
      final decoration =
          tester.widget<DecoratedBox>(outline).decoration as BoxDecoration;
      expect(decoration.border!.top.color, splitTheme.buttonBorder);
      expect(splitTheme.buttonSeparator, isNot(splitTheme.buttonBorder));
    });

    testWidgets('the primary half absorbs a width the host allocates', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}, width: 300));
      final stroke = strokeWidth(tester);
      final controlRect = tester.getRect(control);
      expect(controlRect.width, 300);
      // No slack inside the outline: the disclosure still ends at the edge.
      expect(tester.getRect(disclosure).right, controlRect.right - stroke);
    });
  });

  group('WorkbenchSplitButton behaviour (§spec:split-button)', () {
    testWidgets('the primary half runs its action and opens no menu', (
      tester,
    ) async {
      var runs = 0;
      await tester.pumpWidget(host(onPressed: () => runs++));
      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(runs, 1);
      expect(find.byType(MenuItemButton), findsNothing);
    });

    testWidgets('the disclosure lists the primary action first', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(menuLabels(tester), ['Commit', 'Stash']);
    });

    testWidgets('the primary row runs the primary action', (tester) async {
      var runs = 0;
      await tester.pumpWidget(host(onPressed: () => runs++));
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Commit'));
      await tester.pumpAndSettle();
      expect(runs, 1);
    });

    testWidgets('a host row dispatches its intent', (tester) async {
      var stashes = 0;
      await tester.pumpWidget(
        host(onPressed: () {}, onStash: () => stashes++),
      );
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Stash'));
      await tester.pumpAndSettle();
      expect(stashes, 1);
    });

    testWidgets('a host can suppress the primary row', (tester) async {
      await tester.pumpWidget(
        host(onPressed: () {}, addPrimaryActionToDropdown: false),
      );
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(menuLabels(tester), ['Stash']);
    });

    testWidgets('the disclosure reports its expanded state', (tester) async {
      final expandable = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.expanded != null,
      );
      await tester.pumpWidget(host(onPressed: () {}));
      expect(tester.widget<Semantics>(expandable).properties.expanded, isFalse);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(expandable).properties.expanded, isTrue);
    });

    testWidgets('the disclosure carries the canon title', (tester) async {
      await tester.pumpWidget(host(onPressed: () {}));
      expect(find.byTooltip('More Actions...'), findsOneWidget);
    });
  });

  group('WorkbenchSplitButton menu surface (§spec:split-button)', () {
    testWidgets('renders at the shell menu fill and row height', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      await tester.tap(disclosure);
      await tester.pumpAndSettle();

      // The same popup surface the View menu paints — not a second style.
      expect(popupPanelOf(tester, 'Commit').color, splitTheme.menuBackground);
      expect(
        tester.getSize(find.widgetWithText(MenuItemButton, 'Commit')).height,
        WorkbenchLayoutConstants.menuRowHeight,
      );
    });
  });

  group('WorkbenchSplitButton tiers (§spec:split-button)', () {
    Future<void> expectTierPaint(
      WidgetTester tester, {
      required bool secondary,
      required Color fill,
      required Color border,
    }) async {
      await tester.pumpWidget(host(onPressed: () {}, secondary: secondary));
      expect(fillOf(tester, primary), fill);
      expect(fillOf(tester, disclosure), fill);
      final decoration =
          tester.widget<DecoratedBox>(outline).decoration as BoxDecoration;
      expect(decoration.border!.top.color, border);
    }

    testWidgets('the primary tier paints the button.* family', (tester) async {
      await expectTierPaint(
        tester,
        secondary: false,
        fill: splitTheme.buttonBackground,
        border: splitTheme.buttonBorder,
      );
    });

    testWidgets('the secondary tier paints the button.secondary* family', (
      tester,
    ) async {
      await expectTierPaint(
        tester,
        secondary: true,
        fill: splitTheme.buttonSecondaryBackground,
        border: splitTheme.buttonSecondaryBorder,
      );
      // The tier resolves its own stroke rather than inheriting the primary's.
      final decoration =
          tester.widget<DecoratedBox>(outline).decoration as BoxDecoration;
      expect(decoration.border!.top.color, isNot(splitTheme.buttonBorder));
    });

    Future<void> expectHoverFill(
      WidgetTester tester, {
      required bool secondary,
      required Color hover,
    }) async {
      await tester.pumpWidget(host(onPressed: () {}, secondary: secondary));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(primary));
      await tester.pumpAndSettle();
      expect(fillOf(tester, primary), hover);
    }

    testWidgets('the primary tier hovers to button.hoverBackground', (
      tester,
    ) async {
      await expectHoverFill(
        tester,
        secondary: false,
        hover: splitTheme.buttonHoverBackground,
      );
    });

    testWidgets('the secondary tier hovers to its own hover token', (
      tester,
    ) async {
      await expectHoverFill(
        tester,
        secondary: true,
        hover: splitTheme.buttonSecondaryHoverBackground,
      );
    });
  });

  group('WorkbenchSplitButton disabled state (§spec:split-button)', () {
    final dim = find.descendant(of: control, matching: find.byType(Opacity));

    testWidgets('an enabled control carries no dim', (tester) async {
      await tester.pumpWidget(host(onPressed: () {}));
      expect(dim, findsNothing);
    });

    testWidgets('one dim covers both halves and the pipe', (tester) async {
      await tester.pumpWidget(disabledHost());
      expect(dim, findsOneWidget);
      expect(tester.widget<Opacity>(dim).opacity, 0.4);
      // Every part fades through the same layer, so none dims on its own.
      for (final part in [primary, disclosure, pipe]) {
        expect(find.ancestor(of: part, matching: dim), findsOneWidget);
      }
    });

    testWidgets('the halves keep their token fills under the dim', (
      tester,
    ) async {
      await tester.pumpWidget(disabledHost());
      // A Material disabled fill here would dim a second time, and from a
      // colour-scheme role rather than the button family.
      expect(fillOf(tester, primary), splitTheme.buttonBackground);
      expect(fillOf(tester, disclosure), splitTheme.buttonBackground);
    });

    testWidgets('the disclosure opens no menu while disabled', (tester) async {
      await tester.pumpWidget(disabledHost());
      await tester.tap(disclosure, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNothing);
    });
  });

  group('WorkbenchSplitButton theming (§spec:split-button)', () {
    testWidgets('a theme switch moves the control with the chrome', (
      tester,
    ) async {
      await tester.pumpWidget(host(onPressed: () {}));
      expect(fillOf(tester, primary), splitTheme.buttonBackground);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [testWorkbenchTheme]),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: WorkbenchSplitButton(
                label: 'Commit',
                onPressed: () {},
                actions: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fillOf(tester, primary), testWorkbenchTheme.buttonBackground);
      expect(
        testWorkbenchTheme.buttonBackground,
        isNot(splitTheme.buttonBackground),
      );
    });
  });
}

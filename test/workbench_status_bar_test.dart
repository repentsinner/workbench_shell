import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/src/workbench_surface_treatment.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('WorkbenchStatusBar', () {
    testWidgets('draws no top border under the Modern UI treatment', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(const WorkbenchStatusBar()));

      // `floatingPanels.css` hides the classic `status-border-top` rule under
      // the floating-panels treatment, so the bar meets the band above it
      // without a hairline (§spec:modern-ui-surfaces).
      final decoration =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.byType(Row),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.border, isNull);
      expect(decoration.color, isNotNull);
    });

    testWidgets('draws the top border again with the treatment off', (
      tester,
    ) async {
      // Base VS Code rules the bar off from the band above it with
      // `statusBar.border`; the treatment hides that rule, not the token
      // (§spec:modern-ui-surfaces).
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [testWorkbenchTheme]),
          home: const Scaffold(
            body: WorkbenchSurfaceTreatment(
              modernUI: false,
              child: WorkbenchStatusBar(),
            ),
          ),
        ),
      );

      final decoration =
          tester
                  .widget<Container>(
                    find
                        .ancestor(
                          of: find.byType(Row),
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(
        (decoration.border! as Border).top.color,
        testWorkbenchTheme.statusBarBorder,
      );
    });

    testWidgets('renders leading and trailing items with spacer between', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchStatusBar(
            leading: [WorkbenchStatusBarItem(label: 'Left')],
            trailing: [WorkbenchStatusBarItem(label: 'Right')],
          ),
        ),
      );

      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
    });

    testWidgets('uses shell-defined height from layout constants', (
      tester,
    ) async {
      await tester.pumpWidget(wrapWithTheme(const WorkbenchStatusBar()));
      final size = tester.getSize(find.byType(WorkbenchStatusBar));
      expect(size.height, WorkbenchLayoutConstants.statusBarHeight);
    });

    testWidgets('insets its item row at the part tier', (tester) async {
      // `floatingPanels.css`: `size60` horizontally, `size20` vertically
      // (§spec:modern-ui-surfaces).
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchStatusBar(
            leading: [WorkbenchStatusBarItem(label: 'Left')],
          ),
        ),
      );
      expect(
        _barContainer(tester).padding,
        const EdgeInsets.symmetric(
          horizontal: WorkbenchLayoutConstants.spacingSize60,
          vertical: WorkbenchLayoutConstants.spacingSize20,
        ),
      );
    });

    testWidgets('drops the part inset with the treatment off', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchStatusBar(
            leading: [WorkbenchStatusBarItem(label: 'Left')],
          ),
          modernUI: false,
        ),
      );
      expect(_barContainer(tester).padding, EdgeInsets.zero);
    });

    testWidgets('the inset content box still holds an icon and its label', (
      tester,
    ) async {
      // The bar is a fixed 22px, so the vertical inset shrinks the content box
      // to 18px. Neither the 17px status icon nor the 12px label may outgrow
      // it (§spec:modern-ui-surfaces).
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchStatusBar(
            leading: [
              WorkbenchStatusBarItem(
                icon: Symbols.wifi_rounded,
                label: 'Ln 1, Col 1',
              ),
            ],
          ),
        ),
      );
      const content =
          WorkbenchLayoutConstants.statusBarHeight -
          2 * WorkbenchLayoutConstants.spacingSize20;
      expect(
        tester.getSize(find.byIcon(Symbols.wifi_rounded)).height,
        lessThanOrEqualTo(content),
      );
      expect(
        tester.getSize(find.text('Ln 1, Col 1')).height,
        lessThanOrEqualTo(content),
      );
    });
  });

  group('WorkbenchStatusBarItem', () {
    testWidgets('renders label only when icon is null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const WorkbenchStatusBarItem(label: 'Idle')),
      );
      expect(find.text('Idle'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders icon and label when both provided', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchStatusBarItem(
            icon: Symbols.wifi_rounded,
            label: 'Connected',
          ),
        ),
      );
      expect(find.text('Connected'), findsOneWidget);
      expect(find.byIcon(Symbols.wifi_rounded), findsOneWidget);
    });
  });

  group('WorkbenchStatusBarAction', () {
    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarAction(
            label: 'Tasks',
            icon: Symbols.task_rounded,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('wraps in tooltip when tooltip provided', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarAction(
            label: 'Tasks',
            tooltip: 'Open user tasks',
            onTap: () {},
          ),
        ),
      );
      expect(find.byType(Tooltip), findsOneWidget);
    });

    testWidgets('rounds its ink response at the controls tier', (tester) async {
      // `statusBar.css` rounds `.statusbar-item` at `cornerRadius.small`, so a
      // tapped or hovered item reads as a pill (§spec:modern-ui-surfaces).
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarAction(label: 'Tasks', onTap: () {}),
        ),
      );
      expect(
        tester.widget<InkWell>(find.byType(InkWell)).borderRadius,
        WorkbenchLayoutConstants.controlsRadius,
      );
    });

    testWidgets('leaves the ink response square with the treatment off', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarAction(label: 'Tasks', onTap: () {}),
          modernUI: false,
        ),
      );
      expect(
        tester.widget<InkWell>(find.byType(InkWell)).borderRadius,
        isNull,
      );
    });
  });
}

/// The bar's own chrome container — the `Container` carrying its fill, its
/// base-treatment top border and the treatment's part inset.
Container _barContainer(WidgetTester tester) => tester.widget<Container>(
  find.ancestor(of: find.byType(Row), matching: find.byType(Container)).first,
);

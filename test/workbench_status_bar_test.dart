import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
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
  });
}

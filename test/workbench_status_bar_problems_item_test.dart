import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('WorkbenchStatusBarProblemsItem', () {
    testWidgets('renders all three counts including zeros', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarProblemsItem(
            errorCount: 2,
            warningCount: 0,
            infoCount: 5,
            onTap: () {},
          ),
        ),
      );

      // Every count (including zero) is always visible — matches VS Code.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarProblemsItem(
            errorCount: 0,
            warningCount: 0,
            infoCount: 0,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(WorkbenchStatusBarProblemsItem));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('wraps in a tooltip with the default summary message', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarProblemsItem(
            errorCount: 3,
            warningCount: 1,
            infoCount: 4,
            onTap: () {},
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, '3 errors, 1 warnings, 4 info');
    });

    testWidgets('honours an explicit tooltip override', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarProblemsItem(
            errorCount: 0,
            warningCount: 0,
            infoCount: 0,
            tooltip: 'Problems',
            onTap: () {},
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Problems');
    });

    testWidgets('icon colours match helperStyle color', (tester) async {
      Widget buildHarness(WorkbenchTheme theme) {
        return MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [theme]),
          home: Scaffold(
            body: WorkbenchStatusBarProblemsItem(
              errorCount: 1,
              warningCount: 1,
              infoCount: 1,
              onTap: () {},
            ),
          ),
        );
      }

      // First theme: a distinct helperStyle color.
      final overridden = testWorkbenchTheme.copyWith(
        helperStyle: testWorkbenchTheme.helperStyle.copyWith(
          color: const Color(0xFFAA1111),
        ),
      );
      await tester.pumpWidget(buildHarness(overridden));
      await tester.pumpAndSettle();

      Color colorOf(IconData data) =>
          tester.widget<Icon>(find.byIcon(data)).color!;

      // All three icons share the same helperStyle color.
      expect(colorOf(Icons.error_outline), const Color(0xFFAA1111));
      expect(colorOf(Icons.warning_amber_outlined), const Color(0xFFAA1111));
      expect(colorOf(Icons.info_outline), const Color(0xFFAA1111));

      // Second theme: different helperStyle color. Confirm icons update.
      final other = testWorkbenchTheme.copyWith(
        helperStyle: testWorkbenchTheme.helperStyle.copyWith(
          color: const Color(0xFF004400),
        ),
      );
      await tester.pumpWidget(buildHarness(other));
      await tester.pumpAndSettle();

      expect(colorOf(Icons.error_outline), const Color(0xFF004400));
      expect(colorOf(Icons.warning_amber_outlined), const Color(0xFF004400));
      expect(colorOf(Icons.info_outline), const Color(0xFF004400));
    });
  });
}

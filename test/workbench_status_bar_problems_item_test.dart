import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
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
      expect(find.byIcon(Symbols.error_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.warning_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.info_rounded), findsOneWidget);
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

    testWidgets('icon colours match statusBarTextStyle color', (tester) async {
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

      // Status bar text and icons paint in statusBar.foreground so
      // they read against the blue status bar background. The old
      // contract inherited helperStyle (descriptionForeground) and
      // produced grey-on-blue — a legibility regression. Regression
      // test against that: icons must follow statusBarTextStyle,
      // not helperStyle.
      final overridden = testWorkbenchTheme.copyWith(
        statusBarTextStyle: testWorkbenchTheme.statusBarTextStyle.copyWith(
          color: const Color(0xFFAA1111),
        ),
      );
      await tester.pumpWidget(buildHarness(overridden));
      await tester.pumpAndSettle();

      Color colorOf(IconData data) =>
          tester.widget<Icon>(find.byIcon(data)).color!;

      // All three icons share the statusBarTextStyle color.
      expect(colorOf(Symbols.error_rounded), const Color(0xFFAA1111));
      expect(colorOf(Symbols.warning_rounded), const Color(0xFFAA1111));
      expect(colorOf(Symbols.info_rounded), const Color(0xFFAA1111));

      // Second theme: different statusBarTextStyle color.
      final other = testWorkbenchTheme.copyWith(
        statusBarTextStyle: testWorkbenchTheme.statusBarTextStyle.copyWith(
          color: const Color(0xFF004400),
        ),
      );
      await tester.pumpWidget(buildHarness(other));
      await tester.pumpAndSettle();

      expect(colorOf(Symbols.error_rounded), const Color(0xFF004400));
      expect(colorOf(Symbols.warning_rounded), const Color(0xFF004400));
      expect(colorOf(Symbols.info_rounded), const Color(0xFF004400));
    });
  });
}

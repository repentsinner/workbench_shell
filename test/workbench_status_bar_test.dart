import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('WorkbenchStatusBar', () {
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
          const WorkbenchStatusBarItem(icon: Icons.wifi, label: 'Connected'),
        ),
      );
      expect(find.text('Connected'), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
    });
  });

  group('WorkbenchStatusBarAction', () {
    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchStatusBarAction(
            label: 'Tasks',
            icon: Icons.task,
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

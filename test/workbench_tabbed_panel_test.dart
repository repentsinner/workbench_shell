import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('WorkbenchTabbedPanel', () {
    List<WorkbenchPanelTab> tabs() => [
      WorkbenchPanelTab(
        id: 'a',
        label: const Tab(text: 'A'),
        contentBuilder: (_) => const Text('content-a'),
      ),
      WorkbenchPanelTab(
        id: 'b',
        label: const Tab(text: 'B'),
        contentBuilder: (_) => const Text('content-b'),
      ),
    ];

    testWidgets('renders tab strip and first tab content by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 400,
            height: 300,
            child: WorkbenchTabbedPanel(tabs: tabs(), onTogglePanel: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('content-a'), findsOneWidget);
    });

    testWidgets('initialTabId focuses requested tab on first frame', (
      tester,
    ) async {
      final activeIds = <String>[];
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 400,
            height: 300,
            child: WorkbenchTabbedPanel(
              tabs: tabs(),
              initialTabId: 'b',
              onTogglePanel: () {},
              onActiveTabChanged: activeIds.add,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(activeIds, isNotEmpty);
      expect(activeIds.first, 'b');
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 1);
    });

    testWidgets('onRegisterFocusTab can drive the controller', (tester) async {
      ValueChanged<String>? focus;
      final activeIds = <String>[];
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 400,
            height: 300,
            child: WorkbenchTabbedPanel(
              tabs: tabs(),
              onTogglePanel: () {},
              onRegisterFocusTab: (f) => focus = f,
              onActiveTabChanged: activeIds.add,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(focus, isNotNull);
      focus!('b');
      await tester.pumpAndSettle();
      expect(activeIds.last, 'b');
    });

    testWidgets('close button fires onTogglePanel', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 400,
            height: 300,
            child: WorkbenchTabbedPanel(
              tabs: tabs(),
              onTogglePanel: () => toggled++,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(toggled, 1);
    });

    testWidgets('uses theme tokens for tab strip colors', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            width: 400,
            height: 300,
            child: WorkbenchTabbedPanel(tabs: tabs(), onTogglePanel: () {}),
          ),
        ),
      );
      await tester.pump();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.labelColor, testWorkbenchTheme.tabBarLabelColor);
      expect(
        tabBar.unselectedLabelColor,
        testWorkbenchTheme.tabBarUnselectedLabelColor,
      );
      expect(tabBar.dividerColor, testWorkbenchTheme.tabBarDividerColor);
      final indicator = tabBar.indicator! as UnderlineTabIndicator;
      expect(
        indicator.borderSide.color,
        testWorkbenchTheme.tabBarIndicatorColor,
      );
    });
  });
}

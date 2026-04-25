import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('WorkbenchTabbedPanel', () {
    List<WorkbenchPanelTab> tabs() => [
      WorkbenchPanelTab(
        id: 'a',
        label: 'Output',
        contentBuilder: (_) => const Text('content-a'),
      ),
      WorkbenchPanelTab(
        id: 'b',
        label: 'Debug Console',
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

      // Shell uppercases natural-case labels per §3 canon enforcement.
      expect(find.text('OUTPUT'), findsOneWidget);
      expect(find.text('DEBUG CONSOLE'), findsOneWidget);
      expect(find.text('Output'), findsNothing);
      expect(find.text('Debug Console'), findsNothing);
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

      await tester.tap(find.byIcon(Symbols.close_rounded));
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

    testWidgets('renders no badge widget when badge is null', (tester) async {
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

      // Badge would render as a count Text inside a decorated Container —
      // when no badge is supplied, no count text appears.
      expect(find.textContaining(RegExp(r'^\d+$')), findsNothing);
    });

    testWidgets(
      'renders inline badge chrome (count + accent-coloured pill) when badge != null',
      (tester) async {
        final badged = [
          WorkbenchPanelTab(
            id: 'tasks',
            label: 'Tasks',
            badge: const PanelTabBadge(count: 3),
            contentBuilder: (_) => const Text('content-tasks'),
          ),
          WorkbenchPanelTab(
            id: 'output',
            label: 'Output',
            contentBuilder: (_) => const Text('content-output'),
          ),
        ];

        await tester.pumpWidget(
          wrapWithTheme(
            SizedBox(
              width: 400,
              height: 300,
              child: WorkbenchTabbedPanel(tabs: badged, onTogglePanel: () {}),
            ),
          ),
        );
        await tester.pump();

        // Count rendered.
        expect(find.text('3'), findsOneWidget);
        // The pill is painted in the panel-active accent (the same
        // colour as the active-tab underline). Resolve the rounded
        // container with that fill.
        final containers = tester.widgetList<Container>(find.byType(Container));
        final pill = containers.firstWhere((c) {
          final deco = c.decoration;
          if (deco is! BoxDecoration) return false;
          return deco.color == testWorkbenchTheme.tabBarIndicatorColor;
        }, orElse: () => Container());
        expect(pill.decoration, isA<BoxDecoration>());
      },
    );
  });
}

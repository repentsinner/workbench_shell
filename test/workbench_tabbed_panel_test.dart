import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

      // Shell uppercases natural-case labels per §spec:capability-boundary canon enforcement.
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
        // The pill is painted in the badge accent
        // (`badge.background`), which is a separate slot from the
        // panel-active underline — same colour in some themes,
        // different in others (Light Modern paints the badge in a
        // saturated blue against a near-black underline).
        // Resolve the rounded container with that fill.
        final containers = tester.widgetList<Container>(find.byType(Container));
        final pill = containers.firstWhere((c) {
          final deco = c.decoration;
          if (deco is! BoxDecoration) return false;
          return deco.color == testWorkbenchTheme.badgeBackground;
        }, orElse: () => Container());
        expect(pill.decoration, isA<BoxDecoration>());
      },
    );

    // Suppressing the Material hover overlay is part of the §spec:tab-strip-canon canon
    // contract — every state must resolve to transparent so no box
    // paints behind the tab content.
    testWidgets('TabBar.overlayColor resolves to transparent for every state', (
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

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final overlay = tabBar.overlayColor;
      expect(overlay, isNotNull);
      const probedStates = <Set<WidgetState>>{
        <WidgetState>{},
        <WidgetState>{WidgetState.hovered},
        <WidgetState>{WidgetState.focused},
        <WidgetState>{WidgetState.pressed},
        <WidgetState>{WidgetState.selected},
        <WidgetState>{WidgetState.selected, WidgetState.hovered},
      };
      for (final states in probedStates) {
        expect(
          overlay!.resolve(states),
          Colors.transparent,
          reason: 'overlay should be transparent for $states',
        );
      }
    });

    testWidgets('hover on inactive tab tints label to active-text color', (
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
      await tester.pumpAndSettle();

      // The 'b' tab (rendered uppercase as 'DEBUG CONSOLE') is
      // inactive; initial focus is 'a' (rendered as 'OUTPUT').
      final inactiveLabel = find.descendant(
        of: find.byType(TabBar),
        matching: find.text('DEBUG CONSOLE'),
      );
      expect(inactiveLabel, findsOneWidget);

      Color labelColor() {
        final renderText = tester.renderObject<RenderParagraph>(inactiveLabel);
        return renderText.text.style!.color!;
      }

      expect(
        labelColor(),
        testWorkbenchTheme.tabBarUnselectedLabelColor,
        reason: 'pre-hover inactive tab uses unselected label color',
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(inactiveLabel));
      await tester.pumpAndSettle();

      expect(
        labelColor(),
        testWorkbenchTheme.tabBarLabelColor,
        reason:
            'hovered inactive tab tints label to active-tab text color, '
            'not the selection underline',
      );

      await gesture.moveTo(Offset.zero);
      await tester.pumpAndSettle();

      expect(
        labelColor(),
        testWorkbenchTheme.tabBarUnselectedLabelColor,
        reason: 'post-hover inactive tab reverts to unselected label color',
      );
    });

    testWidgets(
      'tab-list length change keeps the active tab aligned with initialTabId',
      (tester) async {
        final activeIds = <String>[];
        late StateSetter rebuild;
        var current = <WorkbenchPanelTab>[
          WorkbenchPanelTab(
            id: 'a',
            label: 'A',
            contentBuilder: (_) => const Text('content-a'),
          ),
          WorkbenchPanelTab(
            id: 'b',
            label: 'B',
            contentBuilder: (_) => const Text('content-b'),
          ),
          WorkbenchPanelTab(
            id: 'c',
            label: 'C',
            contentBuilder: (_) => const Text('content-c'),
          ),
        ];

        await tester.pumpWidget(
          wrapWithTheme(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return SizedBox(
                  width: 400,
                  height: 300,
                  child: WorkbenchTabbedPanel(
                    tabs: current,
                    // Host preserves its active id and re-passes it.
                    initialTabId: 'b',
                    onTogglePanel: () {},
                    onActiveTabChanged: activeIds.add,
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);

        // Remove the first tab. The host still considers 'b' active, so
        // the rendered tab must follow 'b' (now index 0), not clamp to
        // the old numeric index 1 (which is now 'c').
        rebuild(() => current = [current[1], current[2]]);
        await tester.pump();

        final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
        expect(controller.index, 0);
        expect(find.text('content-b'), findsOneWidget);
        expect(activeIds.last, 'b');
      },
    );

    testWidgets('same-length reorder follows initialTabId', (tester) async {
      final activeIds = <String>[];
      late StateSetter rebuild;
      final a = WorkbenchPanelTab(
        id: 'a',
        label: 'A',
        contentBuilder: (_) => const Text('content-a'),
      );
      final b = WorkbenchPanelTab(
        id: 'b',
        label: 'B',
        contentBuilder: (_) => const Text('content-b'),
      );
      var current = <WorkbenchPanelTab>[a, b];

      await tester.pumpWidget(
        wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return SizedBox(
                width: 400,
                height: 300,
                child: WorkbenchTabbedPanel(
                  tabs: current,
                  initialTabId: 'a',
                  onTogglePanel: () {},
                  onActiveTabChanged: activeIds.add,
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);

      // Swap order; host keeps 'a' active. 'a' is now index 1.
      rebuild(() => current = [b, a]);
      await tester.pump();

      final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      expect(controller.index, 1);
      expect(activeIds.last, 'a');
    });

    testWidgets('hover on active tab does not change its label color', (
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
      await tester.pumpAndSettle();

      final activeLabel = find.descendant(
        of: find.byType(TabBar),
        matching: find.text('OUTPUT'),
      );
      expect(activeLabel, findsOneWidget);

      Color labelColor() {
        final renderText = tester.renderObject<RenderParagraph>(activeLabel);
        return renderText.text.style!.color!;
      }

      expect(labelColor(), testWorkbenchTheme.tabBarLabelColor);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(activeLabel));
      await tester.pumpAndSettle();

      expect(
        labelColor(),
        testWorkbenchTheme.tabBarLabelColor,
        reason: 'active tab label color is unchanged on hover',
      );
    });
  });
}

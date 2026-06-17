import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/src/workbench_sash.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

final _testTheme = testWorkbenchTheme;

final _testItems = [
  const ActivityBarItem(
    id: 'explorer',
    label: 'Explorer',
    icon: Symbols.folder_rounded,
    sortOrder: 100,
  ),
  const ActivityBarItem(
    id: 'search',
    label: 'Search',
    icon: Symbols.search_rounded,
    sortOrder: 200,
  ),
  const ActivityBarItem(
    id: 'settings',
    label: 'Settings',
    icon: Symbols.settings_rounded,
    zone: ActivityBarZone.bottom,
    sortOrder: 900,
  ),
];

/// Single-view container spec whose merged body renders an id-identifiable
/// text. Replaces the retired `sidebarBuilder: (id) => Text('Sidebar: $id')`
/// — the host now supplies typed view descriptors, not a sidebar-body widget
/// (§spec:capability-boundary).
WorkbenchViewContainerSpec _sidebarSpec(String id) {
  return WorkbenchViewContainerSpec(
    mergeSingleView: true,
    views: [
      WorkbenchViewDescriptor(
        id: id,
        title: id,
        bodyBuilder: (_) => Center(child: Text('Sidebar: $id')),
      ),
    ],
  );
}

Widget _buildApp({
  List<ActivityBarItem>? items,
  bool showBottomPanel = true,
  Widget? statusBar,
}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
    home: WorkbenchLayout(
      activityBarItems: items ?? _testItems,
      editor: const Center(child: Text('Editor')),
      containerBuilder: _sidebarSpec,
      bottomPanel: const Center(child: Text('Panel')),
      statusBar: statusBar ?? const SizedBox(height: 22, child: Text('Status')),
      showBottomPanel: showBottomPanel,
    ),
  );
}

void main() {
  group('WorkbenchLayout', () {
    testWidgets('renders activity bar with items', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.search_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.settings_rounded), findsOneWidget);
    });

    testWidgets('renders editor content', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.text('Editor'), findsOneWidget);
    });

    testWidgets('renders sidebar with initial section', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.text('Sidebar: explorer'), findsOneWidget);
      expect(find.text('EXPLORER'), findsOneWidget);
    });

    testWidgets('switches sidebar on activity bar tap', (tester) async {
      await tester.pumpWidget(_buildApp());

      // Tap search icon
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sidebar: search'), findsOneWidget);
      expect(find.text('SEARCH'), findsOneWidget);
    });

    testWidgets('toggles sidebar on tapping active section', (tester) async {
      await tester.pumpWidget(_buildApp());

      // Sidebar visible initially
      expect(find.text('EXPLORER'), findsOneWidget);

      // Tap active section hides sidebar
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();
      expect(find.text('EXPLORER'), findsNothing);

      // Tap again shows sidebar
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();
      expect(find.text('EXPLORER'), findsOneWidget);
    });

    testWidgets('renders bottom panel when visible', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.text('Panel'), findsOneWidget);
    });

    testWidgets('hides bottom panel when showBottomPanel is false', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(showBottomPanel: false));

      expect(find.text('Panel'), findsNothing);
    });

    testWidgets('renders status bar', (tester) async {
      await tester.pumpWidget(_buildApp());

      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('panel sash sits fully inside the panel — no overhang clipped '
        'to a half-width highlight band', (tester) async {
      // The editor↔panel sash must render its full canonical width like the
      // sidebar and view-pane sashes. Placing it as an overhang above the
      // panel's top edge lets the panel Stack's hardEdge clip eat the
      // overhanging half of the highlight band, so it paints at half width.
      // The sash sits fully inside the panel (top: 0), matching the view-pane
      // sash placement.
      const panelKey = ValueKey('panel-fill');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: _sidebarSpec,
            bottomPanel: const ColoredBox(
              key: panelKey,
              color: Color(0xFF202020),
              child: SizedBox.expand(),
            ),
            statusBar: const SizedBox(height: 22),
          ),
        ),
      );

      final sash = find.byWidgetPredicate(
        (w) => w is WorkbenchSash && w.axis == Axis.vertical,
      );
      expect(sash, findsOneWidget);

      // The panel content is inset ~1px below the panel's top edge by the
      // border; the sash must not start above that edge (which would overhang
      // into the clipped region above the panel).
      final panelContentTop = tester.getRect(find.byKey(panelKey)).top;
      final sashTop = tester.getRect(sash).top;
      expect(sashTop, greaterThanOrEqualTo(panelContentTop - 2));
    });

    testWidgets('sidebar sash is transparent at rest (VS Code canon) — no '
        'opaque background strip over its hit area', (tester) async {
      // Canon: `.monaco-sash` is transparent until hover/active; the visible
      // seam is the region border (sideBar.border), not the sash. The sidebar
      // sash overlays the sidebar's right edge like the panel/view-pane sashes,
      // so at rest it paints nothing.
      await tester.pumpWidget(_buildApp());

      final sidebarSash = find.byWidgetPredicate(
        (w) => w is WorkbenchSash && w.axis == Axis.horizontal,
      );
      expect(sidebarSash, findsOneWidget);

      final opaqueFill = find.descendant(
        of: sidebarSash,
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == _testTheme.sideBarBackground,
        ),
      );
      expect(opaqueFill, findsNothing);
    });

    testWidgets('bottom panel top border is not overdrawn by panel child', (
      tester,
    ) async {
      // Regression: a bare DecoratedBox paints its Border *behind*
      // the child. When the bottom panel's own background widget
      // (e.g. ColoredBox(panelBackground) inside WorkbenchTabbedPanel)
      // fills the full rect, it overdraws the 1px border region and
      // the border disappears. The layout must use a Container so
      // Container-added padding insets the child by the border
      // dimensions, keeping the border visible.
      const panelBgKey = ValueKey('panel-bg');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: _sidebarSpec,
            bottomPanel: Container(
              key: panelBgKey,
              color: const Color(0xFFDEADBE),
              child: const Center(child: Text('Panel')),
            ),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
          ),
        ),
      );

      final panelBgFinder = find.byKey(panelBgKey);
      expect(panelBgFinder, findsOneWidget);

      final borderedContainer = find.ancestor(
        of: panelBgFinder,
        matching: find.byWidgetPredicate((w) {
          if (w is! Container) return false;
          final decoration = w.decoration;
          if (decoration is! BoxDecoration) return false;
          final border = decoration.border;
          return border is Border &&
              border.top.color == _testTheme.panelBorder &&
              border.top.width == 1.0;
        }),
      );
      expect(
        borderedContainer,
        findsOneWidget,
        reason:
            'panel border must be drawn via Container (not bare '
            'DecoratedBox) so Container-added padding insets the '
            'panel child past the border region',
      );

      final borderRect = tester.getRect(borderedContainer);
      final panelRect = tester.getRect(panelBgFinder);
      expect(
        panelRect.top - borderRect.top,
        closeTo(1.0, 0.001),
        reason:
            'bottom panel child should be inset 1px from the bordered '
            "container's top edge so the border remains visible",
      );
    });
  });

  group('controlled view-container nav', () {
    testWidgets('host drives active container via activeViewContainerId', (
      tester,
    ) async {
      String active = 'explorer';
      late StateSetter setOuter;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return WorkbenchLayout(
                activityBarItems: _testItems,
                editor: const Center(child: Text('Editor')),
                containerBuilder: _sidebarSpec,
                bottomPanel: const Center(child: Text('Panel')),
                statusBar: const SizedBox(height: 22, child: Text('Status')),
                activeViewContainerId: active,
                onViewContainerChanged: (id) => setState(() => active = id),
              );
            },
          ),
        ),
      );

      expect(find.text('Sidebar: explorer'), findsOneWidget);

      // Tap search icon — host updates state
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Sidebar: search'), findsOneWidget);

      // Externally drive a section change
      setOuter(() => active = 'settings');
      await tester.pumpAndSettle();
      expect(find.text('Sidebar: settings'), findsOneWidget);
    });
  });

  group('view-container inversion', () {
    // §spec:view-stack: the sidebar body is a typed view container built from
    // descriptors, not a host widget. The activity bar selects a container;
    // the shell renders its descriptor stack.
    testWidgets('renders a multi-view container as a stacked WorkbenchViewContainer', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: (id) => id == 'explorer'
                ? WorkbenchViewContainerSpec(
                    views: [
                      WorkbenchViewDescriptor(
                        id: 'open-editors',
                        title: 'Open Editors',
                        bodyBuilder: (_) => const Text('editors-body'),
                      ),
                      WorkbenchViewDescriptor(
                        id: 'outline',
                        title: 'Outline',
                        bodyBuilder: (_) => const Text('outline-body'),
                      ),
                    ],
                  )
                : _sidebarSpec(id),
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
          ),
        ),
      );

      // The container renders one WorkbenchViewContainer from the descriptors.
      expect(find.byType(WorkbenchViewContainer), findsOneWidget);
      // Two views → two collapsible panes, each header uppercased.
      expect(find.text('OPEN EDITORS'), findsOneWidget);
      expect(find.text('OUTLINE'), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsNWidgets(2));
      expect(find.text('editors-body'), findsOneWidget);
    });

    testWidgets('empty views list renders an empty container gracefully', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: (_) =>
                const WorkbenchViewContainerSpec(views: []),
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
          ),
        ),
      );
      // No panes, no crash; the heading still shows.
      expect(find.text('EXPLORER'), findsOneWidget);
      expect(find.byType(WorkbenchViewPane), findsNothing);
    });
  });

  group('view-container retention (§spec:view-container-state)', () {
    // A multi-pane spec helper: two collapsible panes whose bodies carry an
    // identifiable text and whose bodyBuilder runs a side effect when built.
    WorkbenchViewContainerSpec twoPaneSpec(
      String id, {
      VoidCallback? onBodyBuilt,
    }) {
      return WorkbenchViewContainerSpec(
        views: [
          WorkbenchViewDescriptor(
            id: '$id-a',
            title: '$id Alpha',
            bodyBuilder: (_) {
              onBodyBuilt?.call();
              return Text('$id-body-a');
            },
          ),
          WorkbenchViewDescriptor(
            id: '$id-b',
            title: '$id Beta',
            bodyBuilder: (_) => Text('$id-body-b'),
          ),
        ],
      );
    }

    testWidgets('LAZY: a never-selected container is not built; selecting it '
        'first runs its body builder', (tester) async {
      var searchBuilt = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            // Explorer is active by default; search is never selected until the
            // test taps it.
            containerBuilder: (id) => id == 'search'
                ? twoPaneSpec('search', onBodyBuilt: () => searchBuilt++)
                : twoPaneSpec(id),
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
          ),
        ),
      );

      // Search's activity-bar entry was never selected: its body builder must
      // not have run, and its body must be absent from the tree.
      expect(searchBuilt, 0);
      expect(find.text('search-body-a'), findsNothing);

      // Select search — now its body builder runs.
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();
      expect(searchBuilt, greaterThan(0));
      expect(find.text('search-body-a'), findsOneWidget);
    });

    testWidgets('RETENTION: a collapsed pane stays collapsed after switching '
        'containers and back', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: twoPaneSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
          ),
        ),
      );

      // Explorer active: both pane bodies visible.
      expect(find.text('explorer-body-a'), findsOneWidget);
      expect(find.text('explorer-body-b'), findsOneWidget);

      // Collapse the first pane by tapping its header.
      await tester.tap(find.text('EXPLORER ALPHA'));
      await tester.pumpAndSettle();
      expect(find.text('explorer-body-a'), findsNothing);
      expect(find.text('explorer-body-b'), findsOneWidget);

      // Switch to search, then back to explorer.
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();
      expect(find.text('explorer-body-a'), findsNothing);
      expect(find.text('search-body-a'), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();

      // The collapse survived the round trip: pane A is still collapsed.
      expect(find.text('explorer-body-a'), findsNothing);
      expect(find.text('explorer-body-b'), findsOneWidget);
    });

    testWidgets('RETENTION survives sidebar hide/show: collapse persists '
        'across toggling the active container icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: twoPaneSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
          ),
        ),
      );

      // Collapse pane A.
      await tester.tap(find.text('EXPLORER ALPHA'));
      await tester.pumpAndSettle();
      expect(find.text('explorer-body-a'), findsNothing);

      // Hide the sidebar (tap active icon), then show it again.
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();

      // Collapse survived hide/show.
      expect(find.text('explorer-body-a'), findsNothing);
      expect(find.text('explorer-body-b'), findsOneWidget);
    });

    testWidgets('two containers reusing the same view id keep independent '
        'pane state', (tester) async {
      // Both explorer and search declare a view id "shared". Collapsing it in
      // explorer must not collapse it in search.
      WorkbenchViewContainerSpec sharedIdSpec(String id) {
        return WorkbenchViewContainerSpec(
          views: [
            WorkbenchViewDescriptor(
              id: 'shared',
              title: '$id Shared',
              bodyBuilder: (_) => Text('$id-shared-body'),
            ),
            WorkbenchViewDescriptor(
              id: '$id-other',
              title: '$id Other',
              bodyBuilder: (_) => Text('$id-other-body'),
            ),
          ],
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: sharedIdSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
          ),
        ),
      );

      // Collapse the shared pane in explorer.
      await tester.tap(find.text('EXPLORER SHARED'));
      await tester.pumpAndSettle();
      expect(find.text('explorer-shared-body'), findsNothing);

      // Switch to search: its shared pane is independent, still expanded.
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();
      expect(find.text('search-shared-body'), findsOneWidget);
    });
  });

  group('ActivityBarItem', () {
    test('equality based on id', () {
      const a = ActivityBarItem(
        id: 'test',
        label: 'Test',
        icon: Symbols.star_rounded,
      );
      const b = ActivityBarItem(
        id: 'test',
        label: 'Different Label',
        icon: Symbols.circle_rounded,
      );
      expect(a, equals(b));
    });

    test('inequality for different ids', () {
      const a = ActivityBarItem(
        id: 'test1',
        label: 'Test',
        icon: Symbols.star_rounded,
      );
      const b = ActivityBarItem(
        id: 'test2',
        label: 'Test',
        icon: Symbols.star_rounded,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('WorkbenchTheme', () {
    test('copyWith preserves unmodified values', () {
      final modified = _testTheme.copyWith(
        editorBackground: const Color(0xFF000000),
      );
      expect(modified.editorBackground, const Color(0xFF000000));
      expect(modified.activityBarBackground, _testTheme.activityBarBackground);
    });

    test('lerp interpolates between themes', () {
      final other = _testTheme.copyWith(
        editorBackground: const Color(0xFFFFFFFF),
      );
      final result = _testTheme.lerp(other, 0.5);
      expect(result.editorBackground, isNot(_testTheme.editorBackground));
      expect(result.editorBackground, isNot(other.editorBackground));
    });
  });

  group('WorkbenchLayoutConstants', () {
    test('activity bar width is 48', () {
      expect(WorkbenchLayoutConstants.activityBarWidth, 48.0);
    });

    test('sidebar defaults are reasonable', () {
      expect(
        WorkbenchLayoutConstants.sidebarMinWidth,
        lessThan(WorkbenchLayoutConstants.sidebarDefaultWidth),
      );
      expect(
        WorkbenchLayoutConstants.sidebarDefaultWidth,
        lessThan(WorkbenchLayoutConstants.sidebarMaxWidth),
      );
    });
  });
}

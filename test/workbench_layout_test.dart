import 'package:flutter/gestures.dart';
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
  double? initialSidebarWidth,
  double? initialPanelHeight,
  ValueChanged<double>? onSidebarWidthChangeEnd,
  ValueChanged<double>? onPanelHeightChangeEnd,
  WorkbenchSidebarPosition? sidebarPosition,
  ValueChanged<WorkbenchSidebarPosition>? onSidebarPositionChanged,
  WorkbenchPanelAlignment? panelAlignment,
  ValueChanged<WorkbenchPanelAlignment>? onPanelAlignmentChanged,
  WorkbenchViewContainerSpec Function(String)? containerBuilder,
  String? secondaryViewContainerId,
  ValueChanged<String>? onSecondaryViewContainerChanged,
  bool? secondarySideBarVisible,
  ValueChanged<bool>? onSecondarySideBarVisibilityChanged,
  double? initialSecondarySideBarWidth,
  ValueChanged<double>? onSecondarySideBarWidthChangeEnd,
}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
    home: WorkbenchLayout(
      activityBarItems: items ?? _testItems,
      editor: const Center(child: Text('Editor')),
      containerBuilder: containerBuilder ?? _sidebarSpec,
      bottomPanel: const Center(child: Text('Panel')),
      statusBar: statusBar ?? const SizedBox(height: 22, child: Text('Status')),
      showBottomPanel: showBottomPanel,
      initialSidebarWidth: initialSidebarWidth,
      initialPanelHeight: initialPanelHeight,
      onSidebarWidthChangeEnd: onSidebarWidthChangeEnd,
      onPanelHeightChangeEnd: onPanelHeightChangeEnd,
      sidebarPosition: sidebarPosition,
      onSidebarPositionChanged: onSidebarPositionChanged,
      panelAlignment: panelAlignment,
      onPanelAlignmentChanged: onPanelAlignmentChanged,
      secondaryViewContainerId: secondaryViewContainerId,
      onSecondaryViewContainerChanged: onSecondaryViewContainerChanged,
      secondarySideBarVisible: secondarySideBarVisible,
      onSecondarySideBarVisibilityChanged: onSecondarySideBarVisibilityChanged,
      initialSecondarySideBarWidth: initialSecondarySideBarWidth,
      onSecondarySideBarWidthChangeEnd: onSecondarySideBarWidthChangeEnd,
    ),
  );
}

/// The horizontal sash resizes the sidebar width; the vertical sash resizes the
/// panel height. Each seam's live dimension is the sash's [value]
/// (§spec:workbench-layout).
WorkbenchSash _sash(WidgetTester tester, Axis axis) => tester.widget<WorkbenchSash>(
  find.byWidgetPredicate((w) => w is WorkbenchSash && w.axis == axis),
);

Finder _sashFinder(Axis axis) =>
    find.byWidgetPredicate((w) => w is WorkbenchSash && w.axis == axis);

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

    testWidgets('RETENTION survives sidebar position flip: collapse persists '
        'when the bar moves left↔right', (tester) async {
      // The bar travels to the opposite edge by reordering the layout Row.
      // Without stable element identity Flutter rebuilds the whole row from
      // scratch and the retained pane State is discarded (§spec:sidebar-position).
      Widget app(WorkbenchSidebarPosition position) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
        home: WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const Center(child: Text('Editor')),
          containerBuilder: twoPaneSpec,
          bottomPanel: const Center(child: Text('Panel')),
          statusBar: const SizedBox(height: 22, child: Text('Status')),
          sidebarPosition: position,
          onSidebarPositionChanged: (_) {},
        ),
      );

      await tester.pumpWidget(app(WorkbenchSidebarPosition.left));

      // Collapse pane A on the left edge.
      await tester.tap(find.text('EXPLORER ALPHA'));
      await tester.pumpAndSettle();
      expect(find.text('explorer-body-a'), findsNothing);

      // Move the bar to the right edge.
      await tester.pumpWidget(app(WorkbenchSidebarPosition.right));
      await tester.pumpAndSettle();

      // The collapse survived the move — the bar moved, it did not rebuild.
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

  group('outer sash seed-plus-commit (§spec:resize-geometry)', () {
    // Sidebar width and panel height are shell-owned: seeded by initial…,
    // committed once on drag-end via …ChangeEnd. There is no controlled
    // geometry property and no per-frame host callback.

    testWidgets('seeds the sidebar at initialSidebarWidth', (tester) async {
      await tester.pumpWidget(_buildApp(initialSidebarWidth: 420));
      expect(_sash(tester, Axis.horizontal).value, 420);
    });

    testWidgets('seeds the panel at initialPanelHeight', (tester) async {
      await tester.pumpWidget(_buildApp(initialPanelHeight: 320));
      expect(_sash(tester, Axis.vertical).value, 320);
    });

    testWidgets('falls back to the default seed when initial… is null', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      expect(
        _sash(tester, Axis.horizontal).value,
        WorkbenchLayoutConstants.sidebarDefaultWidth,
      );
      expect(
        _sash(tester, Axis.vertical).value,
        WorkbenchLayoutConstants.panelDefaultHeight,
      );
    });

    testWidgets('sidebar drag resizes live and commits once on release', (
      tester,
    ) async {
      final ends = <double>[];
      await tester.pumpWidget(_buildApp(onSidebarWidthChangeEnd: ends.add));

      final before = _sash(tester, Axis.horizontal).value;
      final gesture = await tester.startGesture(
        tester.getCenter(_sashFinder(Axis.horizontal)),
      );

      // Per-frame: the shell owns the width and relayouts live (growSign +1)...
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      expect(_sash(tester, Axis.horizontal).value, greaterThan(before));
      // ...but nothing commits mid-drag.
      expect(ends, isEmpty);

      // Release: exactly one commit carrying the final clamped width.
      await gesture.up();
      await tester.pump();
      expect(ends, hasLength(1));
      expect(ends.single, _sash(tester, Axis.horizontal).value);
    });

    testWidgets('panel drag resizes live and commits once on release', (
      tester,
    ) async {
      final ends = <double>[];
      await tester.pumpWidget(_buildApp(onPanelHeightChangeEnd: ends.add));

      final before = _sash(tester, Axis.vertical).value;
      final gesture = await tester.startGesture(
        tester.getCenter(_sashFinder(Axis.vertical)),
      );

      // Drag up grows the panel (growSign -1).
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      expect(_sash(tester, Axis.vertical).value, greaterThan(before));
      expect(ends, isEmpty);

      await gesture.up();
      await tester.pump();
      expect(ends, hasLength(1));
      expect(ends.single, _sash(tester, Axis.vertical).value);
    });

    testWidgets('double-click resets the sidebar to the default width and '
        'commits it (§spec:workbench-layout)', (tester) async {
      final ends = <double>[];
      await tester.pumpWidget(
        _buildApp(initialSidebarWidth: 420, onSidebarWidthChangeEnd: ends.add),
      );
      expect(_sash(tester, Axis.horizontal).value, 420);

      final center = tester.getCenter(_sashFinder(Axis.horizontal));
      await tester.tapAt(center);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(center);
      await tester.pump();

      expect(
        _sash(tester, Axis.horizontal).value,
        WorkbenchLayoutConstants.sidebarDefaultWidth,
      );
      // The reset commits through the same change-end seam so the host persists
      // it (§spec:resize-geometry).
      expect(ends, [WorkbenchLayoutConstants.sidebarDefaultWidth]);
    });

    testWidgets('double-click resets the panel to the default height and '
        'commits it (§spec:workbench-layout)', (tester) async {
      final ends = <double>[];
      await tester.pumpWidget(
        _buildApp(initialPanelHeight: 320, onPanelHeightChangeEnd: ends.add),
      );
      expect(_sash(tester, Axis.vertical).value, 320);

      final center = tester.getCenter(_sashFinder(Axis.vertical));
      await tester.tapAt(center);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(center);
      await tester.pump();

      expect(
        _sash(tester, Axis.vertical).value,
        WorkbenchLayoutConstants.panelDefaultHeight,
      );
      expect(ends, [WorkbenchLayoutConstants.panelDefaultHeight]);
    });
  });

  group('Zen mode (§spec:editing-modes)', () {
    testWidgets('uncontrolled: zen hides all chrome, leaving the editor', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: _sidebarSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
            initialZenMode: true,
          ),
        ),
      );

      // Editor remains; every chrome surface is gone.
      expect(find.text('Editor'), findsOneWidget);
      expect(find.byIcon(Symbols.folder_rounded), findsNothing);
      expect(find.text('EXPLORER'), findsNothing);
      expect(find.text('Panel'), findsNothing);
      expect(find.text('Status'), findsNothing);
    });

    testWidgets('controlled: host drives zenMode and is notified on toggle', (
      tester,
    ) async {
      bool zen = false;
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
                zenMode: zen,
                onZenModeChanged: (next) => setState(() => zen = next),
              );
            },
          ),
        ),
      );

      // Chrome visible while controlled value is false.
      expect(find.text('Status'), findsOneWidget);
      expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);

      // Host flips its own state on → chrome disappears.
      setOuter(() => zen = true);
      await tester.pumpAndSettle();
      expect(find.text('Status'), findsNothing);
      expect(find.byIcon(Symbols.folder_rounded), findsNothing);
      expect(find.text('Editor'), findsOneWidget);

      // Host flips off → chrome returns.
      setOuter(() => zen = false);
      await tester.pumpAndSettle();
      expect(find.text('Status'), findsOneWidget);
      expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
    });

    testWidgets('asserts onZenModeChanged is required in controlled mode', (
      tester,
    ) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          zenMode: true,
        ),
        throwsAssertionError,
      );
    });
  });

  group('Primary side bar visibility (§spec:layout-customization)', () {
    testWidgets('uncontrolled: initialSidebarVisible false hides the bar at '
        'start; the activity bar stays', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: _sidebarSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
            initialSidebarVisible: false,
          ),
        ),
      );

      // The side bar body is hidden; the activity bar remains so the user can
      // bring it back.
      expect(find.text('EXPLORER'), findsNothing);
      expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
    });

    testWidgets('controlled: host drives sidebarVisible and is notified when the '
        'active activity icon toggles the bar', (tester) async {
      bool visible = true;
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
                sidebarVisible: visible,
                onSidebarVisibilityChanged: (next) =>
                    setState(() => visible = next),
              );
            },
          ),
        ),
      );

      expect(find.text('EXPLORER'), findsOneWidget);

      // Tapping the active container icon requests a hide through the seam; the
      // controlled value flips and the bar disappears.
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();
      expect(visible, isFalse);
      expect(find.text('EXPLORER'), findsNothing);

      // Host flips its own state back on → the bar returns.
      setOuter(() => visible = true);
      await tester.pumpAndSettle();
      expect(find.text('EXPLORER'), findsOneWidget);
    });

    testWidgets('asserts onSidebarVisibilityChanged is required in controlled '
        'mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          sidebarVisible: true,
        ),
        throwsAssertionError,
      );
    });
  });

  group('Status bar visibility (§spec:layout-customization)', () {
    testWidgets('uncontrolled: initialStatusBarVisible false hides the status '
        'bar; other chrome stays', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: _sidebarSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
            initialStatusBarVisible: false,
          ),
        ),
      );

      expect(find.text('Status'), findsNothing);
      // The rest of the workbench is untouched.
      expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
      expect(find.text('EXPLORER'), findsOneWidget);
    });

    testWidgets('controlled: host drives statusBarVisible', (tester) async {
      bool visible = true;
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
                statusBarVisible: visible,
                onStatusBarVisibilityChanged: (next) =>
                    setState(() => visible = next),
              );
            },
          ),
        ),
      );

      expect(find.text('Status'), findsOneWidget);

      setOuter(() => visible = false);
      await tester.pumpAndSettle();
      expect(find.text('Status'), findsNothing);

      setOuter(() => visible = true);
      await tester.pumpAndSettle();
      expect(find.text('Status'), findsOneWidget);
    });

    testWidgets('asserts onStatusBarVisibilityChanged is required in controlled '
        'mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          statusBarVisible: true,
        ),
        throwsAssertionError,
      );
    });
  });

  group('Centered layout (§spec:editing-modes)', () {
    testWidgets('on: editor narrows to the golden-ratio fraction and centers; '
        'chrome stays', (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool centered = false;
      late StateSetter setOuter;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return WorkbenchLayout(
                activityBarItems: _testItems,
                editor: const ColoredBox(
                  key: ValueKey('editor-fill'),
                  color: Color(0xFF123456),
                  child: SizedBox.expand(),
                ),
                containerBuilder: _sidebarSpec,
                bottomPanel: const Center(child: Text('Panel')),
                statusBar: const SizedBox(height: 22, child: Text('Status')),
                centeredLayout: centered,
                onCenteredLayoutChanged: (n) => setState(() => centered = n),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final off = tester.getRect(find.byKey(const ValueKey('editor-fill')));

      setOuter(() => centered = true);
      await tester.pumpAndSettle();
      final on = tester.getRect(find.byKey(const ValueKey('editor-fill')));

      // Chrome stays put.
      expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);

      // Narrowed to the golden-ratio fraction (~0.618 of the column), not a
      // fixed cap.
      final ratio =
          1 - 2 * WorkbenchLayoutConstants.centeredLayoutMarginRatio;
      expect(on.width / off.width, closeTo(ratio, 0.05));

      // Centered: the freed width splits ~evenly into left and right margins.
      final leftMargin = on.left - off.left;
      final rightMargin = off.right - on.right;
      expect(leftMargin, greaterThan(0));
      expect((leftMargin - rightMargin).abs(), lessThan(4));
    });

    testWidgets('on: a hairline (editorGroup.border) runs down each inner edge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const ColoredBox(
              key: ValueKey('editor-fill'),
              color: Color(0xFF123456),
              child: SizedBox.expand(),
            ),
            containerBuilder: _sidebarSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
            initialCenteredLayout: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The centered editor is wrapped in a Container with left+right borders in
      // editorGroupBorder (the hairlines). Side bar (right-only) and panel
      // (top-only) borders use different colors, so this match is unique.
      final hairlined = find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final d = w.decoration;
        if (d is! BoxDecoration) return false;
        final b = d.border;
        return b is Border &&
            b.left.color == _testTheme.editorGroupBorder &&
            b.right.color == _testTheme.editorGroupBorder;
      });
      expect(hairlined, findsOneWidget);
    });

    testWidgets('on: dragging a margin sash resizes symmetrically — the editor '
        'widens but stays centered', (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const ColoredBox(
              key: ValueKey('editor-fill'),
              color: Color(0xFF123456),
              child: SizedBox.expand(),
            ),
            containerBuilder: _sidebarSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
            initialCenteredLayout: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = tester.getRect(find.byKey(const ValueKey('editor-fill')));
      // Drag the left margin sash (on the editor's left hairline) outward.
      await tester.dragFrom(
        Offset(before.left - 1, before.center.dy),
        const Offset(-150, 0),
      );
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byKey(const ValueKey('editor-fill')));

      // The editor widened...
      expect(after.width, greaterThan(before.width + 100));
      // ...symmetrically: both edges moved, so the editor's center is unchanged.
      // An asymmetric drag (one edge only) would shift the center by half the
      // width change.
      expect(after.center.dx, closeTo(before.center.dx, 1.0));
    });

    testWidgets('off: editor fills the available width (no cap)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const ColoredBox(
              key: ValueKey('editor-fill'),
              color: Color(0xFF123456),
              child: SizedBox.expand(),
            ),
            containerBuilder: _sidebarSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
            // centered defaults off — editor fills the column.
          ),
        ),
      );
      await tester.pumpAndSettle();

      final fillWidth = tester
          .getRect(find.byKey(const ValueKey('editor-fill')))
          .width;
      // With centered off, the editor fills the editor column — on a 2000px
      // window minus chrome, far wider than a centered editor would be.
      expect(fillWidth, greaterThan(1200));
    });

    testWidgets('controlled: host drives centeredLayout', (tester) async {
      tester.view.physicalSize = const Size(2000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool centered = false;
      late StateSetter setOuter;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return WorkbenchLayout(
                activityBarItems: _testItems,
                editor: const ColoredBox(
                  key: ValueKey('editor-fill'),
                  color: Color(0xFF123456),
                  child: SizedBox.expand(),
                ),
                containerBuilder: _sidebarSpec,
                bottomPanel: const Center(child: Text('Panel')),
                statusBar: const SizedBox(height: 22, child: Text('Status')),
                centeredLayout: centered,
                onCenteredLayoutChanged: (next) =>
                    setState(() => centered = next),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final wideWidth = tester
          .getRect(find.byKey(const ValueKey('editor-fill')))
          .width;
      expect(wideWidth, greaterThan(1200));

      setOuter(() => centered = true);
      await tester.pumpAndSettle();
      final centeredWidth = tester
          .getRect(find.byKey(const ValueKey('editor-fill')))
          .width;
      // Centered narrows the editor to the golden-ratio fraction (~62%).
      expect(centeredWidth, lessThan(wideWidth * 0.72));
    });

    testWidgets('asserts onCenteredLayoutChanged is required in controlled '
        'mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          centeredLayout: true,
        ),
        throwsAssertionError,
      );
    });
  });

  group('Side Bar position (§spec:sidebar-position)', () {
    // The full layout fills the test window; the activity bar is 48px wide and
    // travels with the side bar to the selected edge. The sidebar sash's
    // growSign encodes which way a drag grows the bar: +1 on the left (drag
    // right), -1 on the right (drag left).
    Rect layoutRect(WidgetTester tester) =>
        tester.getRect(find.byType(WorkbenchLayout));

    testWidgets('uncontrolled default: activity bar is on the left, sash grows '
        'rightward', (tester) async {
      await tester.pumpWidget(_buildApp());

      // Left-to-right: activity bar, side bar, editor.
      final ab = tester.getRect(find.byIcon(Symbols.folder_rounded));
      final sidebarHeading = tester.getRect(find.text('EXPLORER'));
      final editor = tester.getRect(find.text('Editor'));
      expect(ab.left, lessThan(sidebarHeading.left));
      expect(sidebarHeading.left, lessThan(editor.left));
      expect(_sash(tester, Axis.horizontal).growSign, 1);
    });

    testWidgets('right: activity bar and side bar move to the editor’s right '
        'edge, sash grows leftward', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarPosition: WorkbenchSidebarPosition.right,
          onSidebarPositionChanged: (_) {},
        ),
      );

      // Left-to-right mirror: editor, side bar, activity bar against the
      // window's right edge.
      final layout = layoutRect(tester);
      final ab = tester.getRect(find.byIcon(Symbols.folder_rounded));
      final sidebarHeading = tester.getRect(find.text('EXPLORER'));
      final editor = tester.getRect(find.text('Editor'));
      expect(editor.right, lessThan(sidebarHeading.left));
      expect(sidebarHeading.left, lessThan(ab.left));
      // The activity bar (48px) sits flush against the window's right edge.
      expect(ab.right, closeTo(layout.right, 3));

      // The sash now grows the bar when dragged left (toward the editor).
      expect(_sash(tester, Axis.horizontal).growSign, -1);
    });

    testWidgets('right: the side bar sash drags from the right edge and commits '
        'once on release', (tester) async {
      final ends = <double>[];
      await tester.pumpWidget(
        _buildApp(
          sidebarPosition: WorkbenchSidebarPosition.right,
          onSidebarPositionChanged: (_) {},
          onSidebarWidthChangeEnd: ends.add,
        ),
      );

      final before = _sash(tester, Axis.horizontal).value;
      final gesture = await tester.startGesture(
        tester.getCenter(_sashFinder(Axis.horizontal)),
      );

      // Drag left grows the bar (growSign -1); nothing commits mid-drag.
      await gesture.moveBy(const Offset(-50, 0));
      await tester.pump();
      expect(_sash(tester, Axis.horizontal).value, greaterThan(before));
      expect(ends, isEmpty);

      await gesture.up();
      await tester.pump();
      expect(ends, hasLength(1));
      expect(ends.single, _sash(tester, Axis.horizontal).value);
    });

    testWidgets('controlled: host drives sidebarPosition; the bar moves edges', (
      tester,
    ) async {
      var position = WorkbenchSidebarPosition.left;
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
                sidebarPosition: position,
                onSidebarPositionChanged: (next) =>
                    setState(() => position = next),
              );
            },
          ),
        ),
      );

      // Left: activity bar near the window's left edge.
      final leftIcon = tester.getRect(find.byIcon(Symbols.folder_rounded));

      // Host flips to the right → the bar moves to the right edge.
      setOuter(() => position = WorkbenchSidebarPosition.right);
      await tester.pumpAndSettle();
      final rightIcon = tester.getRect(find.byIcon(Symbols.folder_rounded));
      expect(rightIcon.left, greaterThan(leftIcon.left + 400));
      expect(_sash(tester, Axis.horizontal).growSign, -1);
    });

    testWidgets('asserts onSidebarPositionChanged is required in controlled '
        'mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          sidebarPosition: WorkbenchSidebarPosition.right,
        ),
        throwsAssertionError,
      );
    });
  });

  group('Secondary Side Bar (§spec:secondary-sidebar)', () {
    // The secondary side bar reuses _sidebarSpec: the primary shows
    // 'Sidebar: explorer' (the default active container) and the secondary
    // shows 'Sidebar: search', so the two bars carry distinct, locatable text.
    Finder secondarySash() => find.byWidgetPredicate(
      (w) => w is WorkbenchSash && w.axis == Axis.horizontal && w.growSign == -1,
    );

    testWidgets('hidden by default: the secondary container is never built '
        '(lazy)', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          secondaryViewContainerId: 'search',
          onSecondaryViewContainerChanged: (_) {},
          secondarySideBarVisible: false,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Hidden secondary: its body builder never runs (mirrors the primary's
      // lazy retention — an un-opened container contributes no child).
      expect(find.text('Sidebar: search'), findsNothing);
      expect(find.text('Sidebar: explorer'), findsOneWidget);
    });

    testWidgets('visible: the secondary sits on the edge opposite the primary',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          secondaryViewContainerId: 'search',
          onSecondaryViewContainerChanged: (_) {},
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Primary on the left (default) → secondary on the right of the editor.
      final editor = tester.getRect(find.text('Editor'));
      final primary = tester.getRect(find.text('Sidebar: explorer'));
      final secondary = tester.getRect(find.text('Sidebar: search'));
      expect(primary.center.dx, lessThan(editor.center.dx));
      expect(secondary.center.dx, greaterThan(editor.center.dx));
      // Its own sash grows leftward (toward the editor) from the right edge.
      expect(secondarySash(), findsOneWidget);
    });

    testWidgets('follows the primary: swapping the primary to the right moves '
        'the secondary to the now-free left edge', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarPosition: WorkbenchSidebarPosition.right,
          onSidebarPositionChanged: (_) {},
          secondaryViewContainerId: 'search',
          onSecondaryViewContainerChanged: (_) {},
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Primary on the right → secondary on the left of the editor.
      final editor = tester.getRect(find.text('Editor'));
      final primary = tester.getRect(find.text('Sidebar: explorer'));
      final secondary = tester.getRect(find.text('Sidebar: search'));
      expect(primary.center.dx, greaterThan(editor.center.dx));
      expect(secondary.center.dx, lessThan(editor.center.dx));
    });

    testWidgets('its sash commits the secondary width once on release',
        (tester) async {
      final ends = <double>[];
      await tester.pumpWidget(
        _buildApp(
          secondaryViewContainerId: 'search',
          onSecondaryViewContainerChanged: (_) {},
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
          onSecondarySideBarWidthChangeEnd: ends.add,
        ),
      );

      final before = tester.widget<WorkbenchSash>(secondarySash()).value;
      final gesture = await tester.startGesture(
        tester.getCenter(secondarySash()),
      );
      // On the right edge the sash grows the bar when dragged left; nothing
      // commits mid-drag.
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();
      expect(tester.widget<WorkbenchSash>(secondarySash()).value,
          greaterThan(before));
      expect(ends, isEmpty);

      await gesture.up();
      await tester.pump();
      expect(ends, hasLength(1));
      expect(ends.single, tester.widget<WorkbenchSash>(secondarySash()).value);
    });

    testWidgets('RETENTION survives a primary-position swap: a secondary pane '
        'collapse persists when the primary moves left↔right', (tester) async {
      // The secondary is a Row child keyed by a stable GlobalKey, so a primary
      // position swap (which reorders the Row) relocates its subtree rather
      // than rebuilding it — the retained pane State survives the move
      // (§spec:secondary-sidebar, mirroring §spec:sidebar-position).
      WorkbenchViewContainerSpec twoPaneSpec(String id) =>
          WorkbenchViewContainerSpec(
            views: [
              WorkbenchViewDescriptor(
                id: '$id-a',
                title: '$id Alpha',
                bodyBuilder: (_) => Text('$id-body-a'),
              ),
              WorkbenchViewDescriptor(
                id: '$id-b',
                title: '$id Beta',
                bodyBuilder: (_) => Text('$id-body-b'),
              ),
            ],
          );

      Widget app(WorkbenchSidebarPosition position) => _buildApp(
        containerBuilder: twoPaneSpec,
        sidebarPosition: position,
        onSidebarPositionChanged: (_) {},
        secondaryViewContainerId: 'search',
        onSecondaryViewContainerChanged: (_) {},
        secondarySideBarVisible: true,
        onSecondarySideBarVisibilityChanged: (_) {},
      );

      await tester.pumpWidget(app(WorkbenchSidebarPosition.left));

      // Collapse the secondary's first pane (SEARCH ALPHA).
      await tester.tap(find.text('SEARCH ALPHA'));
      await tester.pumpAndSettle();
      expect(find.text('search-body-a'), findsNothing);
      expect(find.text('search-body-b'), findsOneWidget);

      // Move the primary to the right edge: the secondary travels to the left.
      await tester.pumpWidget(app(WorkbenchSidebarPosition.right));
      await tester.pumpAndSettle();

      // The collapse survived the move — the secondary relocated, not rebuilt.
      expect(find.text('search-body-a'), findsNothing);
      expect(find.text('search-body-b'), findsOneWidget);
    });

    testWidgets('asserts onSecondaryViewContainerChanged is required in '
        'controlled mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          secondaryViewContainerId: 'search',
        ),
        throwsAssertionError,
      );
    });

    testWidgets('asserts onSecondarySideBarVisibilityChanged is required in '
        'controlled mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          secondarySideBarVisible: true,
        ),
        throwsAssertionError,
      );
    });
  });

  group('Panel alignment (§spec:panel-alignment)', () {
    // The panel's horizontal band equals the width of its vertical resize sash,
    // which spans the panel's top edge (Positioned left:0, right:0). Comparing
    // the band against the full layout proves where the panel sits in the tree.
    Rect panelBand(WidgetTester tester) =>
        tester.getRect(_sashFinder(Axis.vertical));
    Rect layoutRect(WidgetTester tester) =>
        tester.getRect(find.byType(WorkbenchLayout));

    testWidgets('uncontrolled default is center: the panel spans the editor, '
        'not the full width', (tester) async {
      await tester.pumpWidget(_buildApp());
      final band = panelBand(tester);
      final layout = layoutRect(tester);
      // The activity bar + side bar run full height to the panel's left, so the
      // band starts inboard of the window edge and stops short of full width.
      expect(band.left, greaterThan(layout.left + 1));
      expect(band.width, lessThan(layout.width));
    });

    testWidgets('justify: the panel spans the full width past both side bars', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          panelAlignment: WorkbenchPanelAlignment.justify,
          onPanelAlignmentChanged: (_) {},
        ),
      );
      final band = panelBand(tester);
      final layout = layoutRect(tester);
      expect(band.left, closeTo(layout.left, 1));
      expect(band.right, closeTo(layout.right, 1));
    });

    testWidgets('left: the panel abuts the left side bar and spans to the right '
        'edge past the secondary bar', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          panelAlignment: WorkbenchPanelAlignment.left,
          onPanelAlignmentChanged: (_) {},
          secondaryViewContainerId: 'search',
          onSecondaryViewContainerChanged: (_) {},
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );
      final band = panelBand(tester);
      final layout = layoutRect(tester);
      // Left bar runs full height (band starts inboard); the right/secondary bar
      // stops at the panel top, so the band reaches the window's right edge.
      expect(band.left, greaterThan(layout.left + 1));
      expect(band.right, closeTo(layout.right, 1));
    });

    testWidgets('right: the panel abuts the right side bar and spans to the '
        'left edge past the primary bar', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          panelAlignment: WorkbenchPanelAlignment.right,
          onPanelAlignmentChanged: (_) {},
          secondaryViewContainerId: 'search',
          onSecondaryViewContainerChanged: (_) {},
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );
      final band = panelBand(tester);
      final layout = layoutRect(tester);
      // Left/primary bar stops at the panel top → band reaches the left edge;
      // the right/secondary bar runs full height → band stops short of right.
      expect(band.left, closeTo(layout.left, 1));
      expect(band.right, lessThan(layout.right - 1));
    });

    testWidgets('controlled: host drives panelAlignment; the band widens from '
        'center to justify', (tester) async {
      var alignment = WorkbenchPanelAlignment.center;
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
                panelAlignment: alignment,
                onPanelAlignmentChanged: (next) =>
                    setState(() => alignment = next),
              );
            },
          ),
        ),
      );

      final centerWidth = panelBand(tester).width;
      setOuter(() => alignment = WorkbenchPanelAlignment.justify);
      await tester.pumpAndSettle();
      final justifyWidth = panelBand(tester).width;
      expect(justifyWidth, greaterThan(centerWidth));
      expect(justifyWidth, closeTo(layoutRect(tester).width, 1));
    });

    testWidgets('asserts onPanelAlignmentChanged is required in controlled '
        'mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          panelAlignment: WorkbenchPanelAlignment.justify,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('RETENTION survives an alignment change: a side-bar pane '
        'collapse persists when the panel re-parents', (tester) async {
      // center→justify lifts the side bars into the panel's band, re-parenting
      // them across the widget tree. Their subtrees carry stable GlobalKeys, so
      // the retained pane State survives the move (§spec:view-container-state).
      WorkbenchViewContainerSpec twoPaneSpec(String id) =>
          WorkbenchViewContainerSpec(
            views: [
              WorkbenchViewDescriptor(
                id: '$id-a',
                title: '$id Alpha',
                bodyBuilder: (_) => Text('$id-body-a'),
              ),
              WorkbenchViewDescriptor(
                id: '$id-b',
                title: '$id Beta',
                bodyBuilder: (_) => Text('$id-body-b'),
              ),
            ],
          );

      Widget app(WorkbenchPanelAlignment alignment) => _buildApp(
        containerBuilder: twoPaneSpec,
        panelAlignment: alignment,
        onPanelAlignmentChanged: (_) {},
      );

      await tester.pumpWidget(app(WorkbenchPanelAlignment.center));

      // Collapse the primary's first pane.
      await tester.tap(find.text('EXPLORER ALPHA'));
      await tester.pumpAndSettle();
      expect(find.text('explorer-body-a'), findsNothing);
      expect(find.text('explorer-body-b'), findsOneWidget);

      // Justify re-parents the primary side bar into the panel's band.
      await tester.pumpWidget(app(WorkbenchPanelAlignment.justify));
      await tester.pumpAndSettle();

      // The collapse survived — the bar relocated, it did not rebuild.
      expect(find.text('explorer-body-a'), findsNothing);
      expect(find.text('explorer-body-b'), findsOneWidget);
    });
  });

  group('Editing-mode constants', () {
    test('centered margin ratio matches VS Code golden-ratio default', () {
      expect(WorkbenchLayoutConstants.centeredLayoutMarginRatio, 0.1909);
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

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
      initialSidebarWidth: initialSidebarWidth,
      initialPanelHeight: initialPanelHeight,
      onSidebarWidthChangeEnd: onSidebarWidthChangeEnd,
      onPanelHeightChangeEnd: onPanelHeightChangeEnd,
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

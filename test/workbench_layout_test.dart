import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Widget? editor,
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
  List<String>? secondaryViewContainerIds,
  String? secondaryActiveViewContainerId,
  ValueChanged<String>? onSecondaryActiveViewContainerChanged,
  bool? secondarySideBarVisible,
  ValueChanged<bool>? onSecondarySideBarVisibilityChanged,
  double? initialSecondarySideBarWidth,
  ValueChanged<double>? onSecondarySideBarWidthChangeEnd,
  WorkbenchLayoutDensity initialLayoutDensity = WorkbenchLayoutDensity.standard,
  WorkbenchLayoutDensity? layoutDensity,
  ValueChanged<WorkbenchLayoutDensity>? onLayoutDensityChanged,
  bool initialModernUI = true,
  bool? modernUI,
  ValueChanged<bool>? onModernUIChanged,
  WorkbenchTheme? theme,
}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [theme ?? _testTheme]),
    home: WorkbenchLayout(
      activityBarItems: items ?? _testItems,
      editor: editor ?? const Center(child: Text('Editor')),
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
      secondaryViewContainerIds: secondaryViewContainerIds ?? const [],
      secondaryActiveViewContainerId: secondaryActiveViewContainerId,
      onSecondaryActiveViewContainerChanged:
          onSecondaryActiveViewContainerChanged,
      secondarySideBarVisible: secondarySideBarVisible,
      onSecondarySideBarVisibilityChanged: onSecondarySideBarVisibilityChanged,
      initialSecondarySideBarWidth: initialSecondarySideBarWidth,
      onSecondarySideBarWidthChangeEnd: onSecondarySideBarWidthChangeEnd,
      initialLayoutDensity: initialLayoutDensity,
      layoutDensity: layoutDensity,
      onLayoutDensityChanged: onLayoutDensityChanged,
      initialModernUI: initialModernUI,
      modernUI: modernUI,
      onModernUIChanged: onModernUIChanged,
    ),
  );
}

/// The composite title's own band — the `.part > .title` container the side bar
/// heading occupies, found as the nearest [Container] above its label
/// (§spec:modern-ui-surfaces).
Finder _titleBand(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(Container))
    .first;

/// The horizontal sash resizes the sidebar width; the vertical sash resizes the
/// panel height. Each seam's live dimension is the sash's [value]
/// (§spec:workbench-layout).
WorkbenchSash _sash(WidgetTester tester, Axis axis) =>
    tester.widget<WorkbenchSash>(
      find.byWidgetPredicate((w) => w is WorkbenchSash && w.axis == axis),
    );

/// The fill behind the whole workbench — what shows through the card gutters
/// (§spec:modern-ui-surfaces).
Color _scaffoldFill(WidgetTester tester) => tester
    .widget<Scaffold>(
      find.descendant(
        of: find.byType(WorkbenchLayout),
        matching: find.byType(Scaffold),
      ),
    )
    .backgroundColor!;

/// A theme whose backdrop and editor tokens differ, so a test can tell which
/// one a surface painted. The two are equal on many themes, which is what hid
/// the backdrop defect.
WorkbenchTheme _splitBackdrop(WorkbenchTheme base) => base.copyWith(
  workbenchBackdrop: const Color(0xFF191A1B),
  editorBackground: const Color(0xFF121314),
);

Finder _sashFinder(Axis axis) =>
    find.byWidgetPredicate((w) => w is WorkbenchSash && w.axis == axis);

/// Empty pane body for a const view descriptor in the overflow tests.
Widget _emptyBody(BuildContext _) => const Text('body-c');

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
      expect(find.text('Explorer'), findsOneWidget);
    });

    testWidgets('switches sidebar on activity bar tap', (tester) async {
      await tester.pumpWidget(_buildApp());

      // Tap search icon
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sidebar: search'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('toggles sidebar on tapping active section', (tester) async {
      await tester.pumpWidget(_buildApp());

      // Sidebar visible initially
      expect(find.text('Explorer'), findsOneWidget);

      // Tap active section hides sidebar
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Explorer'), findsNothing);

      // Tap again shows sidebar
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Explorer'), findsOneWidget);
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

      // The panel content is inset below the panel's own top edge by the
      // card's gutter and stroke (§spec:modern-ui-surfaces); the sash sits on
      // that gutter and must not start above the panel's top edge (which would
      // overhang into the region the Stack clips).
      const cardInset =
          WorkbenchLayoutConstants.floatingCardGap +
          WorkbenchLayoutConstants.strokeThickness;
      final panelContentTop = tester.getRect(find.byKey(panelKey)).top;
      final sashTop = tester.getRect(sash).top;
      expect(sashTop, greaterThanOrEqualTo(panelContentTop - cardInset));
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

    testWidgets('bottom panel card stroke is not overdrawn by panel child', (
      tester,
    ) async {
      // Regression: a border painted *behind* the child disappears once the
      // panel's own background widget (e.g. ColoredBox(panelBackground) inside
      // WorkbenchTabbedPanel) fills the full rect. The card paints its stroke
      // as a ring and insets the child past it, so the hairline survives
      // (§spec:modern-ui-surfaces).
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

      final strokeRing = find.ancestor(
        of: panelBgFinder,
        matching: find.byWidgetPredicate((w) {
          if (w is! DecoratedBox) return false;
          final decoration = w.decoration;
          if (decoration is! BoxDecoration) return false;
          if (decoration.borderRadius !=
              BorderRadius.circular(
                WorkbenchLayoutConstants.floatingCardRadius,
              )) {
            return false;
          }
          // The panel's stroke is a foreground-safe Border; the one card that
          // cedes an edge fills the box instead. Either satisfies the
          // guarantee this test exists for.
          final border = decoration.border;
          return decoration.color == _testTheme.surfaceBorder ||
              (border is Border &&
                  border.top.color == _testTheme.surfaceBorder);
        }),
      );
      expect(
        strokeRing,
        findsOneWidget,
        reason:
            'the panel card paints its hairline outside its child, so the '
            'panel child cannot overdraw it',
      );

      final ringRect = tester.getRect(strokeRing);
      final panelRect = tester.getRect(panelBgFinder);
      expect(
        panelRect.top - ringRect.top,
        closeTo(WorkbenchLayoutConstants.strokeThickness, 0.001),
        reason:
            'the panel child should be inset one stroke from the card ring '
            'so the hairline remains visible',
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
    testWidgets(
      'renders a multi-view container as a stacked WorkbenchViewContainer',
      (tester) async {
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
        expect(find.text('Open Editors'), findsOneWidget);
        expect(find.text('Outline'), findsOneWidget);
        expect(find.byIcon(Symbols.expand_more_rounded), findsNWidgets(2));
        expect(find.text('editors-body'), findsOneWidget);
      },
    );

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
      expect(find.text('Explorer'), findsOneWidget);
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
      await tester.tap(find.text('explorer Alpha'));
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
      await tester.tap(find.text('explorer Alpha'));
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
      await tester.tap(find.text('explorer Alpha'));
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
      await tester.tap(find.text('explorer Shared'));
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
      expect(find.text('Explorer'), findsNothing);
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
      expect(find.text('Explorer'), findsNothing);
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

      expect(find.text('Explorer'), findsOneWidget);

      // Tapping the active container icon requests a hide through the seam; the
      // controlled value flips and the bar disappears.
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();
      expect(visible, isFalse);
      expect(find.text('Explorer'), findsNothing);

      // Host flips its own state back on → the bar returns.
      setOuter(() => visible = true);
      await tester.pumpAndSettle();
      expect(find.text('Explorer'), findsOneWidget);
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
      expect(find.text('Explorer'), findsOneWidget);
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

    testWidgets(
      'asserts onStatusBarVisibilityChanged is required in controlled '
      'mode',
      (tester) async {
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
      },
    );
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
      final ratio = 1 - 2 * WorkbenchLayoutConstants.centeredLayoutMarginRatio;
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
      final sidebarHeading = tester.getRect(find.text('Explorer'));
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
      final sidebarHeading = tester.getRect(find.text('Explorer'));
      final editor = tester.getRect(find.text('Editor'));
      expect(editor.right, lessThan(sidebarHeading.left));
      expect(sidebarHeading.left, lessThan(ab.left));
      // The activity bar's 48px allocation reaches the window's right edge;
      // inside it the rail card gives up the cluster's perimeter gutter, its
      // stroke and the lane, and the icon column centres what is left
      // (§spec:modern-ui-surfaces).
      const railToWindow =
          WorkbenchLayoutConstants.floatingCardPerimeter +
          WorkbenchLayoutConstants.strokeThickness +
          WorkbenchLayoutConstants.activityBarIconInset +
          (WorkbenchLayoutConstants.activityBarRailWidth -
                  WorkbenchLayoutConstants.iconActivityBar) /
              2;
      expect(ab.right, closeTo(layout.right - railToWindow, 0.001));

      // The sash now grows the bar when dragged left (toward the editor).
      expect(_sash(tester, Axis.horizontal).growSign, -1);
    });

    testWidgets(
      'right: the side bar sash drags from the right edge and commits '
      'once on release',
      (tester) async {
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
      },
    );

    testWidgets(
      'controlled: host drives sidebarPosition; the bar moves edges',
      (tester) async {
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
      },
    );

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
    // shows 'Sidebar: aux'. Membership ids ('aux', 'outline', 'notes') are
    // disjoint from the activity-bar ids — a container id occupies exactly
    // one location.
    Finder secondarySash() => find.byWidgetPredicate(
      (w) =>
          w is WorkbenchSash && w.axis == Axis.horizontal && w.growSign == -1,
    );

    // Two titled members: the tab labels come from spec.title
    // (§spec:view-container-title) — no activity item names them.
    WorkbenchViewContainerSpec titledSpec(String id) {
      final title = switch (id) {
        'outline' => 'Outline',
        'notes' => 'Notes',
        _ => null,
      };
      return WorkbenchViewContainerSpec(
        title: title,
        views: [
          WorkbenchViewDescriptor(
            id: '$id-view',
            title: '$id view',
            bodyBuilder: (_) => Text('body-$id'),
          ),
        ],
      );
    }

    testWidgets('hidden by default: the secondary container is never built '
        '(lazy)', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          secondaryViewContainerIds: const ['aux'],
          secondarySideBarVisible: false,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Hidden secondary: its body builder never runs (mirrors the primary's
      // lazy retention — an un-opened container contributes no child).
      expect(find.text('Sidebar: aux'), findsNothing);
      expect(find.text('Sidebar: explorer'), findsOneWidget);
    });

    testWidgets(
      'visible: the secondary sits on the edge opposite the primary',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            secondaryViewContainerIds: const ['aux'],
            secondarySideBarVisible: true,
            onSecondarySideBarVisibilityChanged: (_) {},
          ),
        );

        // Primary on the left (default) → secondary on the right of the editor.
        final editor = tester.getRect(find.text('Editor'));
        final primary = tester.getRect(find.text('Sidebar: explorer'));
        final secondary = tester.getRect(find.text('Sidebar: aux'));
        expect(primary.center.dx, lessThan(editor.center.dx));
        expect(secondary.center.dx, greaterThan(editor.center.dx));
        // Its own sash grows leftward (toward the editor) from the right edge.
        expect(secondarySash(), findsOneWidget);
      },
    );

    testWidgets('follows the primary: swapping the primary to the right moves '
        'the secondary to the now-free left edge', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          sidebarPosition: WorkbenchSidebarPosition.right,
          onSidebarPositionChanged: (_) {},
          secondaryViewContainerIds: const ['aux'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Primary on the right → secondary on the left of the editor.
      final editor = tester.getRect(find.text('Editor'));
      final primary = tester.getRect(find.text('Sidebar: explorer'));
      final secondary = tester.getRect(find.text('Sidebar: aux'));
      expect(primary.center.dx, greaterThan(editor.center.dx));
      expect(secondary.center.dx, lessThan(editor.center.dx));
    });

    testWidgets('its sash commits the secondary width once on release', (
      tester,
    ) async {
      final ends = <double>[];
      await tester.pumpWidget(
        _buildApp(
          secondaryViewContainerIds: const ['aux'],
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
      expect(
        tester.widget<WorkbenchSash>(secondarySash()).value,
        greaterThan(before),
      );
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
        secondaryViewContainerIds: const ['aux'],
        secondarySideBarVisible: true,
        onSecondarySideBarVisibilityChanged: (_) {},
      );

      await tester.pumpWidget(app(WorkbenchSidebarPosition.left));

      // Collapse the secondary's first pane (AUX ALPHA).
      await tester.tap(find.text('aux Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('aux-body-a'), findsNothing);
      expect(find.text('aux-body-b'), findsOneWidget);

      // Move the primary to the right edge: the secondary travels to the left.
      await tester.pumpWidget(app(WorkbenchSidebarPosition.right));
      await tester.pumpAndSettle();

      // The collapse survived the move — the secondary relocated, not rebuilt.
      expect(find.text('aux-body-a'), findsNothing);
      expect(find.text('aux-body-b'), findsOneWidget);
    });

    testWidgets('title row renders one tab per member; the first member is '
        'active by default and the other stays unbuilt (lazy)', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          containerBuilder: titledSpec,
          secondaryViewContainerIds: const ['outline', 'notes'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Both members render as uppercase tab labels — not a single composite
      // title naming only the active container.
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      // First member active by default; the second's body never builds.
      expect(find.text('body-outline'), findsOneWidget);
      expect(find.text('body-notes'), findsNothing);
    });

    testWidgets('tapping the inactive tab switches the container and reports '
        'the id (uncontrolled)', (tester) async {
      final reported = <String>[];
      await tester.pumpWidget(
        _buildApp(
          containerBuilder: titledSpec,
          secondaryViewContainerIds: const ['outline', 'notes'],
          onSecondaryActiveViewContainerChanged: reported.add,
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      // The shell originated the switch AND reported it (§spec:secondary-sidebar,
      // the §spec:sidebar-visibility tap-seam pattern).
      expect(find.text('body-notes'), findsOneWidget);
      expect(find.text('body-outline'), findsNothing);
      expect(reported, ['notes']);
    });

    testWidgets('controlled: a tab tap reports without self-switching until '
        'the host updates the value', (tester) async {
      final reported = <String>[];
      var active = 'outline';
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
                containerBuilder: titledSpec,
                bottomPanel: const Center(child: Text('Panel')),
                statusBar: const SizedBox(height: 22, child: Text('Status')),
                secondaryViewContainerIds: const ['outline', 'notes'],
                secondaryActiveViewContainerId: active,
                onSecondaryActiveViewContainerChanged: reported.add,
                secondarySideBarVisible: true,
                onSecondarySideBarVisibilityChanged: (_) {},
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      // Reported but not self-switched — the host owns the value.
      expect(reported, ['notes']);
      expect(find.text('body-outline'), findsOneWidget);
      expect(find.text('body-notes'), findsNothing);

      // The host honors the report; the shell renders the new active member.
      setOuter(() => active = 'notes');
      await tester.pumpAndSettle();
      expect(find.text('body-notes'), findsOneWidget);
      expect(find.text('body-outline'), findsNothing);
    });

    testWidgets('RETENTION across tab switches: a pane collapse in one member '
        'survives switching away and back', (tester) async {
      // Each opened member is retained (§spec:view-container-state), so
      // switching tabs preserves pane order, expansion, and sash sizes.
      WorkbenchViewContainerSpec twoPaneTitledSpec(String id) =>
          WorkbenchViewContainerSpec(
            // Title only the members: the primary containers keep their
            // activity-item labels, so no tab label collides with them.
            title: switch (id) {
              'outline' => 'Outline',
              'notes' => 'Notes',
              _ => null,
            },
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

      await tester.pumpWidget(
        _buildApp(
          containerBuilder: twoPaneTitledSpec,
          secondaryViewContainerIds: const ['outline', 'notes'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Collapse the first pane of the active member (outline).
      await tester.tap(find.text('outline Alpha'));
      await tester.pumpAndSettle();
      expect(find.text('outline-body-a'), findsNothing);
      expect(find.text('outline-body-b'), findsOneWidget);

      // Switch to notes, then back to outline.
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('notes-body-a'), findsOneWidget);
      await tester.tap(find.text('Outline'));
      await tester.pumpAndSettle();

      // The collapse survived the round trip.
      expect(find.text('outline-body-a'), findsNothing);
      expect(find.text('outline-body-b'), findsOneWidget);
    });

    testWidgets('a single-member bar still shows its one tab', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          containerBuilder: titledSpec,
          secondaryViewContainerIds: const ['outline'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // Canon's default presentation: one member, one tab.
      expect(find.text('Outline'), findsOneWidget);
      expect(find.text('body-outline'), findsOneWidget);
    });

    testWidgets('the ⋯ overflow sits right of the tabs and lists the ACTIVE '
        'member\'s Views toggles', (tester) async {
      // Members carry hideable views; every other container is empty, so the
      // secondary title row shows the only overflow button
      // (§spec:view-container-title unchanged under the tab presentation).
      WorkbenchViewContainerSpec memberOnlySpec(String id) =>
          const ['outline', 'notes'].contains(id)
          ? titledSpec(id)
          : const WorkbenchViewContainerSpec(views: []);

      await tester.pumpWidget(
        _buildApp(
          containerBuilder: memberOnlySpec,
          secondaryViewContainerIds: const ['outline', 'notes'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      // One overflow button (the secondary's), right of the tabs.
      final overflow = find.byIcon(Symbols.more_horiz);
      expect(overflow, findsOneWidget);
      expect(
        tester.getCenter(overflow).dx,
        greaterThan(tester.getCenter(find.text('Notes')).dx),
      );

      // It lists the active member's views only.
      await tester.tap(overflow);
      await tester.pumpAndSettle();
      // Matched on the toggle row rather than the bare text: the active
      // member's pane header now carries the same string.
      expect(
        find.widgetWithText(CheckboxMenuButton, 'outline view'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(CheckboxMenuButton, 'notes view'),
        findsNothing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Switching tabs retargets the overflow to the new active member.
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      await tester.tap(overflow);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(CheckboxMenuButton, 'notes view'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(CheckboxMenuButton, 'outline view'),
        findsNothing,
      );
    });

    testWidgets('tabs shrink and ellipsize instead of overflowing a narrow '
        'bar', (tester) async {
      // Canon's tab-overflow dropdown is deferred (§spec:secondary-sidebar);
      // until then, tabs under width pressure ellipsize rather than throwing
      // a RenderFlex overflow.
      WorkbenchViewContainerSpec longTitledSpec(String id) =>
          WorkbenchViewContainerSpec(
            title: 'An Exceedingly Long Member Title $id',
            views: [
              WorkbenchViewDescriptor(
                id: '$id-view',
                title: '$id view',
                bodyBuilder: (_) => Text('body-$id'),
              ),
            ],
          );

      await tester.pumpWidget(
        _buildApp(
          containerBuilder: longTitledSpec,
          secondaryViewContainerIds: const ['aux', 'aux2', 'aux3'],
          initialSecondarySideBarWidth:
              WorkbenchLayoutConstants.sidebarMinWidth,
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('asserts membership ids are disjoint from activity-bar '
        'container ids', (tester) async {
      // A container id occupies exactly one location — the shell rejects a
      // shared id rather than rendering the container twice
      // (§spec:secondary-sidebar).
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          secondaryViewContainerIds: const ['search'],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('asserts onSecondaryActiveViewContainerChanged is required in '
        'controlled mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          secondaryViewContainerIds: const ['aux'],
          secondaryActiveViewContainerId: 'aux',
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
          secondaryViewContainerIds: const ['aux'],
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
          secondaryViewContainerIds: const ['aux'],
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
      await tester.tap(find.text('explorer Alpha'));
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

  group('composite title source (§spec:view-container-title)', () {
    // A container spec whose optional title is set only for the ids present in
    // [titles], so one builder covers both the primary override and the
    // secondary (no-activity-item) cases.
    WorkbenchViewContainerSpec Function(String) builderTitling(
      Map<String, String> titles,
    ) {
      return (id) => WorkbenchViewContainerSpec(
        title: titles[id],
        views: [
          WorkbenchViewDescriptor(
            id: '$id-a',
            title: 'A',
            bodyBuilder: (_) => Text('body-$id-a'),
          ),
          WorkbenchViewDescriptor(
            id: '$id-b',
            title: 'B',
            bodyBuilder: (_) => Text('body-$id-b'),
          ),
        ],
      );
    }

    testWidgets('spec.title overrides the activity-bar label', (tester) async {
      await tester.pumpWidget(
        _buildApp(containerBuilder: builderTitling({'explorer': 'My Files'})),
      );

      expect(find.text('My Files'), findsOneWidget);
      expect(find.text('Explorer'), findsNothing);
    });

    testWidgets('a null spec.title keeps the activity-bar label', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(containerBuilder: builderTitling({})));

      expect(find.text('Explorer'), findsOneWidget);
    });

    testWidgets(
      'an untitled secondary member renders a blank tab — no activity item '
      'exists to fall back to',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            containerBuilder: builderTitling({}),
            secondaryViewContainerIds: const ['notes'],
            secondarySideBarVisible: true,
            onSecondarySideBarVisibilityChanged: (_) {},
          ),
        );

        // The member is built (its body renders) but no tab text names it —
        // the activity bar never lists 'notes' and spec.title is null
        // (§spec:secondary-sidebar).
        expect(find.text('body-notes-a'), findsOneWidget);
        expect(find.text('Notes'), findsNothing);
      },
    );

    testWidgets(
      'spec.title labels a secondary member\'s tab — the activity bar never '
      'lists it',
      (tester) async {
        await tester.pumpWidget(
          _buildApp(
            containerBuilder: builderTitling({'notes': 'Notes'}),
            secondaryViewContainerIds: const ['notes'],
            secondarySideBarVisible: true,
            onSecondarySideBarVisibilityChanged: (_) {},
          ),
        );

        expect(find.text('Notes'), findsOneWidget); // the member's tab label
        expect(find.text('Explorer'), findsOneWidget); // primary unchanged
      },
    );
  });

  group('view-container title overflow (§spec:view-container-title)', () {
    // A three-view Explorer container with a non-hideable Gamma view, host
    // title action, and a host overflow entry. Other ids render empty (no
    // overflow), so only the primary sidebar shows the `⋯` button.
    WorkbenchViewContainerSpec multiSpec(String id) {
      if (id != 'explorer') return const WorkbenchViewContainerSpec(views: []);
      return WorkbenchViewContainerSpec(
        views: [
          WorkbenchViewDescriptor(
            id: 'a',
            title: 'Alpha',
            bodyBuilder: (_) => const Text('body-a'),
          ),
          WorkbenchViewDescriptor(
            id: 'b',
            title: 'Beta',
            bodyBuilder: (_) => const Text('body-b'),
          ),
          const WorkbenchViewDescriptor(
            id: 'c',
            title: 'Gamma',
            canHide: false,
            bodyBuilder: _emptyBody,
          ),
        ],
        titleActions: [
          IconButton(
            key: const ValueKey('title-action'),
            icon: const Icon(Symbols.add_rounded),
            onPressed: () {},
          ),
        ],
        titleOverflowEntries: const [
          WorkbenchViewMenuTab(intent: ActivateIntent(), label: 'Extra Action'),
        ],
      );
    }

    testWidgets('title row shows the host action and the overflow button', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(containerBuilder: multiSpec));

      expect(find.byKey(const ValueKey('title-action')), findsOneWidget);
      expect(find.byIcon(Symbols.more_horiz), findsOneWidget);
    });

    // §spec:chrome-material-theming: the title overflow popup is a menu, so
    // it takes the `menu.*` family rather than the panel it sits over.
    testWidgets('overflow popup panel takes menu.background, not the panel '
        'fill', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          containerBuilder: multiSpec,
          theme: testWorkbenchTheme.copyWith(
            menuBackground: const Color(0xFF1F1F1F),
            menuBorder: const Color(0xFF454545),
            panelBackground: const Color(0xFF181818),
          ),
        ),
      );

      await tester.tap(find.byIcon(Symbols.more_horiz));
      await tester.pumpAndSettle();

      final panel = popupPanelOf(tester, 'Extra Action');
      expect(panel.color, const Color(0xFF1F1F1F));
      expect(
        (panel.shape! as OutlinedBorder).side.color,
        const Color(0xFF454545),
      );
    });

    testWidgets('overflow popup carries the Views group and host entries', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(containerBuilder: multiSpec));

      await tester.tap(find.byIcon(Symbols.more_horiz));
      await tester.pumpAndSettle();

      // Root popup: shell-built Views submenu + host overflow entry.
      expect(find.text('Views'), findsOneWidget);
      expect(find.text('Extra Action'), findsOneWidget);

      await tester.tap(find.text('Views'));
      await tester.pumpAndSettle();

      // One checkbox per view; the non-hideable Gamma is disabled. Matched on
      // the toggle row: each pane header carries the same string.
      for (final title in ['Alpha', 'Beta', 'Gamma']) {
        expect(
          find.widgetWithText(CheckboxMenuButton, title),
          findsOneWidget,
        );
      }
      final gamma = tester.widget<CheckboxMenuButton>(
        find.ancestor(
          of: find.text('Gamma'),
          matching: find.byType(CheckboxMenuButton),
        ),
      );
      expect(gamma.onChanged, isNull);
    });

    testWidgets('toggling a Views checkbox hides the pane; the change survives '
        'an activity-bar switch', (tester) async {
      await tester.pumpWidget(_buildApp(containerBuilder: multiSpec));

      // All three pane headers present initially.
      expect(find.text('Beta'), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Views'));
      await tester.pumpAndSettle();

      // Uncheck Beta → its pane leaves the stack. The toggle row carries the
      // same string as the pane header, so the tap targets the row.
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Beta'));
      await tester.pumpAndSettle();

      // Close the popup, switch to Search and back to Explorer.
      await tester.tap(find.byIcon(Symbols.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Symbols.folder_rounded));
      await tester.pumpAndSettle();

      // Visibility is shell-owned and container-keyed, so Beta stays hidden.
      expect(find.text('Beta'), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
    });

    // Canon: with no host overflow entries, the Views group is the only
    // secondary action, so VS Code inlines the toggles instead of nesting them
    // under a `Views ▸` submenu (panecomposite.ts getSecondaryActions).
    testWidgets('overflow popup inlines the Views toggles when there are no '
        'host overflow entries', (tester) async {
      WorkbenchViewContainerSpec flatSpec(String id) {
        if (id != 'explorer') {
          return const WorkbenchViewContainerSpec(views: []);
        }
        return WorkbenchViewContainerSpec(
          views: [
            WorkbenchViewDescriptor(
              id: 'a',
              title: 'Alpha',
              bodyBuilder: (_) => const Text('body-a'),
            ),
            WorkbenchViewDescriptor(
              id: 'b',
              title: 'Beta',
              bodyBuilder: (_) => const Text('body-b'),
            ),
          ],
        );
      }

      await tester.pumpWidget(_buildApp(containerBuilder: flatSpec));

      await tester.tap(find.byIcon(Symbols.more_horiz));
      await tester.pumpAndSettle();

      // No `Views` wrapper — the toggles are reachable directly. Matched on
      // the toggle row: each pane header carries the same string.
      expect(find.text('Views'), findsNothing);
      expect(find.widgetWithText(CheckboxMenuButton, 'Alpha'), findsOneWidget);

      // Uncheck Beta straight from the root popup. The popup stays open
      // (closeOnActivate: false), so the hidden pane is what disappears —
      // its toggle row is still there to switch back on.
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Beta'));
      await tester.pumpAndSettle();
      expect(find.text('body-b'), findsNothing);
    });

    // Canon: the file explorer's pane header shows the workspace folder name
    // while its Views toggle reads "Folders" (IViewDescriptor.name vs the
    // runtime-overridden title). menuLabel drives the toggle independently.
    testWidgets('a view menuLabel overrides its Views-toggle text without '
        'changing the pane header', (tester) async {
      WorkbenchViewContainerSpec labelSpec(String id) {
        if (id != 'explorer') {
          return const WorkbenchViewContainerSpec(views: []);
        }
        return WorkbenchViewContainerSpec(
          views: [
            WorkbenchViewDescriptor(
              id: 'folders',
              title: 'workbench_shell',
              menuLabel: 'Folders',
              bodyBuilder: (_) => const Text('body-folders'),
            ),
            WorkbenchViewDescriptor(
              id: 'b',
              title: 'Beta',
              bodyBuilder: (_) => const Text('body-b'),
            ),
          ],
        );
      }

      await tester.pumpWidget(_buildApp(containerBuilder: labelSpec));

      // Header shows the title in the host's own casing.
      expect(find.text('workbench_shell'), findsOneWidget);

      await tester.tap(find.byIcon(Symbols.more_horiz));
      await tester.pumpAndSettle();

      // The toggle reads the menuLabel, not the header title.
      expect(find.widgetWithText(CheckboxMenuButton, 'Folders'), findsOneWidget);
      expect(
        find.widgetWithText(CheckboxMenuButton, 'workbench_shell'),
        findsNothing,
      );
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

  group('layout state persistence (§spec:layout-state-persistence)', () {
    // A two-view Explorer whose panes are id-identifiable by body text.
    WorkbenchViewContainerSpec explorerSpec(String id) {
      if (id != 'explorer') return _sidebarSpec(id);
      return WorkbenchViewContainerSpec(
        views: [
          WorkbenchViewDescriptor(
            id: 'folders',
            title: 'Folders',
            bodyBuilder: (_) => const Text('body-folders'),
          ),
          WorkbenchViewDescriptor(
            id: 'outline',
            title: 'Outline',
            initiallyExpanded: false,
            bodyBuilder: (_) => const Text('body-outline'),
          ),
        ],
      );
    }

    testWidgets('seeds view visibility from initialLayoutState', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: explorerSpec,
            bottomPanel: const SizedBox.shrink(),
            statusBar: const SizedBox(height: 22),
            // Seed the visibility store to hide Outline; Folders stays.
            initialLayoutState: const WorkbenchLayoutState(
              hidden: {
                'explorer': {'outline'},
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Outline is hidden by the seeded visibility store.
      expect(find.text('Outline'), findsNothing);
      expect(find.text('Folders'), findsOneWidget);
    });

    testWidgets('drops stale ids in the seed without error (reconcile)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: explorerSpec,
            bottomPanel: const SizedBox.shrink(),
            statusBar: const SizedBox(height: 22),
            // A persisted state referencing a removed container and a removed
            // view — reconcile drops both; the layout renders the live panes.
            initialLayoutState: const WorkbenchLayoutState(
              order: {
                'explorer': ['removed-view', 'outline', 'folders'],
                'gone-container': ['x'],
              },
              hidden: {
                'explorer': {'removed-view'},
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both live panes render; the stale ids are simply absent.
      expect(find.text('Folders'), findsOneWidget);
      expect(find.text('Outline'), findsOneWidget);
    });

    testWidgets('toggling visibility notifies host with the snapshot', (
      tester,
    ) async {
      final snapshots = <WorkbenchLayoutState>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: explorerSpec,
            bottomPanel: const SizedBox.shrink(),
            statusBar: const SizedBox(height: 22),
            onLayoutStateChanged: snapshots.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the container title's ⋯ overflow and toggle Outline off.
      await tester.tap(find.byIcon(Symbols.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxMenuButton, 'Outline'));
      await tester.pumpAndSettle();

      expect(snapshots, isNotEmpty);
      expect(snapshots.last.hidden['explorer'], contains('outline'));
    });
  });

  group('Modern UI surface treatment (§spec:modern-ui-surfaces)', () {
    const gap = WorkbenchLayoutConstants.floatingCardGap;
    const stroke = WorkbenchLayoutConstants.strokeThickness;

    /// The `DecoratedBox` a card paints its hairline with, rounded at the card
    /// tier. A card with a stroke on every edge draws a foreground [Border];
    /// the one card that cedes an edge under a corner radius fills the box
    /// with `surface.border` instead, because a non-uniform border cannot
    /// carry a radius. Compact squares the corners, so there a card states its
    /// ceded edges on the `Border` directly and any side may be [BorderSide.none].
    /// Either way the observable property is the same — a `surface.border`
    /// hairline at the card's edge.
    Finder cardRing(Finder of) => find.ancestor(
      of: of,
      matching: find.byWidgetPredicate((w) {
        if (w is! DecoratedBox) return false;
        final decoration = w.decoration;
        if (decoration is! BoxDecoration) return false;
        if (decoration.color == _testTheme.surfaceBorder) return true;
        final border = decoration.border;
        if (border is! Border) return false;
        return [border.left, border.top, border.right, border.bottom].any(
          (side) => side.width > 0 && side.color == _testTheme.surfaceBorder,
        );
      }),
    );

    /// The filled box an activity bar item paints behind its icon when
    /// selected or hovered. Inactive items wrap no decoration at all.
    Finder indicator(Color color) => find.byWidgetPredicate((w) {
      if (w is! DecoratedBox) return false;
      final decoration = w.decoration;
      return decoration is BoxDecoration && decoration.color == color;
    });

    Finder fillOf(Finder card, Color color) => find.descendant(
      of: card,
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == color,
      ),
    );

    // A theme whose title bar and editor differ, which is the only way to see
    // which one the gutters paint. Themes that leave the two equal — most of
    // the bundled set — hide the difference entirely.
    final backdropTheme = _splitBackdrop(_testTheme);

    testWidgets('marks each boundary between two parts with a grip, and no '
        'seam inside one', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          secondaryViewContainerIds: const ['outline'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
          containerBuilder: (id) => WorkbenchViewContainerSpec(
            views: [
              WorkbenchViewDescriptor(
                id: '$id-a',
                title: '$id A',
                bodyBuilder: (_) => const SizedBox.shrink(),
              ),
              WorkbenchViewDescriptor(
                id: '$id-b',
                title: '$id B',
                bodyBuilder: (_) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );

      // Three inter-part seams: the primary side bar, the secondary side bar
      // and the bottom panel. The Explorer's own view-stack sash lives inside
      // a part, so it draws none (§spec:modern-ui-surfaces).
      expect(find.byKey(sashGripKey), findsNWidgets(3));
      expect(
        find.byWidgetPredicate((w) => w is WorkbenchSash && w.grip),
        findsNWidgets(3),
      );
      expect(
        find.byWidgetPredicate((w) => w is WorkbenchSash && !w.grip),
        findsWidgets,
      );
    });

    testWidgets('compact density retires the grips with the gaps', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(initialLayoutDensity: WorkbenchLayoutDensity.compact),
      );
      expect(find.byKey(sashGripKey), findsNothing);
    });

    testWidgets('insets the side bar sash highlight by the card gutters', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      final sash = tester.widget<WorkbenchSash>(
        _sashFinder(Axis.horizontal),
      );
      // At the default centre alignment the bar runs full height, so its card
      // faces window chrome at both ends and the highlight stops at the
      // cluster's perimeter gutter either way (§spec:modern-ui-surfaces).
      expect(
        sash.highlightInset.top,
        WorkbenchLayoutConstants.floatingCardPerimeter,
      );
      expect(
        sash.highlightInset.bottom,
        WorkbenchLayoutConstants.floatingCardPerimeter,
      );
    });

    testWidgets('renders the composite title in the host casing at the '
        'part-title tier', (tester) async {
      await tester.pumpWidget(_buildApp());
      // `fontRamp.css` renders `.title-label h2` capitalize at label1
      // semiBold; the host's string is already cased
      // (§spec:chrome-typography-canon).
      expect(find.text('EXPLORER'), findsNothing);
      expect(
        tester.widget<Text>(find.text('Explorer')).style,
        _testTheme.sidebarOrPanelHeading,
      );
    });

    testWidgets('insets the composite title at the part and label tiers', (
      tester,
    ) async {
      // `padding.css`: the part takes size40 on each side and the title label
      // a further size80 on its leading edge (§spec:modern-ui-surfaces).
      await tester.pumpWidget(_buildApp());
      final card = tester.getRect(cardRing(find.text('Explorer')));
      final label = tester.getRect(find.text('Explorer'));
      // The primary side bar cedes its rail-facing edge, so no stroke stands
      // between the card box and the part inset (§spec:modern-ui-surfaces).
      expect(
        label.left - card.left,
        closeTo(
          WorkbenchLayoutConstants.spacingSize40 +
              WorkbenchLayoutConstants.spacingSize80,
          0.001,
        ),
      );

      // The trailing action sits against the part's own inset — upstream
      // zeroes the last action's margin.
      final overflow = tester.getRect(
        find.ancestor(
          of: find.byIcon(Symbols.more_horiz),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        card.right - overflow.right,
        closeTo(
          WorkbenchLayoutConstants.strokeThickness +
              WorkbenchLayoutConstants.spacingSize40,
          0.001,
        ),
      );
    });

    testWidgets('tightens the composite title to the treatment band', (
      tester,
    ) async {
      // `padding.css`: `.part > .title { height: 32px }`, kept in sync with
      // `part.ts` `PartLayout.AREA_HEIGHT_MODERN_UI`
      // (§spec:modern-ui-surfaces).
      await tester.pumpWidget(_buildApp());
      expect(
        tester.getSize(_titleBand('Explorer')).height,
        WorkbenchLayoutConstants.modernPartTitleHeight,
      );
    });

    testWidgets('paints the ground behind the cards from the workbench '
        'backdrop, not the editor', (tester) async {
      await tester.pumpWidget(_buildApp(theme: backdropTheme));
      expect(_scaffoldFill(tester), backdropTheme.workbenchBackdrop);
      expect(_scaffoldFill(tester), isNot(backdropTheme.editorBackground));
    });

    testWidgets('zen mode keeps the backdrop behind the bare editor', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [backdropTheme]),
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

      expect(find.text('Panel'), findsNothing);
      expect(_scaffoldFill(tester), backdropTheme.workbenchBackdrop);
    });

    testWidgets('the side bars, panel and editor each render as a bordered, '
        'rounded card', (tester) async {
      await tester.pumpWidget(
        _buildApp(
          secondaryViewContainerIds: const ['outline'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      for (final label in ['Explorer', 'Panel', 'Editor']) {
        final ring = cardRing(find.text(label));
        expect(ring, findsOneWidget, reason: '$label card');
        final decoration =
            (tester.widget<DecoratedBox>(ring).decoration as BoxDecoration);
        // Every corner that does not meet a neighbour flush rounds at the
        // card tier; the editor and the panel meet none.
        expect(
          decoration.borderRadius,
          isA<BorderRadius>().having(
            (r) => r.topRight,
            'topRight',
            const Radius.circular(WorkbenchLayoutConstants.floatingCardRadius),
          ),
        );
      }

      // Visible gaps: the editor card is one gutter clear of the primary side
      // bar's allocation on its left and of the secondary bar's card on its
      // right.
      final editor = tester.getRect(cardRing(find.text('Editor')));
      final sidebar = tester.getRect(cardRing(find.text('Explorer')));
      final panel = tester.getRect(cardRing(find.text('Panel')));
      expect(editor.left - sidebar.right, closeTo(gap, 0.001));
      expect(panel.top - editor.bottom, closeTo(gap, 0.001));
    });

    testWidgets('the primary side bar meets the activity bar as one surface — '
        'one stroke, no gap', (tester) async {
      await tester.pumpWidget(_buildApp());

      final rail = cardRing(find.byIcon(Symbols.folder_rounded));
      final bar = cardRing(find.text('Explorer'));
      final railRect = tester.getRect(rail);
      final barRect = tester.getRect(bar);

      // No gap: the two cards share an edge.
      expect(railRect.right, closeTo(barRect.left, 0.001));

      // One stroke: the rail draws it, and the side bar's fill runs right up
      // to its own card edge rather than adding a second hairline.
      final railFill = fillOf(rail, _testTheme.activityBarBackground);
      final barFill = fillOf(bar, _testTheme.surfaceBackground);
      expect(
        railRect.right - tester.getRect(railFill).right,
        closeTo(stroke, 0.001),
      );
      expect(tester.getRect(barFill).left, closeTo(barRect.left, 0.001));
    });

    testWidgets('the rail keeps its icons optically centred', (tester) async {
      await tester.pumpWidget(_buildApp());

      final railRect = tester.getRect(
        cardRing(find.byIcon(Symbols.folder_rounded)),
      );
      final icon = tester.getRect(find.byIcon(Symbols.folder_rounded));

      // Equal margins either side of the icon column: the lane is halved after
      // the card's two strokes come off it, which is what keeps the column
      // centred in a card whose facing corners are square.
      expect(
        icon.left - railRect.left,
        closeTo(railRect.right - icon.right, 0.001),
      );
    });

    testWidgets('a standalone rail on the trailing edge keeps its full lane', (
      tester,
    ) async {
      // Collapsed on the right the rail owns both gutters: the cluster
      // perimeter on its trailing edge and the leading gap the missing side
      // bar used to supply. Reserved on top of the allocation, not taken out
      // of it — absorbed, both come off the lane and the icon column narrows.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [_testTheme]),
          home: WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const Center(child: Text('Editor')),
            containerBuilder: _sidebarSpec,
            bottomPanel: const Center(child: Text('Panel')),
            statusBar: const SizedBox(height: 22, child: Text('Status')),
            initialSidebarPosition: WorkbenchSidebarPosition.right,
            initialSidebarVisible: false,
          ),
        ),
      );

      final railRect = tester.getRect(
        cardRing(find.byIcon(Symbols.folder_rounded)),
      );

      // The card is the allocation less its two gutters; the lane (both
      // strokes plus the icon inset either side) comes off that, leaving the
      // same icon column the rail has in every other state.
      expect(
        railRect.width - WorkbenchLayoutConstants.activityBarLane,
        closeTo(WorkbenchLayoutConstants.activityBarRailWidth, 0.001),
      );

      final icon = tester.getRect(find.byIcon(Symbols.folder_rounded));
      expect(
        icon.left - railRect.left,
        closeTo(railRect.right - icon.right, 0.001),
      );
    });

    testWidgets('the editor frame consumes no extra layout space', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(initialSidebarWidth: 300));

      final layout = tester.getRect(find.byType(WorkbenchLayout));
      const fixed =
          WorkbenchLayoutConstants.activityBarWidth + 300; // rail + side bar

      // The frame lives entirely inside the row's leftover width — the fixed
      // parts still measure what they always did, so drag-resize arithmetic
      // and the min/max floors keep measuring the same quantities.
      final editor = tester.getRect(cardRing(find.text('Editor')));
      expect(editor.left, greaterThanOrEqualTo(layout.left + fixed));
      expect(editor.right, lessThanOrEqualTo(layout.right));

      // The side bar's card spans its whole allocation horizontally: it cedes
      // the rail seam on one side and leaves the editor to lead with the gap
      // on the other.
      final sidebar = tester.getRect(cardRing(find.text('Explorer')));
      expect(sidebar.width, closeTo(300, 0.001));
    });

    testWidgets('the editor frame fills its vertical allocation', (
      tester,
    ) async {
      // No bottom panel: the editor and the side bar span the same band, from
      // the top perimeter gutter down to the status bar.
      await tester.pumpWidget(
        _buildApp(initialSidebarWidth: 300, showBottomPanel: false),
      );

      final editor = tester.getRect(cardRing(find.text('Editor')));
      final sidebar = tester.getRect(cardRing(find.text('Explorer')));
      expect(editor.top, closeTo(sidebar.top, 0.001));
      expect(editor.bottom, closeTo(sidebar.bottom, 0.001));
    });

    testWidgets('the editor stretches host content that would shrink-wrap', (
      tester,
    ) async {
      // A host editor that sizes to its content under a loose constraint —
      // a scroll view is the common case. The editor area's height comes from
      // the layout, so the content is stretched to it rather than the area
      // collapsing onto the content and centring it.
      await tester.pumpWidget(
        _buildApp(
          initialSidebarWidth: 300,
          showBottomPanel: false,
          editor: SingleChildScrollView(
            child: Column(
              children: List<Widget>.generate(
                3,
                (i) => SizedBox(height: 20, child: Text('line $i')),
              ),
            ),
          ),
        ),
      );

      // Compare against the allocation, not the content: card and content
      // shrink together, so measuring one against the other passes either way.
      final card = tester.getRect(cardRing(find.text('line 0')));
      final sidebar = tester.getRect(cardRing(find.text('Explorer')));
      expect(
        card.top,
        closeTo(sidebar.top, 0.001),
        reason: 'the editor area takes its height from the layout',
      );
      expect(card.bottom, closeTo(sidebar.bottom, 0.001));
    });

    testWidgets('the editor frame meets the panel it sits above', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(initialSidebarWidth: 300, initialPanelHeight: 200),
      );

      final editor = tester.getRect(cardRing(find.text('Editor')));
      final panel = tester.getRect(cardRing(find.text('Panel')));
      final sidebar = tester.getRect(cardRing(find.text('Explorer')));

      // The editor starts at the same top as the side bar and runs down to
      // the panel, leaving only the inter-card gap between them.
      expect(editor.top, closeTo(sidebar.top, 0.001));
      expect(
        panel.top - editor.bottom,
        closeTo(WorkbenchLayoutConstants.floatingCardGap, 0.001),
      );
    });

    testWidgets('selecting an activity bar item fills a rounded background', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());

      final active = indicator(_testTheme.activityBarItemActiveBackground);
      expect(active, findsOneWidget);

      // A filled box behind the icon, not an edge stroke: it is square, sized
      // off the item height, and rounded at the controls tier.
      final rect = tester.getRect(active);
      expect(
        rect.size,
        const Size(
          WorkbenchLayoutConstants.activityBarItemIndicatorSize,
          WorkbenchLayoutConstants.activityBarItemIndicatorSize,
        ),
      );
      final decoration =
          tester.widget<DecoratedBox>(active).decoration as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(
          WorkbenchLayoutConstants.activityBarItemIndicatorRadius,
        ),
      );

      // It sits behind the selected icon and follows the selection.
      expect(
        rect.center,
        tester.getRect(find.byIcon(Symbols.folder_rounded)).center,
      );
      await tester.tap(find.byIcon(Symbols.search_rounded));
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(indicator(_testTheme.activityBarItemActiveBackground))
            .center,
        tester.getRect(find.byIcon(Symbols.search_rounded)).center,
      );
    });

    testWidgets('hovering an unselected item fills the hover background', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());

      final hover = indicator(_testTheme.activityBarItemHoverBackground);
      expect(hover, findsNothing);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(
        location: tester.getCenter(find.byIcon(Symbols.search_rounded)),
      );
      addTearDown(pointer.removePointer);
      await tester.pumpAndSettle();

      expect(hover, findsOneWidget);
      expect(
        tester.getRect(hover).center,
        tester.getRect(find.byIcon(Symbols.search_rounded)).center,
      );
    });

    group('layout density', () {
      const perimeter = WorkbenchLayoutConstants.floatingCardPerimeter;
      const statusBarHeight = 22.0;

      /// Every part on screen at once, so a density change is measurable on
      /// each seam and each perimeter edge in one pump.
      /// Controlled, so a second pump in the same test re-renders at the new
      /// density rather than reusing the element seeded by the first.
      Widget densityApp(WorkbenchLayoutDensity density) => _buildApp(
        layoutDensity: density,
        onLayoutDensityChanged: (_) {},
        secondaryViewContainerIds: const ['outline'],
        secondarySideBarVisible: true,
        onSecondarySideBarVisibilityChanged: (_) {},
      );

      Rect cardOf(WidgetTester tester, String label) =>
          tester.getRect(cardRing(find.text(label)));

      testWidgets('compact closes the gaps so the parts meet edge-to-edge', (
        tester,
      ) async {
        for (final (density, expected) in [
          (WorkbenchLayoutDensity.standard, gap),
          (WorkbenchLayoutDensity.compact, 0.0),
        ]) {
          await tester.pumpWidget(densityApp(density));
          await tester.pumpAndSettle();

          final editor = cardOf(tester, 'Editor');
          final sidebar = cardOf(tester, 'Explorer');
          final secondary = cardOf(tester, 'Sidebar: outline');
          final panel = cardOf(tester, 'Panel');

          expect(
            editor.left - sidebar.right,
            closeTo(expected, 0.001),
            reason: '$density: side bar to editor',
          );
          expect(
            secondary.left - editor.right,
            closeTo(expected, 0.001),
            reason: '$density: editor to secondary side bar',
          );
          expect(
            panel.top - editor.bottom,
            closeTo(expected, 0.001),
            reason: '$density: editor to panel',
          );
        }
      });

      testWidgets('the rail keeps the shared seam in both side bar positions', (
        tester,
      ) async {
        // The seam names its owner explicitly — the rail draws it, the side bar
        // cedes it. Deriving ownership from which side leads instead loses the
        // hairline entirely on the right, where the rail holds the leading
        // edge, and compact is where that surfaces.
        for (final position in WorkbenchSidebarPosition.values) {
          await tester.pumpWidget(
            _buildApp(
              layoutDensity: WorkbenchLayoutDensity.compact,
              onLayoutDensityChanged: (_) {},
              sidebarPosition: position,
              onSidebarPositionChanged: (_) {},
            ),
          );
          await tester.pumpAndSettle();

          final rail = tester.widget<DecoratedBox>(
            cardRing(find.byIcon(Symbols.folder_rounded)),
          );
          final border = (rail.decoration as BoxDecoration).border! as Border;
          final facing = position == WorkbenchSidebarPosition.right
              ? border.left
              : border.right;
          expect(
            facing.color,
            _testTheme.surfaceBorder,
            reason: '$position: rail draws the seam it owns',
          );
        }
      });

      testWidgets('compact squares the card corners', (tester) async {
        await tester.pumpWidget(densityApp(WorkbenchLayoutDensity.compact));
        await tester.pumpAndSettle();

        for (final label in [
          'Explorer',
          'Sidebar: outline',
          'Panel',
          'Editor',
        ]) {
          final ring = cardRing(find.text(label));
          final decoration =
              tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
          expect(
            decoration.borderRadius,
            BorderRadius.zero,
            reason: '$label card',
          );
        }
      });

      testWidgets('the cluster perimeter gutter survives compact', (
        tester,
      ) async {
        // Upstream resolves the perimeter through getFloatingPanelOuterMargin,
        // whose compact branch is COMPACT_FLOATING_PANEL_OUTER_MARGIN = 4 — the
        // same step as the default density. Only the gap *between* cards
        // closes, so the cluster keeps breathing room against window chrome.
        for (final density in WorkbenchLayoutDensity.values) {
          await tester.pumpWidget(densityApp(density));
          await tester.pumpAndSettle();

          final layout = tester.getRect(find.byType(WorkbenchLayout));
          final rail = tester.getRect(
            cardRing(find.byIcon(Symbols.folder_rounded)),
          );
          final secondary = cardOf(tester, 'Sidebar: outline');
          final panel = cardOf(tester, 'Panel');

          expect(
            rail.left - layout.left,
            closeTo(perimeter, 0.001),
            reason: '$density: rail against the window edge',
          );
          expect(
            rail.top - layout.top,
            closeTo(perimeter, 0.001),
            reason: '$density: rail against the top edge',
          );
          expect(
            layout.right - secondary.right,
            closeTo(perimeter, 0.001),
            reason: '$density: secondary bar against the window edge',
          );
          expect(
            layout.bottom - statusBarHeight - panel.bottom,
            closeTo(perimeter, 0.001),
            reason: '$density: panel against the status bar',
          );
        }
      });

      testWidgets('compact draws one hairline per seam, not two', (
        tester,
      ) async {
        // Upstream's compact cards paint their trailing edges always and their
        // leading edges only on the cluster perimeter, so two abutting cards
        // show a single stroke. The editor's fill records it: inset by a
        // stroke where the card draws one, flush to the card edge where the
        // neighbour owns the seam.
        await tester.pumpWidget(densityApp(WorkbenchLayoutDensity.compact));
        await tester.pumpAndSettle();

        final editor = cardOf(tester, 'Editor');
        final fill = tester.getRect(
          fillOf(cardRing(find.text('Editor')), _testTheme.editorBackground),
        );

        // Left: the primary side bar draws the seam, so the editor cedes it.
        expect(fill.left, closeTo(editor.left, 0.001));
        // Top: window chrome, so the editor draws the perimeter stroke.
        expect(fill.top - editor.top, closeTo(stroke, 0.001));
        // Right and bottom: each card draws its own trailing edges.
        expect(editor.right - fill.right, closeTo(stroke, 0.001));
        expect(editor.bottom - fill.bottom, closeTo(stroke, 0.001));
      });

      testWidgets('the rail keeps its icons optically centred in both '
          'densities', (tester) async {
        for (final (density, allocation) in [
          (
            WorkbenchLayoutDensity.standard,
            WorkbenchLayoutConstants.activityBarWidth,
          ),
          (WorkbenchLayoutDensity.compact, 44.0),
        ]) {
          await tester.pumpWidget(densityApp(density));
          await tester.pumpAndSettle();

          final layout = tester.getRect(find.byType(WorkbenchLayout));
          final rail = tester.getRect(
            cardRing(find.byIcon(Symbols.folder_rounded)),
          );
          final icon = tester.getRect(find.byIcon(Symbols.folder_rounded));

          // Equal margins either side of the icon column: each density halves
          // its own lane after the card's two strokes come off it.
          expect(
            icon.left - rail.left,
            closeTo(rail.right - icon.right, 0.001),
            reason: '$density: icon column centred',
          );
          // The lane narrows, so the allocation does — the icon column itself
          // keeps its own width in both densities.
          expect(
            cardOf(tester, 'Explorer').left - layout.left,
            closeTo(allocation, 0.001),
            reason: '$density: rail allocation',
          );
        }
      });

      testWidgets('uncontrolled: the shell tracks the seeded density', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildApp(initialLayoutDensity: WorkbenchLayoutDensity.compact),
        );
        await tester.pumpAndSettle();

        expect(
          cardOf(tester, 'Editor').left - cardOf(tester, 'Explorer').right,
          closeTo(0, 0.001),
        );
      });

      testWidgets('controlled: the host drives layoutDensity', (tester) async {
        var density = WorkbenchLayoutDensity.standard;
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
                  layoutDensity: density,
                  onLayoutDensityChanged: (next) =>
                      setState(() => density = next),
                );
              },
            ),
          ),
        );

        double seam() =>
            cardOf(tester, 'Editor').left - cardOf(tester, 'Explorer').right;
        expect(seam(), closeTo(gap, 0.001));

        setOuter(() => density = WorkbenchLayoutDensity.compact);
        await tester.pumpAndSettle();
        expect(seam(), closeTo(0, 0.001));
      });

      testWidgets('asserts onLayoutDensityChanged is required in controlled '
          'mode', (tester) async {
        expect(
          () => WorkbenchLayout(
            activityBarItems: _testItems,
            editor: const SizedBox(),
            containerBuilder: _sidebarSpec,
            bottomPanel: const SizedBox(),
            statusBar: const SizedBox(),
            layoutDensity: WorkbenchLayoutDensity.compact,
          ),
          throwsAssertionError,
        );
      });
    });
  });

  group('Base surface treatment (§spec:modern-ui-surfaces)', () {
    // Base VS Code draws each part's seam from its own border token, which the
    // treatment suppresses in favour of the shared card hairline. The fixture
    // leaves those tokens null, so the tests set them to read a colour rather
    // than an absence.
    const sideBarSeam = Color(0xFF101010);
    const activityBarSeam = Color(0xFF202020);
    const panelSeam = Color(0xFF303030);
    final baseTheme = _testTheme.copyWith(
      sideBarBorder: sideBarSeam,
      activityBarBorder: activityBarSeam,
      panelBorder: panelSeam,
    );

    /// The nearest ancestor [Container] of [of] painting [color] on any edge —
    /// how base VS Code draws a part seam, and what the card ring replaced.
    Finder seamBox(Finder of, Color color) => find.ancestor(
      of: of,
      matching: find.byWidgetPredicate((w) {
        if (w is! Container) return false;
        final decoration = w.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        if (border is! Border) return false;
        return [
          border.left,
          border.top,
          border.right,
          border.bottom,
        ].any((side) => side.width > 0 && side.color == color);
      }),
    );

    /// Anything painting the treatment's shared card hairline.
    Finder cardHairline() => find.byWidgetPredicate((w) {
      if (w is! DecoratedBox) return false;
      final decoration = w.decoration;
      if (decoration is! BoxDecoration) return false;
      if (decoration.color == baseTheme.surfaceBorder) return true;
      final border = decoration.border;
      if (border is! Border) return false;
      return [
        border.left,
        border.top,
        border.right,
        border.bottom,
      ].any((side) => side.width > 0 && side.color == baseTheme.surfaceBorder);
    });

    Rect editorRect(WidgetTester tester) => tester.getRect(
      find.ancestor(of: find.text('Editor'), matching: find.byType(Center)).first,
    );

    testWidgets('packs the parts flush — no card gutter, stroke or radius', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          initialModernUI: false,
          theme: baseTheme,
          secondaryViewContainerIds: const ['outline'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
        ),
      );

      expect(cardHairline(), findsNothing);

      final rail = tester.getRect(seamBox(
        find.byIcon(Symbols.folder_rounded),
        activityBarSeam,
      ));
      final sidebar = tester.getRect(
        seamBox(find.text('EXPLORER'), sideBarSeam),
      );
      final editor = editorRect(tester);
      final panel = tester.getRect(seamBox(find.text('Panel'), panelSeam));

      expect(rail.right, closeTo(sidebar.left, 0.001));
      expect(sidebar.right, closeTo(editor.left, 0.001));
      expect(editor.bottom, closeTo(panel.top, 0.001));
    });

    testWidgets('draws no sash grips', (tester) async {
      // `sashHandles.css` is a treatment stylesheet; base VS Code's sashes are
      // invisible until hovered (§spec:modern-ui-surfaces).
      await tester.pumpWidget(
        _buildApp(initialModernUI: false, theme: baseTheme),
      );
      expect(find.byKey(sashGripKey), findsNothing);
    });

    testWidgets('uppercases the composite title and the secondary tabs', (
      tester,
    ) async {
      // Base `part.css` renders `.title-label` uppercase at 11 / w400, which
      // the treatment replaces (§spec:chrome-typography-canon).
      await tester.pumpWidget(
        _buildApp(
          initialModernUI: false,
          theme: baseTheme,
          secondaryViewContainerIds: const ['outline', 'notes'],
          secondarySideBarVisible: true,
          onSecondarySideBarVisibilityChanged: (_) {},
          containerBuilder: (id) => WorkbenchViewContainerSpec(
            title: id == 'explorer' ? null : 'Titled $id',
            mergeSingleView: true,
            views: [
              WorkbenchViewDescriptor(
                id: id,
                title: id,
                bodyBuilder: (_) => Text('body-$id'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('EXPLORER'), findsOneWidget);
      expect(find.text('Explorer'), findsNothing);
      expect(find.text('TITLED OUTLINE'), findsOneWidget);
      expect(find.text('TITLED NOTES'), findsOneWidget);

      expect(
        tester.widget<Text>(find.text('EXPLORER')).style,
        baseTheme.baseSidebarOrPanelHeading,
      );
    });

    testWidgets('insets the composite title at the base part and label tiers', (
      tester,
    ) async {
      // Base `part.css`: 8px on the part, a further 12px on the label.
      await tester.pumpWidget(
        _buildApp(initialModernUI: false, theme: baseTheme),
      );
      final card = tester.getRect(
        seamBox(find.text('EXPLORER'), sideBarSeam),
      );
      final label = tester.getRect(find.text('EXPLORER'));
      expect(
        label.left - card.left,
        closeTo(
          WorkbenchLayoutConstants.spacingSize80 +
              WorkbenchLayoutConstants.spacingSize120,
          0.001,
        ),
      );
    });

    testWidgets('keeps the composite title in the base 35px band', (
      tester,
    ) async {
      // Base `part.css`: `.part > .title { height: 35px }`.
      await tester.pumpWidget(
        _buildApp(initialModernUI: false, theme: baseTheme),
      );
      expect(
        tester.getSize(_titleBand('EXPLORER')).height,
        WorkbenchLayoutConstants.sidebarHeadingHeight,
      );
    });

    testWidgets('grounds the workbench on the editor background', (
      tester,
    ) async {
      // No card gutters to show a backdrop through, so the pre-treatment
      // ground stands: base VS Code has no `floatingPanels.css` shell colour.
      final theme = _splitBackdrop(baseTheme);
      await tester.pumpWidget(
        _buildApp(initialModernUI: false, theme: theme),
      );
      expect(_scaffoldFill(tester), theme.editorBackground);
    });

    testWidgets('draws each part seam from its own border token', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(initialModernUI: false, theme: baseTheme),
      );

      // The seam faces the neighbour it separates: the rail and the side bar
      // both draw on their editor-facing edge, the panel on its top edge
      // (§spec:sidebar-position).
      BoxDecoration decorationOf(Finder finder) =>
          tester.widget<Container>(finder).decoration! as BoxDecoration;

      final rail = decorationOf(
        seamBox(find.byIcon(Symbols.folder_rounded), activityBarSeam),
      );
      expect((rail.border! as Border).right.color, activityBarSeam);
      expect(rail.color, baseTheme.activityBarBackground);

      final sidebar = decorationOf(seamBox(find.text('EXPLORER'), sideBarSeam));
      expect((sidebar.border! as Border).right.color, sideBarSeam);
      // Base fills the primary side bar from its own token, not the shared
      // card surface the treatment introduced.
      expect(sidebar.color, baseTheme.sideBarBackground);

      final panel = decorationOf(seamBox(find.text('Panel'), panelSeam));
      expect((panel.border! as Border).top.color, panelSeam);
    });

    testWidgets('marks the active activity bar item with the base left-border '
        'indicator', (tester) async {
      // The fixture theme leaves `activityBar.border` null, so the bar draws no
      // seam and an item measures the full allocation rather than the
      // allocation less a hairline.
      await tester.pumpWidget(_buildApp(initialModernUI: false));

      Container itemOf(IconData icon) => tester.widget<Container>(
        find
            .ancestor(of: find.byIcon(icon), matching: find.byType(Container))
            .first,
      );

      final active = itemOf(Symbols.folder_rounded);
      final indicator = (active.decoration! as BoxDecoration).border! as Border;
      expect(indicator.left.color, _testTheme.activityBarForeground);
      expect(
        indicator.left.width,
        WorkbenchLayoutConstants.activityBarIndicatorWidth,
      );

      // An inactive item reserves the same stripe transparently, so selecting
      // one never reflows the column.
      final inactive = itemOf(Symbols.search_rounded);
      expect(
        ((inactive.decoration! as BoxDecoration).border! as Border).left.color,
        Colors.transparent,
      );

      // The square item box the stripe rides on, at the rail's full width.
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.byIcon(Symbols.folder_rounded),
                matching: find.byType(Container),
              )
              .first,
        ),
        const Size(
          WorkbenchLayoutConstants.activityBarWidth,
          WorkbenchLayoutConstants.activityBarWidth,
        ),
      );

      // No filled background behind the icon — that is the treatment's
      // affordance, and it is the one this replaces.
      expect(
        find.byWidgetPredicate((w) {
          if (w is! DecoratedBox) return false;
          final decoration = w.decoration;
          return decoration is BoxDecoration &&
              decoration.color == _testTheme.activityBarItemActiveBackground;
        }),
        findsNothing,
      );
    });

    testWidgets('restores the cards when the host switches the treatment back '
        'on', (tester) async {
      var modernUI = false;
      late StateSetter setOuter;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [baseTheme]),
          home: StatefulBuilder(
            builder: (context, setState) {
              setOuter = setState;
              return WorkbenchLayout(
                activityBarItems: _testItems,
                editor: const Center(child: Text('Editor')),
                containerBuilder: _sidebarSpec,
                bottomPanel: const Center(child: Text('Panel')),
                statusBar: const SizedBox(height: 22, child: Text('Status')),
                modernUI: modernUI,
                onModernUIChanged: (next) => setState(() => modernUI = next),
              );
            },
          ),
        ),
      );

      expect(cardHairline(), findsNothing);

      setOuter(() => modernUI = true);
      await tester.pumpAndSettle();
      expect(cardHairline(), findsWidgets);
    });

    testWidgets('ships the treatment on', (tester) async {
      await tester.pumpWidget(_buildApp(theme: baseTheme));
      expect(cardHairline(), findsWidgets);
    });

    testWidgets('asserts onModernUIChanged is required in controlled mode', (
      tester,
    ) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: _testItems,
          editor: const SizedBox(),
          containerBuilder: _sidebarSpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          modernUI: false,
        ),
        throwsAssertionError,
      );
    });
  });
}

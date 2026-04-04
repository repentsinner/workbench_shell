import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

const _testTheme = WorkbenchTheme(
  activityBarBackground: Color(0xFF333333),
  activityBarBorder: Color(0xFF444444),
  activityBarForeground: Color(0xFFFFFFFF),
  activityBarInactiveForeground: Color(0xFF888888),
  sideBarBackground: Color(0xFF252526),
  sideBarBorder: Color(0xFF444444),
  editorBackground: Color(0xFF1E1E1E),
  panelBorder: Color(0xFF444444),
  statusBarBackground: Color(0xFF007ACC),
  statusBarBorder: Color(0xFF007ACC),
  sashHoverBackground: Color(0xFF007ACC),
  sidebarOrPanelHeading: TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: Color(0xFFBBBBBB),
  ),
);

final _testItems = [
  const ActivityBarItem(
    id: 'explorer',
    label: 'Explorer',
    icon: Icons.folder,
    sortOrder: 100,
  ),
  const ActivityBarItem(
    id: 'search',
    label: 'Search',
    icon: Icons.search,
    sortOrder: 200,
  ),
  const ActivityBarItem(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings,
    zone: ActivityBarZone.bottom,
    sortOrder: 900,
  ),
];

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
      sidebarBuilder: (id) => Center(child: Text('Sidebar: $id')),
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

      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
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
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Sidebar: search'), findsOneWidget);
      expect(find.text('SEARCH'), findsOneWidget);
    });

    testWidgets('toggles sidebar on tapping active section', (tester) async {
      await tester.pumpWidget(_buildApp());

      // Sidebar visible initially
      expect(find.text('EXPLORER'), findsOneWidget);

      // Tap active section hides sidebar
      await tester.tap(find.byIcon(Icons.folder));
      await tester.pumpAndSettle();
      expect(find.text('EXPLORER'), findsNothing);

      // Tap again shows sidebar
      await tester.tap(find.byIcon(Icons.folder));
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
  });

  group('ActivityBarItem', () {
    test('equality based on id', () {
      const a = ActivityBarItem(id: 'test', label: 'Test', icon: Icons.star);
      const b = ActivityBarItem(
        id: 'test',
        label: 'Different Label',
        icon: Icons.circle,
      );
      expect(a, equals(b));
    });

    test('inequality for different ids', () {
      const a = ActivityBarItem(id: 'test1', label: 'Test', icon: Icons.star);
      const b = ActivityBarItem(id: 'test2', label: 'Test', icon: Icons.star);
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

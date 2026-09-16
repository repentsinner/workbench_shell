import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/src/workbench_editor_tabs.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

WorkbenchViewContainerSpec _emptySpec(String id) =>
    const WorkbenchViewContainerSpec(views: []);

/// A tab whose content names its id, so a test can tell which one shows.
WorkbenchEditorTab _tab(
  String id, {
  IconData? icon,
  bool isDirty = false,
  WidgetBuilder? contentBuilder,
}) {
  return WorkbenchEditorTab(
    id: id,
    label: 'Tab $id',
    icon: icon,
    isDirty: isDirty,
    contentBuilder: contentBuilder ?? (_) => Text('Content $id'),
  );
}

Widget _layout({
  List<WorkbenchEditorTab> editorTabs = const [],
  String? initialActiveEditorTabId,
  String? activeEditorTabId,
  ValueChanged<String>? onActiveEditorTabChanged,
  bool? zenMode,
  bool? centeredLayout,
  bool modernUI = false,
  WorkbenchTheme? theme,
}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [theme ?? testWorkbenchTheme]),
    home: WorkbenchLayout(
      activityBarItems: const [],
      editor: const Center(child: Text('Empty editor')),
      containerBuilder: _emptySpec,
      bottomPanel: const SizedBox.shrink(),
      showBottomPanel: false,
      statusBar: const SizedBox(height: 22),
      editorTabs: editorTabs,
      initialActiveEditorTabId: initialActiveEditorTabId,
      activeEditorTabId: activeEditorTabId,
      onActiveEditorTabChanged: onActiveEditorTabChanged,
      zenMode: zenMode,
      onZenModeChanged: zenMode == null ? null : (_) {},
      centeredLayout: centeredLayout,
      onCenteredLayoutChanged: centeredLayout == null ? null : (_) {},
      modernUI: modernUI,
      onModernUIChanged: (_) {},
    ),
  );
}

/// The tab's own surface: the nearest decorated box painting a fill above
/// its label.
BoxDecoration _tabDecoration(WidgetTester tester, String label) {
  final container = tester
      .widgetList<Container>(
        find.ancestor(of: find.text(label), matching: find.byType(Container)),
      )
      .firstWhere((c) => c.decoration is BoxDecoration);
  return container.decoration! as BoxDecoration;
}

void main() {
  group('Editor tab strip (§spec:editor-tabs)', () {
    testWidgets('a layout given no tabs renders editor unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(_layout());
      expect(find.text('Empty editor'), findsOneWidget);
      expect(find.byType(EditorTabStrip), findsNothing);
    });

    testWidgets('a layout given tabs renders a strip over the first tab', (
      tester,
    ) async {
      await tester.pumpWidget(
        _layout(
          editorTabs: [
            _tab('a', icon: Symbols.description),
            _tab('b'),
          ],
        ),
      );
      expect(find.byType(EditorTabStrip), findsOneWidget);
      expect(find.text('Tab a'), findsOneWidget);
      expect(find.text('Tab b'), findsOneWidget);
      expect(find.byIcon(Symbols.description), findsOneWidget);
      expect(find.text('Content a'), findsOneWidget);
      expect(find.text('Content b'), findsNothing);
      // The host's empty-editor surface gives way to the tabs.
      expect(find.text('Empty editor'), findsNothing);
      // The strip sits above the content.
      expect(
        tester.getBottomLeft(find.byType(EditorTabStrip)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Content a')).dy),
      );
    });

    testWidgets('a single tab still renders as a strip', (tester) async {
      await tester.pumpWidget(_layout(editorTabs: [_tab('a')]));
      expect(find.byType(EditorTabStrip), findsOneWidget);
    });

    testWidgets('the strip is a 35px row on the tabs background', (
      tester,
    ) async {
      await tester.pumpWidget(_layout(editorTabs: [_tab('a'), _tab('b')]));
      expect(
        tester.getSize(find.byType(EditorTabStrip)).height,
        WorkbenchLayoutConstants.editorTabHeight,
      );
      expect(WorkbenchLayoutConstants.editorTabHeight, 35);
      final strip = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(EditorTabStrip),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(strip.color, testWorkbenchTheme.editorGroupHeaderTabsBackground);
    });

    testWidgets('a tab is fit-sized: at least 120px, growing with its label', (
      tester,
    ) async {
      final long = WorkbenchEditorTab(
        id: 'long',
        label: 'A very long editor tab label that needs more than the minimum',
        contentBuilder: (_) => const SizedBox(),
      );
      await tester.pumpWidget(_layout(editorTabs: [_tab('a'), long]));
      expect(
        tester.getSize(find.byKey(const ValueKey('editor-tab-a'))).width,
        WorkbenchLayoutConstants.editorTabMinWidth,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('editor-tab-long'))).width,
        greaterThan(WorkbenchLayoutConstants.editorTabMinWidth),
      );
    });

    testWidgets('the active and inactive tabs paint their tab.* tokens', (
      tester,
    ) async {
      await tester.pumpWidget(_layout(editorTabs: [_tab('a'), _tab('b')]));
      final theme = testWorkbenchTheme;
      final active = _tabDecoration(tester, 'Tab a');
      final inactive = _tabDecoration(tester, 'Tab b');
      expect(active.color, theme.tabActiveBackground);
      expect(inactive.color, theme.tabInactiveBackground);
      // Each tab draws a tab.border divider on its trailing edge.
      final border = active.border! as Border;
      expect(border.right.color, theme.tabBorder);

      final activeLabel = tester.widget<Text>(find.text('Tab a'));
      final inactiveLabel = tester.widget<Text>(find.text('Tab b'));
      expect(activeLabel.style!.color, theme.tabActiveForeground);
      expect(inactiveLabel.style!.color, theme.tabInactiveForeground);
      // The editor-tab tier of the typography canon.
      expect(activeLabel.style!.fontSize, 13);
      expect(activeLabel.style!.fontWeight, FontWeight.w400);
    });

    testWidgets('the active tab draws top and bottom rules only when the '
        'theme sets them', (tester) async {
      Finder rules() => find.byKey(const ValueKey('editor-tab-active-rules'));
      await tester.pumpWidget(_layout(editorTabs: [_tab('a'), _tab('b')]));
      final unset = tester.widget<DecoratedBox>(rules());
      final unsetBorder = (unset.decoration as BoxDecoration).border! as Border;
      expect(unsetBorder.top, BorderSide.none);
      expect(unsetBorder.bottom, BorderSide.none);

      const top = Color(0xFF0078D4);
      const bottom = Color(0xFF1F1F1F);
      await tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b')],
          theme: testWorkbenchTheme.copyWith(
            tabActiveBorderTop: top,
            tabActiveBorder: bottom,
          ),
        ),
      );
      // MaterialApp animates between themes.
      await tester.pumpAndSettle();
      final set =tester.widget<DecoratedBox>(rules());
      final setBorder = (set.decoration as BoxDecoration).border! as Border;
      expect(setBorder.top.color, top);
      expect(setBorder.top.width, WorkbenchLayoutConstants.strokeThickness);
      expect(setBorder.bottom.color, bottom);
      // Only the active tab carries the rules.
      expect(rules(), findsOneWidget);
    });

    testWidgets('clicking a tab shows its content and reports it', (
      tester,
    ) async {
      final reported = <String>[];
      await tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b')],
          onActiveEditorTabChanged: reported.add,
        ),
      );
      await tester.tap(find.text('Tab b'));
      await tester.pump();
      expect(find.text('Content b'), findsOneWidget);
      expect(find.text('Content a'), findsNothing);
      expect(reported, ['b']);

      // Clicking the active tab again reports nothing.
      await tester.tap(find.text('Tab b'));
      await tester.pump();
      expect(reported, ['b']);
    });

    testWidgets('initialActiveEditorTabId seeds the active tab', (
      tester,
    ) async {
      await tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b')],
          initialActiveEditorTabId: 'b',
        ),
      );
      expect(find.text('Content b'), findsOneWidget);
    });

    testWidgets('controlled: the host drives the active tab', (tester) async {
      var active = 'a';
      final reported = <String>[];
      late StateSetter setOuter;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return _layout(
              editorTabs: [_tab('a'), _tab('b')],
              activeEditorTabId: active,
              onActiveEditorTabChanged: reported.add,
            );
          },
        ),
      );
      await tester.tap(find.text('Tab b'));
      await tester.pump();
      // Reported, but the host has not honoured it yet.
      expect(reported, ['b']);
      expect(find.text('Content a'), findsOneWidget);

      setOuter(() => active = 'b');
      await tester.pump();
      expect(find.text('Content b'), findsOneWidget);
    });

    testWidgets('asserts onActiveEditorTabChanged is required in controlled '
        'mode', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: const [],
          editor: const SizedBox(),
          containerBuilder: _emptySpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          editorTabs: [_tab('a')],
          activeEditorTabId: 'a',
        ),
        throwsAssertionError,
      );
    });

    testWidgets('asserts tab ids are unique', (tester) async {
      expect(
        () => WorkbenchLayout(
          activityBarItems: const [],
          editor: const SizedBox(),
          containerBuilder: _emptySpec,
          bottomPanel: const SizedBox(),
          statusBar: const SizedBox(),
          editorTabs: [_tab('a'), _tab('a')],
        ),
        throwsAssertionError,
      );
    });

    testWidgets('tab content is built only once its tab becomes active', (
      tester,
    ) async {
      final built = <String>[];
      WorkbenchEditorTab counted(String id) => _tab(
        id,
        contentBuilder: (_) {
          built.add(id);
          return Text('Content $id');
        },
      );
      await tester.pumpWidget(
        _layout(editorTabs: [counted('a'), counted('b')]),
      );
      expect(built, isNot(contains('b')));

      await tester.tap(find.text('Tab b'));
      await tester.pump();
      expect(built, contains('b'));
    });

    testWidgets('a tab keeps its widget state across switches', (tester) async {
      WorkbenchEditorTab scrolling(String id) => _tab(
        id,
        contentBuilder: (_) => ListView.builder(
          key: PageStorageKey<String>('list-$id'),
          itemCount: 100,
          itemBuilder: (_, i) => SizedBox(height: 40, child: Text('$id $i')),
        ),
      );
      await tester.pumpWidget(
        _layout(editorTabs: [scrolling('a'), scrolling('b')]),
      );
      await tester.drag(find.text('a 0'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('a 0'), findsNothing);

      await tester.tap(find.text('Tab b'));
      await tester.pumpAndSettle();
      expect(find.text('b 0'), findsOneWidget);

      await tester.tap(find.text('Tab a'));
      await tester.pumpAndSettle();
      // Scrolled away from the top, as it was left.
      expect(find.text('a 0'), findsNothing);
      expect(find.text('a 12'), findsOneWidget);
    });

    testWidgets('an inactive tab is retained offstage with tickers off', (
      tester,
    ) async {
      await tester.pumpWidget(_layout(editorTabs: [_tab('a'), _tab('b')]));
      await tester.tap(find.text('Tab b'));
      await tester.pump();
      // Still in the tree, offstage.
      expect(find.text('Content a', skipOffstage: false), findsOneWidget);
      final context = tester.element(
        find.text('Content a', skipOffstage: false),
      );
      expect(TickerMode.valuesOf(context).enabled, isFalse);
    });

    testWidgets('removing every tab restores the editor with no strip', (
      tester,
    ) async {
      var tabs = [_tab('a'), _tab('b')];
      late StateSetter setOuter;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return _layout(editorTabs: tabs);
          },
        ),
      );
      setOuter(() => tabs = const []);
      await tester.pump();
      expect(find.byType(EditorTabStrip), findsNothing);
      expect(find.text('Empty editor'), findsOneWidget);
    });

    testWidgets('Zen and centered layout carry the strip with the content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a')], zenMode: true, centeredLayout: true),
      );
      expect(find.byType(EditorTabStrip), findsOneWidget);
      expect(find.text('Content a'), findsOneWidget);
      // Centered narrows the strip and content together.
      final screen = tester.getSize(find.byType(WorkbenchLayout)).width;
      expect(
        tester.getSize(find.byType(EditorTabStrip)).width,
        lessThan(screen),
      );
    });

    testWidgets('the Modern UI flag renders the base strip until the '
        'connected treatment lands', (tester) async {
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a'), _tab('b')], modernUI: true),
      );
      expect(
        tester.getSize(find.byType(EditorTabStrip)).height,
        WorkbenchLayoutConstants.editorTabHeight,
      );
    });

    testWidgets('exposes each tab as a selectable tab to assistive '
        'technology', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a'), _tab('b', isDirty: true)]),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('editor-tab-a'))),
        matchesSemantics(
          label: 'Tab a',
          isSelected: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('editor-tab-b'))),
        matchesSemantics(
          label: 'Tab b',
          value: 'unsaved changes',
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}

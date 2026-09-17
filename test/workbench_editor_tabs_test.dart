import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  ValueChanged<List<String>>? onEditorTabOrderChanged,
  ValueChanged<String>? onEditorTabCloseRequested,
  bool? zenMode,
  bool? centeredLayout,
  bool modernUI = false,
  WorkbenchLayoutDensity? layoutDensity,
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
      onEditorTabOrderChanged: onEditorTabOrderChanged,
      onEditorTabCloseRequested: onEditorTabCloseRequested,
      zenMode: zenMode,
      onZenModeChanged: zenMode == null ? null : (_) {},
      centeredLayout: centeredLayout,
      onCenteredLayoutChanged: centeredLayout == null ? null : (_) {},
      modernUI: modernUI,
      onModernUIChanged: (_) {},
      layoutDensity: layoutDensity,
      onLayoutDensityChanged: layoutDensity == null ? null : (_) {},
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
      final strip = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('editor-tab-strip-background')),
      );
      final decoration = strip.decoration as BoxDecoration;
      expect(
        decoration.color,
        testWorkbenchTheme.editorGroupHeaderTabsBackground,
      );
      expect(decoration.border, isNull);
    });

    testWidgets('the strip repaints apart from the editor content', (
      tester,
    ) async {
      for (final modernUI in [false, true]) {
        await tester.pumpWidget(
          _layout(editorTabs: [_tab('a'), _tab('b')], modernUI: modernUI),
        );
        // Hover and drag feedback repaint the strip alone.
        expect(
          tester.renderObject(find.byType(EditorTabStrip)).isRepaintBoundary,
          isTrue,
        );
      }
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
      final set = tester.widget<DecoratedBox>(rules());
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

    testWidgets('an unchanged hidden tab is not rebuilt when the layout '
        'rebuilds', (tester) async {
      var builds = 0;
      final a = _tab(
        'a',
        contentBuilder: (_) {
          builds++;
          return const Text('Content a');
        },
      );
      final b = _tab('b');
      late StateSetter setOuter;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return _layout(editorTabs: [a, b]);
          },
        ),
      );
      await tester.tap(find.text('Tab b'));
      await tester.pump();
      final before = builds;

      // The host rebuilds with the same descriptors.
      setOuter(() {});
      await tester.pump();
      expect(builds, before);
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

  group('Pill editor tabs under Modern UI (§spec:editor-tab-rendering)', () {
    Finder tabOf(String id) => find.byKey(ValueKey('editor-tab-$id'));

    /// The rounded fill behind the tab with [id].
    Finder fillOf(String id) => find.descendant(
      of: tabOf(id),
      matching: find.byKey(const ValueKey('editor-tab-pill-fill')),
    );

    BoxDecoration fillDecoration(WidgetTester tester, String id) =>
        tester.widget<DecoratedBox>(fillOf(id)).decoration as BoxDecoration;

    Color? labelColor(WidgetTester tester, String id) =>
        tester.widget<Text>(find.text('Tab $id')).style!.color;

    Future<TestGesture> hover(WidgetTester tester, Finder target) async {
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(target));
      await tester.pump();
      return pointer;
    }

    testWidgets('the strip is a transparent 32px row at either density', (
      tester,
    ) async {
      // editorTabsControl.ts: EDITOR_TAB_HEIGHT.modernUI, a 24px tab with 4px
      // above and below.
      expect(WorkbenchLayoutConstants.modernEditorTabStripHeight, 32);
      for (final density in WorkbenchLayoutDensity.values) {
        await tester.pumpWidget(
          _layout(
            editorTabs: [_tab('a'), _tab('b')],
            modernUI: true,
            layoutDensity: density,
          ),
        );
        expect(
          tester.getSize(find.byType(EditorTabStrip)).height,
          WorkbenchLayoutConstants.modernEditorTabStripHeight,
        );
        final strip = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('editor-tab-strip-background')),
        );
        final decoration = strip.decoration as BoxDecoration;
        // The editor card shows through: no fill, no separator.
        expect(decoration.color, isNull);
        expect(decoration.border, isNull);
      }
    });

    testWidgets('the first tab stands a 2px inset from the strip edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a'), _tab('b')], modernUI: true),
      );
      expect(
        tester.getTopLeft(tabOf('a')).dx -
            tester.getTopLeft(find.byType(EditorTabStrip)).dx,
        WorkbenchLayoutConstants.modernEditorTabStripInset,
      );
      // Neighbouring tabs touch, so the hit targets leave no gap; the fills
      // stand apart.
      expect(
        tester.getTopLeft(tabOf('b')).dx,
        tester.getTopRight(tabOf('a')).dx,
      );
    });

    testWidgets('each tab carries a 24px rounded fill inset from its box', (
      tester,
    ) async {
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a'), _tab('b')], modernUI: true),
      );
      final tab = tester.getRect(tabOf('a'));
      final fill = tester.getRect(fillOf('a'));
      expect(fill.height, WorkbenchLayoutConstants.modernEditorTabHeight);
      expect(
        fill.top - tab.top,
        WorkbenchLayoutConstants.modernEditorTabRowInset,
      );
      expect(
        fill.left - tab.left,
        WorkbenchLayoutConstants.modernEditorTabFillInset,
      );
      expect(
        tab.right - fill.right,
        WorkbenchLayoutConstants.modernEditorTabFillInset,
      );
      expect(
        fillDecoration(tester, 'a').borderRadius,
        BorderRadius.circular(WorkbenchLayoutConstants.cornerRadiusSmall),
      );
    });

    testWidgets('the active pill fills and inactive pills stay clear, with '
        'dimmed labels', (tester) async {
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a'), _tab('b')], modernUI: true),
      );
      final theme = testWorkbenchTheme;
      expect(
        fillDecoration(tester, 'a').color,
        theme.modernEditorTabActiveBackground,
      );
      expect(fillDecoration(tester, 'b').color, isNull);
      expect(labelColor(tester, 'a'), theme.modernEditorTabActiveForeground);
      expect(labelColor(tester, 'b'), theme.modernEditorTabInactiveForeground);
    });

    testWidgets('hovering fills an inactive pill in the hover colours and an '
        'active pill in the active-hover fill', (tester) async {
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a'), _tab('b')], modernUI: true),
      );
      final theme = testWorkbenchTheme.copyWith(
        modernEditorTabActiveHoverBackground: const Color(0xFF123456),
      );
      await tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b')],
          modernUI: true,
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();

      final pointer = await hover(tester, find.text('Tab b'));
      expect(
        fillDecoration(tester, 'b').color,
        theme.modernEditorTabHoverBackground,
      );
      expect(labelColor(tester, 'b'), theme.modernEditorTabHoverForeground);

      await pointer.moveTo(tester.getCenter(find.text('Tab a')));
      await tester.pump();
      expect(fillDecoration(tester, 'b').color, isNull);
      expect(
        fillDecoration(tester, 'a').color,
        theme.modernEditorTabActiveHoverBackground,
      );
      expect(labelColor(tester, 'a'), theme.modernEditorTabActiveForeground);
    });

    testWidgets("a theme's tab.* colours leave the pills alone", (
      tester,
    ) async {
      const red = Color(0xFFFF0000);
      final theme = testWorkbenchTheme.copyWith(
        tabActiveBackground: red,
        tabInactiveBackground: red,
        tabActiveForeground: red,
        tabInactiveForeground: red,
      );
      await tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b')],
          modernUI: true,
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      expect(fillDecoration(tester, 'a').color, isNot(red));
      expect(labelColor(tester, 'a'), isNot(red));
      expect(labelColor(tester, 'b'), isNot(red));
    });

    testWidgets('tabs are content-sized and reserve the action column on '
        'every tab', (tester) async {
      await tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b')],
          modernUI: true,
          onEditorTabCloseRequested: (_) {},
        ),
      );
      // `.sizing-fit` drops the base 120px floor under the treatment.
      expect(
        tester.getSize(tabOf('a')).width,
        lessThan(WorkbenchLayoutConstants.editorTabMinWidth),
      );
      for (final id in ['a', 'b']) {
        final tab = tester.getRect(tabOf(id));
        final actions = find.descendant(
          of: tabOf(id),
          matching: find.byKey(const ValueKey('editor-tab-actions')),
        );
        final column = tester.getRect(actions);
        expect(
          column.width,
          WorkbenchLayoutConstants.modernEditorTabActionsWidth,
        );
        expect(column.height, WorkbenchLayoutConstants.modernEditorTabHeight);
        // `.tab-actions { right: 0; margin: 0 spacing.size20 }`.
        expect(
          tab.right - column.right,
          WorkbenchLayoutConstants.modernEditorTabActionsMargin,
        );
        // `tabActionReserveSpace` keeps the close button on every tab.
        expect(tester.widget<Opacity>(actions).opacity, 1);
        // The label ends before the reserved 28px column.
        expect(
          tab.right - tester.getRect(find.text('Tab $id')).right,
          greaterThanOrEqualTo(WorkbenchLayoutConstants.spacingSize280),
        );
      }
    });

    testWidgets('without a close handler a clean tab reserves no column', (
      tester,
    ) async {
      await tester.pumpWidget(_layout(editorTabs: [_tab('a')], modernUI: true));
      final tab = tester.getRect(tabOf('a'));
      // `.close-action-off { padding: 0 spacing.size80 0 spacing.size60 }`.
      expect(
        tab.right - tester.getRect(find.text('Tab a')).right,
        WorkbenchLayoutConstants.modernEditorTabPadding,
      );
    });

    testWidgets('a dirty tab shows its close button while the tab is '
        'hovered', (tester) async {
      await tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b', isDirty: true)],
          modernUI: true,
          onEditorTabCloseRequested: (_) {},
        ),
      );
      Finder inB(IconData icon) =>
          find.descendant(of: tabOf('b'), matching: find.byIcon(icon));
      expect(inB(Symbols.fiber_manual_record), findsOneWidget);

      // Over the label, not the dot: `tabs.css` swaps the glyph on
      // `.tab.dirty:hover`.
      await hover(tester, find.text('Tab b'));
      expect(inB(Symbols.close_rounded), findsOneWidget);
      expect(inB(Symbols.fiber_manual_record), findsNothing);
    });

    testWidgets('turning Modern UI off returns the base strip', (tester) async {
      await tester.pumpWidget(
        _layout(editorTabs: [_tab('a'), _tab('b')], modernUI: true),
      );
      expect(
        find.byKey(const ValueKey('editor-tab-pill-fill')),
        findsNWidgets(2),
      );
      await tester.pumpWidget(_layout(editorTabs: [_tab('a'), _tab('b')]));
      expect(find.byKey(const ValueKey('editor-tab-pill-fill')), findsNothing);
      expect(
        tester.getSize(find.byType(EditorTabStrip)).height,
        WorkbenchLayoutConstants.editorTabHeight,
      );
    });
  });

  group('Editor tab lifecycle (§spec:editor-tab-state)', () {
    /// Pumps a layout whose tab list a test replaces through the returned
    /// setter, the way a host adds and removes editors.
    Future<void Function(List<WorkbenchEditorTab>)> pumpHost(
      WidgetTester tester, {
      required List<WorkbenchEditorTab> tabs,
      ValueChanged<String>? onActiveEditorTabChanged,
      ValueChanged<List<String>>? onEditorTabOrderChanged,
      ValueChanged<String>? onEditorTabCloseRequested,
    }) async {
      var current = tabs;
      late StateSetter setOuter;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return _layout(
              editorTabs: current,
              onActiveEditorTabChanged: onActiveEditorTabChanged,
              onEditorTabOrderChanged: onEditorTabOrderChanged,
              onEditorTabCloseRequested: onEditorTabCloseRequested,
            );
          },
        ),
      );
      return (List<WorkbenchEditorTab> next) => setOuter(() => current = next);
    }

    /// The labels in the order the strip renders them, left to right.
    List<String> stripOrder(WidgetTester tester) {
      final labels = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(EditorTabStrip),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data!)
          .toList();
      labels.sort(
        (a, b) => tester
            .getTopLeft(find.text(a))
            .dx
            .compareTo(tester.getTopLeft(find.text(b)).dx),
      );
      return labels;
    }

    testWidgets('an added tab opens right of the active tab and activates', (
      tester,
    ) async {
      final orders = <List<String>>[];
      final actives = <String>[];
      final setTabs = await pumpHost(
        tester,
        tabs: [_tab('a'), _tab('b'), _tab('c')],
        onEditorTabOrderChanged: orders.add,
        onActiveEditorTabChanged: actives.add,
      );
      await tester.tap(find.text('Tab b'));
      await tester.pump();

      setTabs([_tab('a'), _tab('b'), _tab('c'), _tab('d')]);
      await tester.pump();

      expect(stripOrder(tester), ['Tab a', 'Tab b', 'Tab d', 'Tab c']);
      expect(find.text('Content d'), findsOneWidget);
      expect(orders, [
        ['a', 'b', 'd', 'c'],
      ]);
      expect(actives, ['b', 'd']);
    });

    testWidgets('the host list order no longer moves open tabs', (
      tester,
    ) async {
      final orders = <List<String>>[];
      final setTabs = await pumpHost(
        tester,
        tabs: [_tab('a'), _tab('b'), _tab('c')],
        onEditorTabOrderChanged: orders.add,
      );
      setTabs([_tab('c'), _tab('a'), _tab('b')]);
      await tester.pump();
      expect(stripOrder(tester), ['Tab a', 'Tab b', 'Tab c']);
      expect(orders, isEmpty);
    });

    testWidgets('removing the active tab activates the most recently active '
        'remaining tab', (tester) async {
      final actives = <String>[];
      final setTabs = await pumpHost(
        tester,
        tabs: [_tab('a'), _tab('b'), _tab('c')],
        onActiveEditorTabChanged: actives.add,
      );
      await tester.tap(find.text('Tab c'));
      await tester.pump();
      await tester.tap(find.text('Tab b'));
      await tester.pump();

      setTabs([_tab('a'), _tab('c')]);
      await tester.pump();
      // c was active before b, so it takes over — not the neighbour a.
      expect(find.text('Content c'), findsOneWidget);
      expect(actives, ['c', 'b', 'c']);
    });

    testWidgets('a host that edits its tab list in place is reconciled', (
      tester,
    ) async {
      final tabs = [_tab('a'), _tab('b')];
      await tester.pumpWidget(
        _layout(editorTabs: tabs, initialActiveEditorTabId: 'b'),
      );
      tabs.removeLast();
      await tester.pumpWidget(
        _layout(editorTabs: tabs, initialActiveEditorTabId: 'b'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Tab b'), findsNothing);
      expect(find.text('Content a'), findsOneWidget);
    });

    testWidgets('removing an inactive tab keeps the active tab', (
      tester,
    ) async {
      final actives = <String>[];
      final setTabs = await pumpHost(
        tester,
        tabs: [_tab('a'), _tab('b')],
        onActiveEditorTabChanged: actives.add,
      );
      setTabs([_tab('a')]);
      await tester.pump();
      expect(find.text('Content a'), findsOneWidget);
      expect(actives, isEmpty);
    });

    testWidgets('clicking a close button requests the close; the tab stays '
        'until the host removes it', (tester) async {
      final requested = <String>[];
      await pumpHost(
        tester,
        tabs: [_tab('a'), _tab('b')],
        onEditorTabCloseRequested: requested.add,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('editor-tab-a')),
          matching: find.byIcon(Symbols.close_rounded),
        ),
      );
      await tester.pump();
      expect(requested, ['a']);
      expect(find.text('Tab a'), findsOneWidget);
      // Closing is not activating.
      expect(find.text('Content a'), findsOneWidget);
    });

    Finder closeButtonOf(String id) => find.descendant(
      of: find.byKey(ValueKey('editor-tab-$id')),
      matching: find.byKey(const ValueKey('editor-tab-actions')),
    );

    double actionsOpacity(WidgetTester tester, String id) =>
        tester.widget<Opacity>(closeButtonOf(id)).opacity;

    testWidgets('the close button shows on the active tab and on hover', (
      tester,
    ) async {
      await pumpHost(
        tester,
        tabs: [_tab('a'), _tab('b')],
        onEditorTabCloseRequested: (_) {},
      );
      expect(actionsOpacity(tester, 'a'), 1);
      expect(actionsOpacity(tester, 'b'), 0);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(find.text('Tab b')));
      await tester.pump();
      expect(actionsOpacity(tester, 'b'), 1);

      await pointer.moveTo(tester.getCenter(find.text('Content a')));
      await tester.pump();
      expect(actionsOpacity(tester, 'b'), 0);
    });

    testWidgets('a dirty tab shows a dot until the pointer is over it', (
      tester,
    ) async {
      await pumpHost(
        tester,
        tabs: [_tab('a'), _tab('b', isDirty: true)],
        onEditorTabCloseRequested: (_) {},
      );
      Finder inB(IconData icon) => find.descendant(
        of: find.byKey(const ValueKey('editor-tab-b')),
        matching: find.byIcon(icon),
      );
      // Shown although the tab is inactive and not hovered.
      expect(actionsOpacity(tester, 'b'), 1);
      expect(inB(Symbols.fiber_manual_record), findsOneWidget);
      expect(inB(Symbols.close_rounded), findsNothing);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(closeButtonOf('b')));
      await tester.pump();
      expect(inB(Symbols.close_rounded), findsOneWidget);
      expect(inB(Symbols.fiber_manual_record), findsNothing);
    });

    testWidgets('without a close handler no tab shows a close button', (
      tester,
    ) async {
      await pumpHost(tester, tabs: [_tab('a'), _tab('b', isDirty: true)]);
      expect(find.byIcon(Symbols.close_rounded), findsNothing);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(closeButtonOf('b')));
      await tester.pump();
      expect(find.byIcon(Symbols.close_rounded), findsNothing);
      // The unsaved dot is state, not an affordance, so it stays.
      expect(find.byIcon(Symbols.fiber_manual_record), findsOneWidget);
      // A clean tab reserves no action column.
      expect(closeButtonOf('a'), findsNothing);
    });

    testWidgets('the close button is announced as a button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHost(
        tester,
        tabs: [_tab('a')],
        onEditorTabCloseRequested: (_) {},
      );
      expect(
        tester.getSemantics(
          find.descendant(
            of: closeButtonOf('a'),
            matching: find.byType(GestureDetector),
          ),
        ),
        matchesSemantics(label: 'Close', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });
  });

  group('Editor tab drag reorder (§spec:editor-tab-interaction)', () {
    Finder tabOf(String id) => find.byKey(ValueKey('editor-tab-$id'));
    final indicator = find.byKey(const ValueKey('editor-tab-drop-indicator'));

    /// Pumps a host that keeps its tab list and records what the shell
    /// reports.
    Future<void> pumpHost(
      WidgetTester tester, {
      List<List<String>>? orders,
      List<String>? actives,
      bool modernUI = false,
    }) {
      return tester.pumpWidget(
        _layout(
          editorTabs: [_tab('a'), _tab('b'), _tab('c')],
          onEditorTabOrderChanged: orders?.add,
          onActiveEditorTabChanged: actives?.add,
          modernUI: modernUI,
        ),
      );
    }

    /// Starts dragging the tab with [id] and moves the pointer to [to].
    Future<TestGesture> dragTo(
      WidgetTester tester,
      String id,
      Offset to,
    ) async {
      final gesture = await tester.startGesture(
        tester.getCenter(tabOf(id)),
        kind: PointerDeviceKind.mouse,
      );
      // Past the drag slop, then onto the target.
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(to);
      await tester.pump();
      return gesture;
    }

    /// A point over [id] at [fraction] of its width from its leading edge.
    Offset over(WidgetTester tester, String id, double fraction) {
      final rect = tester.getRect(tabOf(id));
      return Offset(rect.left + rect.width * fraction, rect.center.dy);
    }

    /// The labels in the order the strip renders them, left to right.
    List<String> stripOrder(WidgetTester tester) {
      final ids = ['a', 'b', 'c'];
      ids.sort(
        (x, y) => tester
            .getTopLeft(tabOf(x))
            .dx
            .compareTo(tester.getTopLeft(tabOf(y)).dx),
      );
      return ids;
    }

    testWidgets('dropping on the trailing half of a tab moves the dragged tab '
        'after it and reports the full order', (tester) async {
      final orders = <List<String>>[];
      await pumpHost(tester, orders: orders);

      final gesture = await dragTo(tester, 'a', over(tester, 'b', 0.75));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(stripOrder(tester), ['b', 'a', 'c']);
      expect(orders, [
        ['b', 'a', 'c'],
      ]);
    });

    testWidgets('the 2px drop bar tracks which half of the tab the pointer is '
        'over', (tester) async {
      await pumpHost(tester);
      final gesture = await dragTo(tester, 'a', over(tester, 'b', 0.25));

      // Leading half of b: the bar sits on b's leading edge.
      expect(indicator, findsOneWidget);
      final bar = tester.getRect(indicator);
      expect(bar.left, tester.getRect(tabOf('b')).left);
      expect(bar.width, WorkbenchLayoutConstants.editorTabDropIndicatorWidth);
      expect(bar.height, tester.getRect(tabOf('b')).height);
      expect(
        tester.widget<ColoredBox>(indicator).color,
        testWorkbenchTheme.tabDragAndDropBorder,
      );

      // Trailing half of b: the bar moves to c's leading edge.
      await gesture.moveTo(over(tester, 'b', 0.75));
      await tester.pump();
      expect(indicator, findsOneWidget);
      expect(tester.getRect(indicator).left, tester.getRect(tabOf('c')).left);

      // Trailing half of the last tab: the bar sits just past its edge.
      await gesture.moveTo(over(tester, 'c', 0.75));
      await tester.pump();
      expect(tester.getRect(indicator).left, tester.getRect(tabOf('c')).right);

      // Past every tab, on the empty strip: after the last tab too.
      final strip = tester.getRect(find.byType(EditorTabStrip));
      await gesture.moveTo(
        Offset(tester.getRect(tabOf('c')).right + 40, strip.center.dy),
      );
      await tester.pump();
      expect(tester.getRect(indicator).left, tester.getRect(tabOf('c')).right);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(indicator, findsNothing);
    });

    testWidgets('dropping a tab where it already stands reports nothing', (
      tester,
    ) async {
      final orders = <List<String>>[];
      await pumpHost(tester, orders: orders);

      // The leading half of b is the slot a already occupies.
      final gesture = await dragTo(tester, 'a', over(tester, 'b', 0.25));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(stripOrder(tester), ['a', 'b', 'c']);
      expect(orders, isEmpty);
    });

    testWidgets('a drag released off the strip changes nothing', (
      tester,
    ) async {
      final orders = <List<String>>[];
      await pumpHost(tester, orders: orders);

      final gesture = await dragTo(
        tester,
        'a',
        tester.getCenter(find.text('Content a')),
      );
      expect(indicator, findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(stripOrder(tester), ['a', 'b', 'c']);
      expect(orders, isEmpty);
    });

    testWidgets('dragging a tab activates it, as pressing it does upstream', (
      tester,
    ) async {
      final actives = <String>[];
      await pumpHost(tester, actives: actives);

      final gesture = await dragTo(tester, 'c', over(tester, 'a', 0.25));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(actives, ['c']);
      expect(find.text('Content c'), findsOneWidget);
      expect(stripOrder(tester), ['c', 'a', 'b']);
    });

    testWidgets('under Modern UI the bar spans the 24px tab row', (
      tester,
    ) async {
      await pumpHost(tester, modernUI: true);
      final gesture = await dragTo(tester, 'a', over(tester, 'c', 0.25));
      final tab = tester.getRect(tabOf('c'));
      final bar = tester.getRect(indicator);
      expect(
        bar.top,
        tab.top + WorkbenchLayoutConstants.modernEditorTabRowInset,
      );
      expect(bar.height, WorkbenchLayoutConstants.modernEditorTabHeight);
      expect(bar.left, tab.left);

      // Past the last tab the bar keeps the row's span, just past its edge.
      await gesture.moveTo(over(tester, 'c', 0.75));
      await tester.pump();
      final end = tester.getRect(indicator);
      expect(end.left, tab.right);
      expect(end.width, WorkbenchLayoutConstants.editorTabDropIndicatorWidth);
      expect(
        end.top,
        tab.top + WorkbenchLayoutConstants.modernEditorTabRowInset,
      );
      expect(end.height, WorkbenchLayoutConstants.modernEditorTabHeight);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('moving the drop bar keeps every tab mounted', (tester) async {
      await pumpHost(tester);
      final gesture = await dragTo(tester, 'a', over(tester, 'b', 0.25));
      // Scoped to the strip's tab: the drag image carries a label of its own.
      Element label(String id) => tester.element(
        find.descendant(of: tabOf(id), matching: find.text('Tab $id')),
      );
      final labels = [
        for (final id in ['a', 'b', 'c']) label(id),
      ];
      for (final (id, fraction) in [('b', 0.75), ('c', 0.75), ('a', 0.25)]) {
        await gesture.moveTo(over(tester, id, fraction));
        await tester.pump();
        expect(indicator, findsOneWidget);
        // A slot change leaves each tab's subtree in place.
        expect([
          for (final id in ['a', 'b', 'c']) label(id),
        ], labels);
      }
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('Editor tab overflow (§spec:editor-tab-overflow)', () {
    Finder tabOf(String id) => find.byKey(ValueKey('editor-tab-$id'));
    final viewport = find.byKey(const ValueKey('editor-tab-viewport'));
    final scrollbar = find.byKey(const ValueKey('editor-tab-scrollbar'));
    final slider = find.byKey(const ValueKey('editor-tab-scrollbar-slider'));

    /// Ids for [count] tabs, enough at 12 to overflow the test window's
    /// editor area in either treatment.
    List<String> ids([int count = 12]) => [
      for (var i = 0; i < count; i++) '$i',
    ];

    /// Pumps a host that removes a tab when its close is requested.
    Future<void> pumpHost(
      WidgetTester tester, {
      List<String>? tabIds,
      bool modernUI = false,
      String? initialActiveEditorTabId,
      List<List<String>>? orders,
      WorkbenchTheme? theme,
    }) async {
      final open = [...(tabIds ?? ids())];
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => _layout(
            editorTabs: [for (final id in open) _tab(id)],
            modernUI: modernUI,
            initialActiveEditorTabId: initialActiveEditorTabId,
            onEditorTabOrderChanged: orders?.add,
            onEditorTabCloseRequested: (id) => setState(() => open.remove(id)),
            theme: theme,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    ScrollPosition position(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(of: viewport, matching: find.byType(Scrollable)),
        )
        .position;

    double scrollbarOpacity(WidgetTester tester) =>
        tester.widget<AnimatedOpacity>(scrollbar).opacity;

    Future<void> wheel(WidgetTester tester, Offset delta) async {
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(viewport),
          scrollDelta: delta,
        ),
      );
      await tester.pump();
    }

    testWidgets('a vertical wheel scrolls an overflowing strip sideways, and a '
        'horizontal one scrolls it directly', (tester) async {
      await pumpHost(tester);
      final start = tester.getTopLeft(tabOf('0')).dx;
      expect(position(tester).maxScrollExtent, greaterThan(0));

      await wheel(tester, const Offset(0, 100));
      expect(position(tester).pixels, 100);
      expect(tester.getTopLeft(tabOf('0')).dx, start - 100);

      await wheel(tester, const Offset(-40, 0));
      expect(position(tester).pixels, 60);

      // The predominant axis wins, as upstream's `scrollPredominantAxis`.
      await wheel(tester, const Offset(10, -30));
      expect(position(tester).pixels, 30);

      // Clamped at either end.
      await wheel(tester, const Offset(0, -500));
      expect(position(tester).pixels, 0);
    });

    testWidgets('a vertical trackpad gesture scrolls the strip sideways', (
      tester,
    ) async {
      await pumpHost(tester);
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.trackpad,
      );
      final center = tester.getCenter(viewport);
      await gesture.panZoomStart(center);
      await gesture.panZoomUpdate(center, pan: const Offset(0, -60));
      await tester.pump();
      await gesture.panZoomEnd();
      await tester.pump();
      expect(position(tester).pixels, 60);
    });

    testWidgets('a strip that fits ignores the wheel and shows no scrollbar', (
      tester,
    ) async {
      await pumpHost(tester, tabIds: ids(2));
      expect(position(tester).maxScrollExtent, 0);
      await wheel(tester, const Offset(0, 100));
      expect(position(tester).pixels, 0);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: tester.getCenter(viewport));
      addTearDown(pointer.removePointer);
      await tester.pumpAndSettle();
      expect(scrollbarOpacity(tester), 0);
    });

    testWidgets('the scrollbar overlays the strip foot and shows only while '
        'the pointer is over an overflowing strip', (tester) async {
      await pumpHost(tester);
      final strip = tester.getRect(viewport);
      final bar = tester.getRect(scrollbar);
      // A 3px bar over the bottom of the strip, taking no layout space.
      expect(bar.height, WorkbenchLayoutConstants.editorTabScrollbarSize);
      expect(bar.bottom, strip.bottom);
      expect(bar.width, strip.width);
      expect(
        tester.getSize(find.byType(EditorTabStrip)).height,
        WorkbenchLayoutConstants.editorTabHeight,
      );
      expect(scrollbarOpacity(tester), 0);

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(tabOf('1')));
      await tester.pump();
      expect(scrollbarOpacity(tester), 1);
      expect(
        tester.widget<AnimatedOpacity>(scrollbar).duration,
        WorkbenchLayoutConstants.editorTabScrollbarFadeInDuration,
      );
      // Still shown while the pointer stays, however long.
      await tester.pump(const Duration(seconds: 2));
      expect(scrollbarOpacity(tester), 1);

      await pointer.moveTo(tester.getCenter(find.text('Content 0')));
      await tester.pump();
      expect(scrollbarOpacity(tester), 0);
      expect(
        tester.widget<AnimatedOpacity>(scrollbar).duration,
        WorkbenchLayoutConstants.editorTabScrollbarFadeOutDuration,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('scrolling shows the scrollbar, which fades once scrolling '
        'has stopped for the hide delay', (tester) async {
      await pumpHost(tester);
      // A scroll the pointer does not drive: activating a cut-off tab.
      Actions.invoke(
        tester.element(find.text('Content 0')),
        const ActivateLastEditorTabIntent(),
      );
      await tester.pump();
      await tester.pump();
      expect(position(tester).pixels, greaterThan(0));
      expect(scrollbarOpacity(tester), 1);

      const delay = WorkbenchLayoutConstants.editorTabScrollbarHideDelay;
      await tester.pump(delay - const Duration(milliseconds: 1));
      expect(scrollbarOpacity(tester), 1);
      await tester.pump(const Duration(milliseconds: 2));
      expect(scrollbarOpacity(tester), 0);
      await tester.pumpAndSettle();
    });

    testWidgets('the slider is sized and placed from the scroll extent', (
      tester,
    ) async {
      await pumpHost(tester);
      await wheel(tester, const Offset(0, 150));
      final metrics = position(tester);
      final visible = metrics.viewportDimension;
      final scrollSize = metrics.maxScrollExtent + visible;
      // scrollbarState.ts: the slider takes the visible share of the track,
      // never less than 20px, and moves in proportion to the scroll.
      final size = (visible * visible / scrollSize).floorToDouble().clamp(
        WorkbenchLayoutConstants.editorTabScrollbarMinSliderSize,
        visible,
      );
      final ratio = (visible - size) / (scrollSize - visible);
      final rect = tester.getRect(slider);
      final bar = tester.getRect(scrollbar);
      expect(rect.width, size.roundToDouble());
      expect(rect.left - bar.left, (metrics.pixels * ratio).roundToDouble());
      expect(rect.height, WorkbenchLayoutConstants.editorTabScrollbarSize);
    });

    testWidgets('the slider paints scrollbarSlider.*, and dragging it scrolls '
        'the strip', (tester) async {
      await pumpHost(tester);
      Color? sliderColor() =>
          (tester.widget<DecoratedBox>(slider).decoration as BoxDecoration)
              .color;
      final theme = testWorkbenchTheme;

      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: Offset.zero);
      addTearDown(pointer.removePointer);
      await pointer.moveTo(tester.getCenter(tabOf('1')));
      await tester.pump();
      expect(sliderColor(), theme.scrollbarSliderBackground);

      await pointer.moveTo(tester.getCenter(slider));
      await tester.pump();
      expect(sliderColor(), theme.scrollbarSliderHoverBackground);

      await pointer.down(tester.getCenter(slider));
      await tester.pump();
      expect(sliderColor(), theme.scrollbarSliderActiveBackground);
      await pointer.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(position(tester).pixels, greaterThan(40));
      await pointer.up();
      await tester.pump();
      expect(sliderColor(), theme.scrollbarSliderHoverBackground);
    });

    testWidgets('under Modern UI the slider rounds to the controls tier', (
      tester,
    ) async {
      await pumpHost(tester, modernUI: true);
      expect(
        (tester.widget<DecoratedBox>(slider).decoration as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(WorkbenchLayoutConstants.cornerRadiusSmall),
      );
    });

    testWidgets('activating a tab cut off at the trailing edge scrolls until '
        'its trailing edge meets the strip', (tester) async {
      await pumpHost(tester);
      Actions.invoke(
        tester.element(find.text('Content 0')),
        const ActivateEditorTabAtIndexIntent(6),
      );
      await tester.pumpAndSettle();
      final strip = tester.getRect(viewport);
      expect(tester.getRect(tabOf('6')).right, closeTo(strip.right, 0.01));
    });

    testWidgets('activating a tab cut off at the leading edge scrolls until '
        'its leading edge meets the strip', (tester) async {
      await pumpHost(tester, initialActiveEditorTabId: '11');
      expect(position(tester).pixels, position(tester).maxScrollExtent);
      Actions.invoke(
        tester.element(find.text('Content 11')),
        const ActivateEditorTabAtIndexIntent(4),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(tabOf('4')).left,
        closeTo(tester.getRect(viewport).left, 0.01),
      );
    });

    testWidgets('a tab wider than the strip aligns its leading edge', (
      tester,
    ) async {
      final wide = WorkbenchEditorTab(
        id: 'wide',
        label: List.filled(40, 'wide').join(' '),
        contentBuilder: (_) => const Text('Content wide'),
      );
      await tester.pumpWidget(_layout(editorTabs: [_tab('a'), wide]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tab a'));
      await tester.pumpAndSettle();
      Actions.invoke(
        tester.element(find.text('Content a')),
        const ActivateLastEditorTabIntent(),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(tabOf('wide')).left,
        closeTo(tester.getRect(viewport).left, 0.01),
      );
    });

    testWidgets('closing a tab through its button leaves the strip where it '
        'is', (tester) async {
      // Under Modern UI every tab shows its close button.
      await pumpHost(tester, tabIds: ids(20), modernUI: true);
      await wheel(tester, const Offset(0, 300));
      expect(position(tester).pixels, 300);
      // The active tab, 0, is now out of view to the leading side.
      expect(
        tester.getRect(tabOf('0')).right,
        lessThan(tester.getRect(viewport).left),
      );

      final visible = ids(20).firstWhere(
        (id) => tester.getRect(tabOf(id)).left > tester.getRect(viewport).left,
      );
      await tester.tap(
        find.descendant(
          of: tabOf(visible),
          matching: find.byKey(const ValueKey('editor-tab-actions')),
        ),
      );
      await tester.pumpAndSettle();
      expect(tabOf(visible), findsNothing);
      expect(position(tester).pixels, 300);
    });

    testWidgets('dragging a tab near an end scrolls the strip, and the tab '
        'drops at a slot that started out of view', (tester) async {
      final orders = <List<String>>[];
      await pumpHost(tester, orders: orders);
      final strip = tester.getRect(viewport);
      // The last tab starts out of view.
      expect(tester.getRect(tabOf('11')).left, greaterThan(strip.right));

      final gesture = await tester.startGesture(
        tester.getCenter(tabOf('0')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(
        Offset(
          strip.right - WorkbenchLayoutConstants.editorTabDragScrollEdge / 2,
          strip.center.dy,
        ),
      );
      await tester.pump();
      // Hold the pointer still in the edge zone until the strip reaches its
      // end.
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(position(tester).pixels, position(tester).maxScrollExtent);
      expect(
        tester.getRect(find.byKey(const ValueKey('editor-tab-drop-indicator'))),
        isNotNull,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(orders.single.last, '0');

      // Near the leading edge the strip scrolls back.
      final back = await tester.startGesture(
        tester.getCenter(tabOf('0')),
        kind: PointerDeviceKind.mouse,
      );
      await back.moveBy(const Offset(-20, 0));
      await tester.pump();
      await back.moveTo(
        Offset(
          strip.left + WorkbenchLayoutConstants.editorTabDragScrollEdge / 2,
          strip.center.dy,
        ),
      );
      await tester.pump();
      final before = position(tester).pixels;
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(position(tester).pixels, lessThan(before));
      await back.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a drag in the middle of the strip does not scroll it', (
      tester,
    ) async {
      await pumpHost(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(tabOf('0')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(viewport));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(position(tester).pixels, 0);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('Editor tab keyboard (§spec:editor-tab-interaction)', () {
    /// Presses [key] with the named modifiers held.
    Future<void> press(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool meta = false,
      bool control = false,
      bool alt = false,
      bool shift = false,
    }) async {
      final modifiers = [
        if (meta) LogicalKeyboardKey.metaLeft,
        if (control) LogicalKeyboardKey.controlLeft,
        if (alt) LogicalKeyboardKey.altLeft,
        if (shift) LogicalKeyboardKey.shiftLeft,
      ];
      for (final modifier in modifiers) {
        await tester.sendKeyDownEvent(modifier);
      }
      await tester.sendKeyEvent(key);
      for (final modifier in modifiers.reversed) {
        await tester.sendKeyUpEvent(modifier);
      }
      await tester.pump();
    }

    /// The id of the tab whose content shows.
    String shown() {
      for (final id in const ['a', 'b', 'c']) {
        if (find.text('Content $id').evaluate().isNotEmpty) return id;
      }
      return '';
    }

    /// A host the way the example builds one: [WorkbenchShortcuts] above the
    /// layout, holding focus through its own autofocus.
    Widget host({
      List<WorkbenchEditorTab>? tabs,
      ValueChanged<String>? onEditorTabCloseRequested,
      Map<ShortcutActivator, Intent>? extraShortcuts,
      Map<Type, Action<Intent>>? actions,
    }) {
      return Actions(
        actions: actions ?? const {},
        child: WorkbenchShortcuts(
          extraShortcuts: extraShortcuts,
          child: _layout(
            editorTabs: tabs ?? [_tab('a'), _tab('b'), _tab('c')],
            onEditorTabCloseRequested: onEditorTabCloseRequested,
          ),
        ),
      );
    }

    testWidgets('macOS binds next, previous, index, last and close', (
      tester,
    ) async {
      final closed = <String>[];
      await tester.pumpWidget(host(onEditorTabCloseRequested: closed.add));
      await tester.pump();
      expect(shown(), 'a');

      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(shown(), 'b');
      await press(
        tester,
        LogicalKeyboardKey.bracketRight,
        meta: true,
        shift: true,
      );
      expect(shown(), 'c');
      // Next wraps from the last tab to the first.
      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(shown(), 'a');
      // Previous wraps from the first tab to the last.
      await press(tester, LogicalKeyboardKey.arrowLeft, meta: true, alt: true);
      expect(shown(), 'c');
      await press(
        tester,
        LogicalKeyboardKey.bracketLeft,
        meta: true,
        shift: true,
      );
      expect(shown(), 'b');

      await press(tester, LogicalKeyboardKey.digit1, control: true);
      expect(shown(), 'a');
      await press(tester, LogicalKeyboardKey.digit0, control: true);
      expect(shown(), 'c');
      await press(tester, LogicalKeyboardKey.digit2, control: true);
      expect(shown(), 'b');
      // An index past the last tab does nothing.
      await press(tester, LogicalKeyboardKey.digit9, control: true);
      expect(shown(), 'b');

      await press(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(closed, ['b']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('Windows binds Ctrl+PageDown/PageUp, Alt+digits, Ctrl+W and '
        'Ctrl+F4', (tester) async {
      final closed = <String>[];
      await tester.pumpWidget(host(onEditorTabCloseRequested: closed.add));
      await tester.pump();

      await press(tester, LogicalKeyboardKey.pageDown, control: true);
      expect(shown(), 'b');
      await press(tester, LogicalKeyboardKey.pageUp, control: true);
      expect(shown(), 'a');
      await press(tester, LogicalKeyboardKey.digit3, alt: true);
      expect(shown(), 'c');
      await press(tester, LogicalKeyboardKey.digit0, alt: true);
      expect(shown(), 'c');
      await press(tester, LogicalKeyboardKey.digit1, alt: true);
      expect(shown(), 'a');

      await press(tester, LogicalKeyboardKey.keyW, control: true);
      await press(tester, LogicalKeyboardKey.f4, control: true);
      expect(closed, ['a', 'a']);

      // The macOS chords are not bound here.
      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(shown(), 'a');
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

    testWidgets('Linux binds the Windows set without Ctrl+F4', (tester) async {
      final closed = <String>[];
      await tester.pumpWidget(host(onEditorTabCloseRequested: closed.add));
      await tester.pump();

      await press(tester, LogicalKeyboardKey.pageDown, control: true);
      expect(shown(), 'b');
      await press(tester, LogicalKeyboardKey.f4, control: true);
      expect(closed, isEmpty);
      await press(tester, LogicalKeyboardKey.keyW, control: true);
      expect(closed, ['b']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    testWidgets('without a close handler the close chord closes nothing and '
        'reaches the host', (tester) async {
      var hostHandled = 0;
      await tester.pumpWidget(
        host(
          extraShortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyW, meta: true):
                _HostCloseIntent(),
          },
          actions: {
            _HostCloseIntent: CallbackAction<_HostCloseIntent>(
              onInvoke: (_) => hostHandled++,
            ),
          },
        ),
      );
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyW, meta: true);
      expect(hostHandled, 1);
      expect(shown(), 'a');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a layout without tabs binds nothing', (tester) async {
      var hostHandled = 0;
      await tester.pumpWidget(
        host(
          tabs: const [],
          extraShortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyW, meta: true):
                _HostCloseIntent(),
          },
          actions: {
            _HostCloseIntent: CallbackAction<_HostCloseIntent>(
              onInvoke: (_) => hostHandled++,
            ),
          },
        ),
      );
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyW, meta: true);
      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(hostHandled, 1);
      expect(find.text('Empty editor'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('with focus inside a layout without tabs, the chords reach '
        'the host', (tester) async {
      var hostHandled = 0;
      final editorNode = FocusNode();
      addTearDown(editorNode.dispose);
      await tester.pumpWidget(
        Actions(
          actions: {
            _HostCloseIntent: CallbackAction<_HostCloseIntent>(
              onInvoke: (_) => hostHandled++,
            ),
          },
          child: WorkbenchShortcuts(
            extraShortcuts: const {
              SingleActivator(LogicalKeyboardKey.keyW, meta: true):
                  _HostCloseIntent(),
              SingleActivator(
                LogicalKeyboardKey.arrowRight,
                meta: true,
                alt: true,
              ): _HostCloseIntent(),
            },
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                extensions: [testWorkbenchTheme],
              ),
              home: WorkbenchLayout(
                activityBarItems: const [],
                editor: Focus(
                  focusNode: editorNode,
                  child: const Text('Empty editor'),
                ),
                containerBuilder: _emptySpec,
                bottomPanel: const SizedBox.shrink(),
                showBottomPanel: false,
                statusBar: const SizedBox(height: 22),
              ),
            ),
          ),
        ),
      );
      editorNode.requestFocus();
      await tester.pump();
      expect(editorNode.hasPrimaryFocus, isTrue);
      await press(tester, LogicalKeyboardKey.keyW, meta: true);
      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(hostHandled, 2);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('the host bindings above the layout still fire', (
      tester,
    ) async {
      var toggled = 0;
      await tester.pumpWidget(
        host(
          actions: {
            ToggleBottomPanelIntent: CallbackAction<ToggleBottomPanelIntent>(
              onInvoke: (_) => toggled++,
            ),
          },
        ),
      );
      await tester.pump();
      await press(tester, LogicalKeyboardKey.keyJ, meta: true);
      expect(toggled, 1);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a hidden tab gives up focus, and the bindings keep working', (
      tester,
    ) async {
      final contentNode = FocusNode();
      addTearDown(contentNode.dispose);
      await tester.pumpWidget(
        host(
          tabs: [
            _tab(
              'a',
              contentBuilder: (_) =>
                  Focus(focusNode: contentNode, child: const Text('Content a')),
            ),
            _tab('b'),
          ],
        ),
      );
      await tester.pump();
      contentNode.requestFocus();
      await tester.pump();
      expect(contentNode.hasPrimaryFocus, isTrue);

      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(shown(), 'b');
      expect(contentNode.hasFocus, isFalse);
      // Focus did not strand in the hidden editor, so the next chord lands.
      await press(tester, LogicalKeyboardKey.arrowLeft, meta: true, alt: true);
      expect(shown(), 'a');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a host that clears focus keeps it cleared until a tab is '
        'clicked', (tester) async {
      await tester.pumpWidget(host());
      await tester.pump();
      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(shown(), 'b');

      final scope = FocusManager.instance.primaryFocus!.enclosingScope!;
      FocusManager.instance.primaryFocus!.unfocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, scope);

      await tester.tap(find.text('Tab a'));
      await tester.pump();
      await press(tester, LogicalKeyboardKey.arrowRight, meta: true, alt: true);
      expect(shown(), 'b');
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('content inside a tab dispatches the published intents', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pump();
      Actions.invoke(
        tester.element(find.text('Content a')),
        const ActivateLastEditorTabIntent(),
      );
      await tester.pump();
      expect(shown(), 'c');
    });
  });
}

/// A host's own command bound to the same chord as the shell's close.
class _HostCloseIntent extends Intent {
  const _HostCloseIntent();
}

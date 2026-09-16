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
              contentBuilder: (_) => Focus(
                focusNode: contentNode,
                child: const Text('Content a'),
              ),
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

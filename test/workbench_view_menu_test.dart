import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  // Force the non-macOS in-window path so widget tests exercise the
  // Material MenuBar instead of PlatformMenuBar (which attaches to the
  // host OS menu bar and has no visible widgets to interact with).
  group('WorkbenchMenuBar (in-window)', () {
    testWidgets('opens View menu and lists static tab labels', (tester) async {
      const tabs = [
        WorkbenchViewMenuTab(id: 'tasks', label: 'Tasks'),
        WorkbenchViewMenuTab(id: 'mdi', label: 'MDI'),
      ];
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchMenuBar(
            useNativeMenuBar: false,
            onToggleBottomPanel: () {},
            tabs: tabs,
            onSelectTab: (_) {},
            child: const SizedBox(width: 400, height: 200),
          ),
        ),
      );

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Bottom Panel'), findsNothing);
      expect(find.text('Show Bottom Panel'), findsNothing);
      expect(find.text('Panel'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('MDI'), findsOneWidget);
    });

    testWidgets('Panel menu item invokes onToggleBottomPanel', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchMenuBar(
            useNativeMenuBar: false,
            onToggleBottomPanel: () => toggled++,
            tabs: const [],
            onSelectTab: (_) {},
            child: const SizedBox(width: 400, height: 200),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panel'));
      await tester.pumpAndSettle();
      expect(toggled, 1);
    });

    testWidgets('renders shortcuts alongside tab labels', (tester) async {
      const tabs = [
        WorkbenchViewMenuTab(
          id: 'tasks',
          label: 'Tasks',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyM,
            meta: true,
            shift: true,
          ),
        ),
        WorkbenchViewMenuTab(
          id: 'machine_state',
          label: 'Machine State',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyY,
            meta: true,
            shift: true,
          ),
        ),
        WorkbenchViewMenuTab(
          id: 'mdi',
          label: 'MDI',
          shortcut: SingleActivator(
            LogicalKeyboardKey.backquote,
            control: true,
          ),
        ),
        WorkbenchViewMenuTab(
          id: 'output',
          label: 'Output',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyU,
            meta: true,
            shift: true,
          ),
        ),
      ];
      final selected = <String>[];
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchMenuBar(
            useNativeMenuBar: false,
            onToggleBottomPanel: () {},
            tabs: tabs,
            onSelectTab: selected.add,
            child: const SizedBox(width: 400, height: 200),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      for (final tab in tabs) {
        final item = tester.widget<MenuItemButton>(
          find.widgetWithText(MenuItemButton, tab.label),
        );
        expect(item.shortcut, tab.shortcut);
      }

      // Menu is still open from the inspection above. Tap each tab
      // to verify onSelectTab fires, re-opening the View menu between
      // selections (tapping a MenuItemButton closes the submenu).
      for (var i = 0; i < tabs.length; i++) {
        if (i > 0) {
          await tester.tap(find.text('View'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(tabs[i].label));
        await tester.pumpAndSettle();
      }
      expect(selected, ['tasks', 'machine_state', 'mdi', 'output']);
    });

    testWidgets('selecting a tab passes its id to onSelectTab', (tester) async {
      String? selectedId;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchMenuBar(
            useNativeMenuBar: false,
            onToggleBottomPanel: () {},
            tabs: const [WorkbenchViewMenuTab(id: 'mdi', label: 'MDI')],
            onSelectTab: (id) => selectedId = id,
            child: const SizedBox(width: 400, height: 200),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MDI'));
      await tester.pumpAndSettle();
      expect(selectedId, 'mdi');
    });
  });

  group('WorkbenchShortcuts', () {
    testWidgets('Ctrl+backquote invokes onFocusMdi', (tester) async {
      var focused = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchShortcuts(
            onFocusMdi: () => focused++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(focused, greaterThanOrEqualTo(1));
    });

    testWidgets('Cmd+backquote does not invoke onFocusMdi', (tester) async {
      var focused = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchShortcuts(
            onFocusMdi: () => focused++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.backquote);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(focused, 0);
    });

    testWidgets('Shift+Cmd+M invokes onFocusTasks', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchShortcuts(
            onFocusTasks: () => n++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(n, greaterThanOrEqualTo(1));
    });

    testWidgets('Shift+Cmd+Y invokes onFocusMachineState', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchShortcuts(
            onFocusMachineState: () => n++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(n, greaterThanOrEqualTo(1));
    });

    testWidgets('Shift+Cmd+U invokes onFocusOutput', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchShortcuts(
            onFocusOutput: () => n++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyU);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(n, greaterThanOrEqualTo(1));
    });

    testWidgets('Cmd+J invokes onToggleBottomPanel', (tester) async {
      var toggled = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchShortcuts(
            onToggleBottomPanel: () => toggled++,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(toggled, greaterThanOrEqualTo(1));
    });
  });
}

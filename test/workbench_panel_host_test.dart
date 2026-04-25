import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

class _FocusFooIntent extends Intent {
  const _FocusFooIntent(this.id);
  final String id;
}

WorkbenchPanel _panel(
  String id,
  String label, {
  PanelTabBadge? badge,
  ShortcutActivator? shortcut,
  Intent? focusIntent,
}) {
  return WorkbenchPanel(
    id: id,
    label: label,
    badge: badge,
    shortcut: shortcut as MenuSerializableShortcut?,
    focusIntent: focusIntent,
    contentBuilder: (_, lifecycle) => _CountingContent(lifecycle: lifecycle),
  );
}

/// Test panel content that exposes the supplied [PanelLifecycle] to
/// the test harness via a [ValueKey] so tests can inspect transitions.
class _CountingContent extends StatefulWidget {
  const _CountingContent({required this.lifecycle});
  final PanelLifecycle lifecycle;

  @override
  State<_CountingContent> createState() => _CountingContentState();
}

class _CountingContentState extends State<_CountingContent> {
  int _focusedTransitions = 0;

  @override
  void initState() {
    super.initState();
    widget.lifecycle.isFocused.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.lifecycle.isFocused.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.lifecycle.isFocused.value) _focusedTransitions++;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      'focused=${widget.lifecycle.isFocused.value} transitions=$_focusedTransitions',
    );
  }
}

void main() {
  group('WorkbenchPanelHost', () {
    Widget wrap({
      required List<WorkbenchPanel> panels,
      required bool panelVisible,
      required VoidCallback onTogglePanel,
      Map<Type, Action<Intent>>? actions,
      Object? initialActiveId,
      WorkbenchPanelScopeBuilder? builder,
    }) {
      return wrapWithTheme(
        SizedBox(
          width: 800,
          height: 400,
          child: Actions(
            actions: actions ?? const <Type, Action<Intent>>{},
            child: WorkbenchPanelHost(
              panels: panels,
              panelVisible: panelVisible,
              initialActiveId: initialActiveId,
              onTogglePanel: onTogglePanel,
              builder:
                  builder ??
                  (ctx, scope) => Shortcuts(
                    shortcuts: scope.shortcuts,
                    child: Focus(autofocus: true, child: scope.tabbedPanel),
                  ),
            ),
          ),
        ),
      );
    }

    testWidgets('active tab persists across panelVisible toggle', (
      tester,
    ) async {
      final panels = [
        _panel('a', 'Alpha'),
        _panel('b', 'Beta'),
        _panel('c', 'Gamma'),
      ];

      await tester.pumpWidget(
        wrap(panels: panels, panelVisible: true, onTogglePanel: () {}),
      );
      await tester.pump();
      // Move to second tab.
      await tester.tap(find.text('BETA'));
      await tester.pumpAndSettle();
      // Hide panel.
      await tester.pumpWidget(
        wrap(panels: panels, panelVisible: false, onTogglePanel: () {}),
      );
      await tester.pumpAndSettle();
      // Show again.
      await tester.pumpWidget(
        wrap(panels: panels, panelVisible: true, onTogglePanel: () {}),
      );
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabBar.controller!.index, 1, reason: 'Beta tab still focused');
    });

    testWidgets(
      'menu and tab strip both lose entries when a panel is dropped',
      (tester) async {
        final fullPanels = [
          _panel('a', 'Alpha', focusIntent: const _FocusFooIntent('a')),
          _panel('b', 'Beta', focusIntent: const _FocusFooIntent('b')),
        ];
        final reducedPanels = [fullPanels[0]];

        List<WorkbenchViewMenuTab>? capturedMenuTabs;
        Widget capture(BuildContext ctx, WorkbenchPanelScope scope) {
          capturedMenuTabs = scope.viewMenuTabs;
          return scope.tabbedPanel;
        }

        await tester.pumpWidget(
          wrap(
            panels: fullPanels,
            panelVisible: true,
            onTogglePanel: () {},
            builder: capture,
          ),
        );
        await tester.pump();
        expect(find.text('ALPHA'), findsOneWidget);
        expect(find.text('BETA'), findsOneWidget);
        expect(capturedMenuTabs!.map((t) => t.label).toList(), [
          'Alpha',
          'Beta',
        ]);

        await tester.pumpWidget(
          wrap(
            panels: reducedPanels,
            panelVisible: true,
            onTogglePanel: () {},
            builder: capture,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ALPHA'), findsOneWidget);
        expect(find.text('BETA'), findsNothing);
        expect(capturedMenuTabs!.map((t) => t.label).toList(), ['Alpha']);
      },
    );

    testWidgets('shortcut activator routes through intent dispatch', (
      tester,
    ) async {
      final invocations = <String>[];
      final panels = [
        _panel(
          'a',
          'Alpha',
          shortcut: const SingleActivator(LogicalKeyboardKey.keyA, alt: true),
          focusIntent: const _FocusFooIntent('a'),
        ),
        _panel(
          'b',
          'Beta',
          shortcut: const SingleActivator(LogicalKeyboardKey.keyB, alt: true),
          focusIntent: const _FocusFooIntent('b'),
        ),
      ];

      await tester.pumpWidget(
        wrap(
          panels: panels,
          panelVisible: true,
          onTogglePanel: () {},
          actions: <Type, Action<Intent>>{
            _FocusFooIntent: CallbackAction<_FocusFooIntent>(
              onInvoke: (intent) {
                invocations.add(intent.id);
                return null;
              },
            ),
          },
        ),
      );
      await tester.pump();

      // Send the Alt+B activator through the keyboard simulator. The
      // surrounding `Shortcuts` was wired with `scope.shortcuts`, so
      // the host's panel-derived bindings should fire the intent.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pumpAndSettle();

      expect(invocations, contains('b'));
    });

    testWidgets('lifecycle isFocused tracks active tab and panelVisible', (
      tester,
    ) async {
      // Captured by each panel's content builder when (and if)
      // TabBarView mounts that tab. We only assert on a lifecycle
      // after its panel has been mounted at least once.
      final lifecycles = <String, PanelLifecycle>{};
      WorkbenchPanel makePanel(String id, String label) => WorkbenchPanel(
        id: id,
        label: label,
        contentBuilder: (_, lifecycle) {
          lifecycles[id] = lifecycle;
          return Text('$id-${lifecycle.isFocused.value}');
        },
      );

      final panels = [makePanel('a', 'Alpha'), makePanel('b', 'Beta')];

      await tester.pumpWidget(
        wrap(panels: panels, panelVisible: true, onTogglePanel: () {}),
      );
      await tester.pumpAndSettle();
      // Alpha is the default active tab — its content has been built
      // and its lifecycle is focused.
      expect(lifecycles['a']!.isFocused.value, isTrue);

      // Switch tabs — Alpha's lifecycle goes false, Beta's content
      // builder runs for the first time and Beta is focused.
      await tester.tap(find.text('BETA'));
      await tester.pumpAndSettle();
      expect(lifecycles['a']!.isFocused.value, isFalse);
      expect(lifecycles['b']!.isFocused.value, isTrue);

      // Hide panel — Beta's lifecycle goes false.
      await tester.pumpWidget(
        wrap(panels: panels, panelVisible: false, onTogglePanel: () {}),
      );
      await tester.pumpAndSettle();
      expect(lifecycles['b']!.isFocused.value, isFalse);

      // Show again — Beta is still the active tab and its
      // lifecycle goes true again.
      await tester.pumpWidget(
        wrap(panels: panels, panelVisible: true, onTogglePanel: () {}),
      );
      await tester.pumpAndSettle();
      expect(lifecycles['b']!.isFocused.value, isTrue);
    });

    testWidgets('panel with focusIntent: null is omitted from the View menu', (
      tester,
    ) async {
      final panels = [
        _panel('a', 'Alpha', focusIntent: const _FocusFooIntent('a')),
        // No focusIntent — should not appear in the View menu.
        _panel('b', 'Beta'),
      ];

      List<WorkbenchViewMenuTab>? capturedMenuTabs;
      await tester.pumpWidget(
        wrap(
          panels: panels,
          panelVisible: true,
          onTogglePanel: () {},
          builder: (ctx, scope) {
            capturedMenuTabs = scope.viewMenuTabs;
            return scope.tabbedPanel;
          },
        ),
      );
      await tester.pump();

      // Both tabs present in the strip.
      expect(find.text('ALPHA'), findsOneWidget);
      expect(find.text('BETA'), findsOneWidget);
      // Menu only has the panel that supplied a focus intent.
      expect(capturedMenuTabs!.map((t) => t.label).toList(), ['Alpha']);
    });
  });
}

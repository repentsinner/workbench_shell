import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

/// Test-only host intent used to verify `WorkbenchViewMenuTab.intent`
/// is dispatched through `Actions.invoke`. The shell publishes only
/// `ToggleBottomPanelIntent`; every other intent is host-defined.
class _FocusTestTabIntent extends Intent {
  const _FocusTestTabIntent(this.id);
  final String id;
}

/// Wraps [child] in an [Actions] scope that records each invoked
/// intent in [invocations]. Every menu-bar test that exercises tab
/// selection uses this so assertions can check dispatch order.
Widget _actionsHarness({
  required Widget child,
  required List<Object> invocations,
}) {
  return Actions(
    actions: <Type, Action<Intent>>{
      ToggleBottomPanelIntent: CallbackAction<ToggleBottomPanelIntent>(
        onInvoke: (intent) {
          invocations.add(intent);
          return null;
        },
      ),
      _FocusTestTabIntent: CallbackAction<_FocusTestTabIntent>(
        onInvoke: (intent) {
          invocations.add(intent.id);
          return null;
        },
      ),
    },
    child: child,
  );
}

void main() {
  // Force the non-macOS in-window path so widget tests exercise the
  // Material MenuBar instead of PlatformMenuBar (which attaches to the
  // host OS menu bar and has no visible widgets to interact with).
  group('WorkbenchMenuBar (in-window)', () {
    testWidgets('opens View menu and lists static tab labels', (tester) async {
      final invocations = <Object>[];
      const tabs = [
        WorkbenchViewMenuTab(
          intent: _FocusTestTabIntent('tasks'),
          label: 'Tasks',
        ),
        WorkbenchViewMenuTab(intent: _FocusTestTabIntent('mdi'), label: 'MDI'),
      ];
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: invocations,
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: tabs,
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('MDI'), findsOneWidget);
    });

    testWidgets('command entry dispatches its intent on selection', (
      tester,
    ) async {
      final invocations = <Object>[];
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: invocations,
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: [
                WorkbenchViewMenuTab(
                  intent: ToggleBottomPanelIntent(),
                  label: 'Panel',
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Panel'));
      await tester.pumpAndSettle();
      expect(invocations, hasLength(1));
      expect(invocations.single, isA<ToggleBottomPanelIntent>());
    });

    testWidgets('renders shortcuts alongside tab labels', (tester) async {
      final invocations = <Object>[];
      const tabs = [
        WorkbenchViewMenuTab(
          intent: _FocusTestTabIntent('tasks'),
          label: 'Tasks',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyM,
            meta: true,
            shift: true,
          ),
        ),
        WorkbenchViewMenuTab(
          intent: _FocusTestTabIntent('machine_state'),
          label: 'Machine State',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyY,
            meta: true,
            shift: true,
          ),
        ),
        WorkbenchViewMenuTab(
          intent: _FocusTestTabIntent('mdi'),
          label: 'MDI',
          shortcut: SingleActivator(
            LogicalKeyboardKey.backquote,
            control: true,
          ),
        ),
        WorkbenchViewMenuTab(
          intent: _FocusTestTabIntent('output'),
          label: 'Output',
          shortcut: SingleActivator(
            LogicalKeyboardKey.keyU,
            meta: true,
            shift: true,
          ),
        ),
      ];
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: invocations,
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: tabs,
              child: SizedBox(width: 400, height: 200),
            ),
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
      // to verify the intent is dispatched, re-opening the View menu
      // between selections (tapping a MenuItemButton closes the submenu).
      for (var i = 0; i < tabs.length; i++) {
        if (i > 0) {
          await tester.tap(find.text('View'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(tabs[i].label));
        await tester.pumpAndSettle();
      }
      expect(invocations, ['tasks', 'machine_state', 'mdi', 'output']);
    });

    testWidgets('selecting a tab dispatches its intent via Actions.invoke', (
      tester,
    ) async {
      final invocations = <Object>[];
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: invocations,
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: [
                WorkbenchViewMenuTab(
                  intent: _FocusTestTabIntent('mdi'),
                  label: 'MDI',
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MDI'));
      await tester.pumpAndSettle();
      expect(invocations, ['mdi']);
    });
  });

  group('WorkbenchMenuBar entry model (in-window)', () {
    testWidgets('submenu nests its children behind a SubmenuButton', (
      tester,
    ) async {
      final invocations = <Object>[];
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: invocations,
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: [
                WorkbenchMenuSubmenu(
                  label: 'Appearance',
                  children: [
                    WorkbenchViewMenuTab(
                      intent: _FocusTestTabIntent('zen'),
                      label: 'Zen Mode',
                    ),
                  ],
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      // The child is not visible until the submenu opens.
      expect(find.text('Zen Mode'), findsNothing);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      expect(find.text('Zen Mode'), findsOneWidget);
      await tester.tap(find.text('Zen Mode'));
      await tester.pumpAndSettle();
      expect(invocations, ['zen']);
    });

    testWidgets('checkbox renders a CheckboxMenuButton tracking checked', (
      tester,
    ) async {
      final invocations = <Object>[];
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: invocations,
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: [
                WorkbenchMenuCheckbox(
                  intent: ToggleBottomPanelIntent(),
                  label: 'Panel',
                  checked: true,
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      final checkbox = tester.widget<CheckboxMenuButton>(
        find.widgetWithText(CheckboxMenuButton, 'Panel'),
      );
      expect(checkbox.value, isTrue);
      await tester.tap(find.text('Panel'));
      await tester.pumpAndSettle();
      expect(invocations.single, isA<ToggleBottomPanelIntent>());
    });

    testWidgets('radio renders a RadioMenuButton tracking selected', (
      tester,
    ) async {
      final invocations = <Object>[];
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: invocations,
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: [
                WorkbenchMenuSubmenu(
                  label: 'Align Panel',
                  children: [
                    WorkbenchMenuRadio(
                      intent: _FocusTestTabIntent('center'),
                      label: 'Center',
                      selected: true,
                    ),
                    WorkbenchMenuRadio(
                      intent: _FocusTestTabIntent('left'),
                      label: 'Left',
                      selected: false,
                    ),
                  ],
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Align Panel'));
      await tester.pumpAndSettle();
      final center = tester.widget<RadioMenuButton<bool>>(
        find.widgetWithText(RadioMenuButton<bool>, 'Center'),
      );
      final left = tester.widget<RadioMenuButton<bool>>(
        find.widgetWithText(RadioMenuButton<bool>, 'Left'),
      );
      // Selected when value == groupValue.
      expect(center.value == center.groupValue, isTrue);
      expect(left.value == left.groupValue, isFalse);
      await tester.tap(find.text('Left'));
      await tester.pumpAndSettle();
      expect(invocations, ['left']);
    });

    testWidgets('separator renders a Divider between groups', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _actionsHarness(
            invocations: <Object>[],
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: [
                WorkbenchViewMenuTab(
                  intent: _FocusTestTabIntent('a'),
                  label: 'Alpha',
                ),
                WorkbenchMenuSeparator(),
                WorkbenchViewMenuTab(
                  intent: _FocusTestTabIntent('b'),
                  label: 'Beta',
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('WorkbenchMenuBar entry model (macOS native)', () {
    // Drives the macOS path. PlatformMenuBar serializes to the
    // `flutter/menu` channel on mount; stub it so the native path mounts
    // headless, then inspect the configured PlatformMenu tree.
    Future<PlatformMenu> pumpAndReadViewMenu(
      WidgetTester tester,
      List<WorkbenchMenuEntry> entries,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/menu'),
        (call) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/menu'),
          null,
        );
      });
      await tester.pumpWidget(
        wrapWithTheme(
          Actions(
            actions: <Type, Action<Intent>>{
              ToggleBottomPanelIntent: CallbackAction<ToggleBottomPanelIntent>(
                onInvoke: (_) => null,
              ),
              _FocusTestTabIntent: CallbackAction<_FocusTestTabIntent>(
                onInvoke: (_) => null,
              ),
            },
            child: WorkbenchMenuBar(
              useNativeMenuBar: true,
              entries: entries,
              child: const SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.pump();
      final menuBar = tester.widget<PlatformMenuBar>(
        find.byType(PlatformMenuBar),
      );
      return menuBar.menus.firstWhere(
            (m) => m is PlatformMenu && m.label == 'View',
          )
          as PlatformMenu;
    }

    testWidgets('checkbox degrades to a leading "✓ " when checked', (
      tester,
    ) async {
      final view = await pumpAndReadViewMenu(tester, const [
        WorkbenchMenuCheckbox(
          intent: ToggleBottomPanelIntent(),
          label: 'Panel',
          checked: true,
        ),
        WorkbenchMenuCheckbox(
          intent: ToggleBottomPanelIntent(),
          label: 'Status Bar',
          checked: false,
        ),
      ]);
      final labels = view.menus
          .cast<PlatformMenuItem>()
          .map((m) => m.label)
          .toList();
      expect(labels, ['✓ Panel', 'Status Bar']);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('radio degrades to a leading "✓ " on the selected member', (
      tester,
    ) async {
      final view = await pumpAndReadViewMenu(tester, const [
        WorkbenchMenuSubmenu(
          label: 'Align Panel',
          children: [
            WorkbenchMenuRadio(
              intent: _FocusTestTabIntent('center'),
              label: 'Center',
              selected: true,
            ),
            WorkbenchMenuRadio(
              intent: _FocusTestTabIntent('left'),
              label: 'Left',
              selected: false,
            ),
          ],
        ),
      ]);
      final submenu = view.menus.single as PlatformMenu;
      expect(submenu.label, 'Align Panel');
      final labels = submenu.menus
          .cast<PlatformMenuItem>()
          .map((m) => m.label)
          .toList();
      expect(labels, ['✓ Center', 'Left']);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('separator splits children into PlatformMenuItemGroups', (
      tester,
    ) async {
      final view = await pumpAndReadViewMenu(tester, const [
        WorkbenchViewMenuTab(
          intent: _FocusTestTabIntent('a'),
          label: 'Alpha',
        ),
        WorkbenchMenuSeparator(),
        WorkbenchViewMenuTab(intent: _FocusTestTabIntent('b'), label: 'Beta'),
      ]);
      expect(view.menus, hasLength(2));
      expect(view.menus.every((m) => m is PlatformMenuItemGroup), isTrue);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('WorkbenchMenuBar application menu label', () {
    test('defaults to the neutral host-agnostic label', () {
      const bar = WorkbenchMenuBar(entries: [], child: SizedBox.shrink());
      expect(bar.applicationMenuLabel, isNotEmpty);
      expect(
        bar.applicationMenuLabel,
        WorkbenchMenuBar.defaultApplicationMenuLabel,
      );
    });

    test('threads the configured label through the widget field', () {
      const bar = WorkbenchMenuBar(
        applicationMenuLabel: 'Acme',
        entries: [],
        child: SizedBox.shrink(),
      );
      expect(bar.applicationMenuLabel, 'Acme');
    });

    testWidgets('macOS application menu uses applicationMenuLabel', (
      tester,
    ) async {
      // Drive the macOS rendering path. PlatformMenuBar serializes its
      // menus to the `flutter/menu` channel on mount; stub the channel
      // so the native path mounts under the test host without a real
      // NSMenu backend, letting us inspect the configured PlatformMenu.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('flutter/menu'),
        (call) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('flutter/menu'),
          null,
        );
      });

      await tester.pumpWidget(
        wrapWithTheme(
          Actions(
            actions: <Type, Action<Intent>>{
              ToggleBottomPanelIntent: CallbackAction<ToggleBottomPanelIntent>(
                onInvoke: (_) => null,
              ),
            },
            child: const WorkbenchMenuBar(
              useNativeMenuBar: true,
              applicationMenuLabel: 'Acme',
              // A non-empty tab keeps the View menu's
              // PlatformMenuItemGroup valid during channel serialization.
              entries: [
                WorkbenchViewMenuTab(
                  intent: _FocusTestTabIntent('mdi'),
                  label: 'MDI',
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
      await tester.pump();

      final menuBar = tester.widget<PlatformMenuBar>(
        find.byType(PlatformMenuBar),
      );
      final appMenu = menuBar.menus.first as PlatformMenu;
      expect(appMenu.label, 'Acme');

      // Reset inside the body: the framework checks foundation debug
      // vars before addTearDown runs.
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('WorkbenchMenuBar styling (in-window)', () {
    Widget buildHarness(WorkbenchTheme theme) {
      return MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [theme]),
        home: Scaffold(
          body: Actions(
            actions: <Type, Action<Intent>>{
              ToggleBottomPanelIntent: CallbackAction<ToggleBottomPanelIntent>(
                onInvoke: (_) => null,
              ),
              _FocusTestTabIntent: CallbackAction<_FocusTestTabIntent>(
                onInvoke: (_) => null,
              ),
            },
            child: const WorkbenchMenuBar(
              useNativeMenuBar: false,
              entries: [
                WorkbenchViewMenuTab(
                  intent: _FocusTestTabIntent('mdi'),
                  label: 'MDI',
                ),
              ],
              child: SizedBox(width: 400, height: 200),
            ),
          ),
        ),
      );
    }

    testWidgets('strip background reads from WorkbenchTheme', (tester) async {
      final themeA = testWorkbenchTheme.copyWith(
        menuBarBackground: const Color(0xFF101112),
        menuBarForeground: const Color(0xFFEEEEEE),
        menuBarBorder: const Color(0xFF303132),
      );
      await tester.pumpWidget(buildHarness(themeA));
      await tester.pumpAndSettle();

      // The strip container is the decorated box directly above the
      // Material `MenuBar`. Pull it via an ancestor walk from the bar.
      final stripContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(MenuBar),
              matching: find.byType(Container),
            )
            .first,
      );
      final stripDecoration = stripContainer.decoration! as BoxDecoration;
      expect(stripDecoration.color, const Color(0xFF101112));
      expect(
        (stripDecoration.border! as Border).bottom.color,
        const Color(0xFF303132),
      );

      // Swap to a contrasting theme and confirm the strip follows.
      final themeB = testWorkbenchTheme.copyWith(
        menuBarBackground: const Color(0xFFAABBCC),
        menuBarForeground: const Color(0xFF112233),
        menuBarBorder: const Color(0xFF445566),
      );
      await tester.pumpWidget(buildHarness(themeB));
      await tester.pumpAndSettle();

      final stripContainerB = tester.widget<Container>(
        find
            .ancestor(
              of: find.byType(MenuBar),
              matching: find.byType(Container),
            )
            .first,
      );
      final stripDecorationB = stripContainerB.decoration! as BoxDecoration;
      expect(stripDecorationB.color, const Color(0xFFAABBCC));
      expect(
        (stripDecorationB.border! as Border).bottom.color,
        const Color(0xFF445566),
      );
    });

    testWidgets('menu button foreground resolves to menuBarForeground', (
      tester,
    ) async {
      final theme = testWorkbenchTheme.copyWith(
        menuBarForeground: const Color(0xFFC0FFEE),
      );
      await tester.pumpWidget(buildHarness(theme));
      await tester.pumpAndSettle();

      // Both the top-level `SubmenuButton` and every `MenuItemButton`
      // resolve their styling through `MenuButtonTheme`. Read the
      // installed override from the nearest element inside the bar.
      final view = find.descendant(
        of: find.byType(MenuBar),
        matching: find.text('View'),
      );
      expect(view, findsOneWidget);
      final themeData = MenuButtonTheme.of(tester.element(view));
      final resolvedColor = themeData.style!.foregroundColor!.resolve(const {});
      expect(resolvedColor, const Color(0xFFC0FFEE));
    });
  });

  group('WorkbenchShortcuts', () {
    Widget buildShell({
      required List<Object> invocations,
      Map<ShortcutActivator, Intent>? extraShortcuts,
    }) {
      return wrapWithTheme(
        Actions(
          actions: <Type, Action<Intent>>{
            ToggleBottomPanelIntent: CallbackAction<ToggleBottomPanelIntent>(
              onInvoke: (intent) {
                invocations.add(intent);
                return null;
              },
            ),
          },
          child: WorkbenchShortcuts(
            extraShortcuts: extraShortcuts,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );
    }

    testWidgets('Cmd+J dispatches ToggleBottomPanelIntent', (tester) async {
      final invocations = <Object>[];
      await tester.pumpWidget(buildShell(invocations: invocations));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();
      expect(invocations, hasLength(greaterThanOrEqualTo(1)));
      expect(invocations.first, isA<ToggleBottomPanelIntent>());
    });

    testWidgets('Ctrl+J dispatches ToggleBottomPanelIntent', (tester) async {
      final invocations = <Object>[];
      await tester.pumpWidget(buildShell(invocations: invocations));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(invocations, hasLength(greaterThanOrEqualTo(1)));
      expect(invocations.first, isA<ToggleBottomPanelIntent>());
    });

    testWidgets('extraShortcuts merge into the default map', (tester) async {
      final invocations = <Object>[];
      await tester.pumpWidget(
        buildShell(
          invocations: invocations,
          extraShortcuts: const {
            SingleActivator(LogicalKeyboardKey.keyK, control: true):
                ToggleBottomPanelIntent(),
          },
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(invocations, hasLength(greaterThanOrEqualTo(1)));
    });
  });

  group('WorkbenchMenuBar enable state (in-window)', () {
    testWidgets(
      'menu item renders disabled when host action reports disabled',
      (tester) async {
        final invocations = <Object>[];
        final enabledAction = _ToggleEnabledAction(enabled: false);
        addTearDown(enabledAction.dispose);
        await tester.pumpWidget(
          wrapWithTheme(
            Actions(
              actions: <Type, Action<Intent>>{
                ToggleBottomPanelIntent: enabledAction,
                _FocusTestTabIntent: CallbackAction<_FocusTestTabIntent>(
                  onInvoke: (intent) {
                    invocations.add(intent.id);
                    return null;
                  },
                ),
              },
              child: const WorkbenchMenuBar(
                useNativeMenuBar: false,
                entries: [
                  WorkbenchViewMenuTab(
                    intent: ToggleBottomPanelIntent(),
                    label: 'Panel',
                  ),
                ],
                child: SizedBox(width: 400, height: 200),
              ),
            ),
          ),
        );
        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        final item = tester.widget<MenuItemButton>(
          find.widgetWithText(MenuItemButton, 'Panel'),
        );
        expect(item.onPressed, isNull);
      },
    );

    testWidgets(
      'menu item re-enables live when host action notifies listeners',
      (tester) async {
        final enabledAction = _ToggleEnabledAction(enabled: false);
        addTearDown(enabledAction.dispose);
        await tester.pumpWidget(
          wrapWithTheme(
            Actions(
              actions: <Type, Action<Intent>>{
                ToggleBottomPanelIntent: enabledAction,
              },
              child: const WorkbenchMenuBar(
                useNativeMenuBar: false,
                entries: [
                  WorkbenchViewMenuTab(
                    intent: ToggleBottomPanelIntent(),
                    label: 'Panel',
                  ),
                ],
                child: SizedBox(width: 400, height: 200),
              ),
            ),
          ),
        );
        await tester.tap(find.text('View'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MenuItemButton>(
                find.widgetWithText(MenuItemButton, 'Panel'),
              )
              .onPressed,
          isNull,
        );

        enabledAction.setEnabled(true);
        await tester.pump();
        expect(
          tester
              .widget<MenuItemButton>(
                find.widgetWithText(MenuItemButton, 'Panel'),
              )
              .onPressed,
          isNotNull,
        );
      },
    );
  });
}

/// Host-style `Action` whose `isActionEnabled` is under test control
/// and who forwards changes via [notifyActionListeners].
class _ToggleEnabledAction extends Action<ToggleBottomPanelIntent> {
  _ToggleEnabledAction({required bool enabled}) : _enabled = enabled;

  bool _enabled;

  @override
  bool isEnabled(ToggleBottomPanelIntent intent) => _enabled;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyActionListeners();
  }

  @override
  Object? invoke(ToggleBottomPanelIntent intent) => null;

  void dispose() {}
}

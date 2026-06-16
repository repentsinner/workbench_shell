import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

/// Build a collapsible pane through the library-internal seam the container
/// uses (§spec:view-stack). The public constructor renders a non-collapsible
/// standalone pane; collapsibility is container-derived, so collapse behavior
/// is exercised via [WorkbenchViewPane.inContainer], the same seam
/// [WorkbenchViewContainer] drives.
WorkbenchViewPane _collapsiblePane({
  required String title,
  required Widget child,
  bool initiallyExpanded = true,
  bool? expanded,
  ValueChanged<bool>? onExpandedChanged,
  String? infoTooltip,
  List<Widget> actions = const [],
  bool actionsAlwaysVisible = false,
  Key? key,
}) {
  return WorkbenchViewPane.inContainer(
    key: key,
    title: title,
    collapsible: true,
    initiallyExpanded: initiallyExpanded,
    expanded: expanded,
    onExpandedChanged: onExpandedChanged,
    infoTooltip: infoTooltip,
    actions: actions,
    actionsAlwaysVisible: actionsAlwaysVisible,
    child: child,
  );
}

void main() {
  group('WorkbenchViewPane', () {
    testWidgets('renders title uppercased with sectionTitle style', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchViewPane(title: 'Hello', child: Text('body')),
        ),
      );
      // §spec:chrome-typography-canon: WorkbenchViewPane adopts the pane-header canon —
      // titles render uppercase regardless of input casing, parallel
      // to the §spec:tabbed-panel tab-label canon.
      final titleFinder = find.text('HELLO');
      expect(titleFinder, findsOneWidget);
      expect(find.text('Hello'), findsNothing);
      expect(find.text('body'), findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style, testWorkbenchTheme.sectionTitle);
    });

    testWidgets('uppercases title regardless of input casing', (tester) async {
      // Mixed-case, all-lower, and already-upper inputs all render
      // uppercase — the shell owns the transform so consumers cannot
      // diverge (§spec:capability-boundary canon enforcement).
      await tester.pumpWidget(
        wrapWithTheme(
          const Column(
            children: [
              WorkbenchViewPane(title: 'mixed Case', child: SizedBox.shrink()),
              WorkbenchViewPane(title: 'all lower', child: SizedBox.shrink()),
              WorkbenchViewPane(title: 'ALREADY UP', child: SizedBox.shrink()),
            ],
          ),
        ),
      );
      expect(find.text('MIXED CASE'), findsOneWidget);
      expect(find.text('ALL LOWER'), findsOneWidget);
      expect(find.text('ALREADY UP'), findsOneWidget);
    });

    testWidgets('renders info tooltip when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchViewPane(
            title: 'Hello',
            infoTooltip: 'helpful',
            child: SizedBox.shrink(),
          ),
        ),
      );
      expect(find.byIcon(Symbols.info_rounded), findsOneWidget);
    });

    testWidgets('omits tooltip icon when null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchViewPane(title: 'Hello', child: SizedBox.shrink()),
        ),
      );
      expect(find.byIcon(Symbols.info_rounded), findsNothing);
    });
  });

  group('WorkbenchViewPane disclosure', () {
    // §spec:section-disclosure: disclosure is opt-in and off by default.
    testWidgets(
      'non-collapsible pane renders body unconditionally with no chevron',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            const WorkbenchViewPane(title: 'Hello', child: Text('body')),
          ),
        );
        expect(find.text('body'), findsOneWidget);
        expect(find.byIcon(Symbols.expand_more_rounded), findsNothing);
        expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
      },
    );

    testWidgets(
      'public constructor takes no host collapsible flag — pane is '
      'non-collapsible (§spec:section-disclosure)',
      (tester) async {
        // The default public constructor renders the standalone primitive:
        // body always shown, no chevron. Collapsibility is container-derived
        // (§spec:view-stack), never a host param. A `collapsible:` argument to
        // this constructor would not compile — analyze guards the absence.
        await tester.pumpWidget(
          wrapWithTheme(
            const WorkbenchViewPane(title: 'Hello', child: Text('body')),
          ),
        );
        expect(find.text('body'), findsOneWidget);
        expect(find.byIcon(Symbols.expand_more_rounded), findsNothing);
        expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
      },
    );

    testWidgets('collapsible pane shows a leading chevron', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(title: 'Hello', child: const Text('body')),
        ),
      );
      // Expanded by default → downward chevron, body visible.
      expect(find.byIcon(Symbols.expand_more_rounded), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('header tap toggles body visibility and chevron orientation', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(title: 'Hello', child: const Text('body')),
        ),
      );
      expect(find.text('body'), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsOneWidget);

      await tester.tap(find.text('HELLO'));
      await tester.pumpAndSettle();

      // Collapsed → body hidden, chevron points right.
      expect(find.text('body'), findsNothing);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsNothing);

      await tester.tap(find.text('HELLO'));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsOneWidget);
    });

    testWidgets('starts collapsed when initiallyExpanded is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(
            title: 'Hello',
            initiallyExpanded: false,
            child: const Text('body'),
          ),
        ),
      );
      expect(find.text('body'), findsNothing);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('keyboard Enter and Space toggle the pane', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(title: 'Hello', child: const Text('body')),
        ),
      );
      expect(find.text('body'), findsOneWidget);

      // The header toggle is an InkWell — focus it via traversal, then drive
      // activation through the keyboard (Enter/Space fire ActivateIntent on
      // the focused InkWell). Tab moves primary focus to the focusable header.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(primaryFocus, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('collapsible header exposes Semantics(expanded:)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(title: 'Hello', child: const Text('body')),
        ),
      );
      // Expanded by default.
      expect(
        tester.getSemantics(find.text('HELLO')),
        matchesSemantics(
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          label: 'HELLO',
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );

      await tester.tap(find.text('HELLO'));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.text('HELLO')),
        matchesSemantics(
          isButton: true,
          hasExpandedState: true,
          // isExpanded omitted — defaults to false, asserting collapsed.
          label: 'HELLO',
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('controlled mode reflects expanded and fires callback', (
      tester,
    ) async {
      bool? reported;
      Widget build(bool expanded) => wrapWithTheme(
        _collapsiblePane(
          title: 'Hello',
          expanded: expanded,
          onExpandedChanged: (value) => reported = value,
          child: const Text('body'),
        ),
      );

      await tester.pumpWidget(build(true));
      expect(find.text('body'), findsOneWidget);

      // Tapping reports the requested next state but does not self-toggle:
      // the host drives the value.
      await tester.tap(find.text('HELLO'));
      await tester.pumpAndSettle();
      expect(reported, isFalse);
      // Still expanded because the host has not pushed a new value.
      expect(find.text('body'), findsOneWidget);

      // Host pushes the collapsed value → body hides.
      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    });
  });

  group('WorkbenchViewPane header actions', () {
    // §spec:section-header-actions: actions are host-supplied widgets the
    // shell only places and reveals — hidden until hover/focus, only while
    // expanded, hidden entirely when collapsed, with an always-visible
    // opt-in. Activating an action does not toggle the pane.
    const actionKey = Key('pane-action');
    final actionWidget = IconButton(
      key: actionKey,
      icon: const Icon(Symbols.refresh_rounded),
      onPressed: () {},
    );

    // Drive a synthetic mouse hover onto the header center.
    Future<TestGesture> hoverHeader(WidgetTester tester) async {
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('HELLO')));
      await tester.pumpAndSettle();
      return gesture;
    }

    testWidgets('empty actions renders the header unchanged', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchViewPane(title: 'Hello', child: Text('body')),
        ),
      );
      // No actions supplied → no IconButton, header is title-only.
      expect(find.byType(IconButton), findsNothing);
      expect(find.text('HELLO'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('actions hidden by default without hover', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchViewPane(
            title: 'Hello',
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      expect(find.byKey(actionKey), findsNothing);
    });

    testWidgets('actions appear on header hover while expanded', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchViewPane(
            title: 'Hello',
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      expect(find.byKey(actionKey), findsNothing);
      await hoverHeader(tester);
      expect(find.byKey(actionKey), findsOneWidget);
    });

    testWidgets('actions appear on header focus via traversal', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchViewPane(
            title: 'Hello',
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      expect(find.byKey(actionKey), findsNothing);
      // Tab moves primary focus onto the header's focus scope, revealing the
      // actions (no hover involved).
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(primaryFocus, isNotNull);
      expect(find.byKey(actionKey), findsOneWidget);
    });

    testWidgets('actions hidden entirely when collapsed even while hovered', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(
            title: 'Hello',
            initiallyExpanded: false,
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      // Collapsed: hovering the header must not reveal the actions.
      await hoverHeader(tester);
      expect(find.byKey(actionKey), findsNothing);
    });

    testWidgets('always-visible mode shows actions without hover', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchViewPane(
            title: 'Hello',
            actionsAlwaysVisible: true,
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      expect(find.byKey(actionKey), findsOneWidget);
    });

    testWidgets('always-visible actions still hide when collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(
            title: 'Hello',
            initiallyExpanded: false,
            actionsAlwaysVisible: true,
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      // Always-visible is gated on expansion: a collapsed pane hides actions.
      expect(find.byKey(actionKey), findsNothing);
    });

    testWidgets('tapping an action runs its callback and does not toggle', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(
            title: 'Hello',
            actionsAlwaysVisible: true,
            actions: [
              IconButton(
                key: actionKey,
                icon: const Icon(Symbols.refresh_rounded),
                onPressed: () => tapped++,
              ),
            ],
            child: const Text('body'),
          ),
        ),
      );
      // Expanded with the action shown.
      expect(find.text('body'), findsOneWidget);
      expect(find.byKey(actionKey), findsOneWidget);

      await tester.tap(find.byKey(actionKey));
      await tester.pumpAndSettle();

      // The action ran; the pane stayed expanded (tap did not bubble to the
      // header toggle).
      expect(tapped, 1);
      expect(find.text('body'), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsOneWidget);
    });

    testWidgets('header layout order: twisty -> title -> infoTooltip -> '
        'actions', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          _collapsiblePane(
            title: 'Hello',
            infoTooltip: 'meta',
            actionsAlwaysVisible: true,
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      final twistyX = tester.getCenter(
        find.byIcon(Symbols.expand_more_rounded),
      ).dx;
      final titleX = tester.getCenter(find.text('HELLO')).dx;
      final infoX = tester.getCenter(find.byIcon(Symbols.info_rounded)).dx;
      final actionX = tester.getCenter(find.byKey(actionKey)).dx;
      expect(twistyX, lessThan(titleX));
      expect(titleX, lessThan(infoX));
      expect(infoX, lessThan(actionX));
    });

    testWidgets("action vertical center matches the title's", (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchViewPane(
            title: 'Hello',
            actionsAlwaysVisible: true,
            actions: [actionWidget],
            child: const Text('body'),
          ),
        ),
      );
      final titleY = tester.getCenter(find.text('HELLO')).dy;
      final actionY = tester.getCenter(find.byKey(actionKey)).dy;
      expect((titleY - actionY).abs(), lessThan(1.0));
    });
  });

  group('WorkbenchViewPane header chrome', () {
    // §spec:view-stack: each pane header paints a section-header
    // background band and a 1px top rule from the nullable
    // sideBarSectionHeader.background / sideBarSectionHeader.border
    // tokens. Null tokens suppress each paint independently.
    const band = Color(0xFF181818);
    const rule = Color(0xFF2B2B2B);

    WorkbenchTheme themeWith({Color? background, Color? border}) {
      final colors = <String, Color>{};
      if (background != null) {
        colors['sideBarSectionHeader.background'] = background;
      }
      if (border != null) colors['sideBarSectionHeader.border'] = border;
      return WorkbenchTheme.fromVscodeColorMap(
        VscodeColorMap(name: 'Header', baseType: 'vs-dark', colors: colors),
      );
    }

    Widget wrapWith(WorkbenchTheme theme, Widget child) {
      return MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [theme]),
        home: Scaffold(body: child),
      );
    }

    // The header band Container is the Container ancestor of the title
    // text that carries a BoxDecoration (the only decorated Container in
    // a WorkbenchViewPane header).
    BoxDecoration? headerDecoration(WidgetTester tester) {
      final containers = tester
          .widgetList<Container>(
            find.ancestor(
              of: find.text('HELLO'),
              matching: find.byType(Container),
            ),
          )
          .where((c) => c.decoration is BoxDecoration);
      if (containers.isEmpty) return null;
      return containers.first.decoration as BoxDecoration;
    }

    testWidgets('paints the background band and 1px top rule from tokens', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWith(
          themeWith(background: band, border: rule),
          const WorkbenchViewPane(title: 'Hello', child: Text('body')),
        ),
      );
      final decoration = headerDecoration(tester);
      expect(decoration, isNotNull);
      expect(decoration!.color, band);
      final topSide = (decoration.border as Border).top;
      expect(topSide.color, rule);
      expect(topSide.width, 1.0);
    });

    testWidgets('header sits at the pane-header height (rule absorbed)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWith(
          themeWith(background: band, border: rule),
          const WorkbenchViewPane(title: 'Hello', child: Text('body')),
        ),
      );
      // Box-sizing border-box: the header occupies exactly the canonical
      // pane-header height, the 1px rule absorbed within it — not
      // height + 1.
      final size = tester.getSize(
        find.ancestor(
          of: find.text('HELLO'),
          matching: find.byType(Container),
        ).first,
      );
      expect(size.height, WorkbenchLayoutConstants.viewPaneHeaderHeight);
    });

    testWidgets('suppresses the band when background token is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWith(
          themeWith(border: rule),
          const WorkbenchViewPane(title: 'Hello', child: Text('body')),
        ),
      );
      final decoration = headerDecoration(tester);
      expect(decoration?.color, isNull);
      expect((decoration!.border as Border).top.color, rule);
    });

    testWidgets('suppresses both paints when both tokens are null', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWith(
          themeWith(),
          const WorkbenchViewPane(title: 'Hello', child: Text('body')),
        ),
      );
      // Neither paint appears — no decorated header Container.
      expect(headerDecoration(tester), isNull);
      // Header still renders its title and body as before.
      expect(find.text('HELLO'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });
  });

  group('WorkbenchSubsection', () {
    testWidgets('renders title with subsectionTitleStyle', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchSubsection(title: 'Sub', child: Text('body')),
        ),
      );
      final textWidget = tester.widget<Text>(find.text('Sub'));
      expect(textWidget.style, testWorkbenchTheme.subsectionTitleStyle);
    });
  });

  group('WorkbenchCard', () {
    testWidgets('renders bordered container around child', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(const WorkbenchCard(child: Text('card-body'))),
      );
      expect(find.text('card-body'), findsOneWidget);
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('card-body'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        (decoration.border as Border).top.color,
        testWorkbenchTheme.borderColor,
      );
    });
  });

  group('WorkbenchEmptyState', () {
    testWidgets('renders icon, title, subtitle, and action', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchEmptyState(
            icon: Symbols.inbox_rounded,
            title: 'Nothing here',
            subtitle: 'Try adding one',
            action: OutlinedButton(onPressed: () {}, child: const Text('Add')),
          ),
        ),
      );
      expect(find.byIcon(Symbols.inbox_rounded), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Try adding one'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}

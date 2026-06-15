import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

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

    testWidgets('collapsible pane shows a leading chevron', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchViewPane(
            title: 'Hello',
            collapsible: true,
            child: Text('body'),
          ),
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
          const WorkbenchViewPane(
            title: 'Hello',
            collapsible: true,
            child: Text('body'),
          ),
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
          const WorkbenchViewPane(
            title: 'Hello',
            collapsible: true,
            initiallyExpanded: false,
            child: Text('body'),
          ),
        ),
      );
      expect(find.text('body'), findsNothing);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('keyboard Enter and Space toggle the pane', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchViewPane(
            title: 'Hello',
            collapsible: true,
            child: Text('body'),
          ),
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
          const WorkbenchViewPane(
            title: 'Hello',
            collapsible: true,
            child: Text('body'),
          ),
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
        WorkbenchViewPane(
          title: 'Hello',
          collapsible: true,
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

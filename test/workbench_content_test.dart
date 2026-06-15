import 'package:flutter/material.dart';
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

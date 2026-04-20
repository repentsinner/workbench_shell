import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('WorkbenchSection', () {
    testWidgets('renders title with sectionTitleStyle', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchSection(title: 'Hello', child: Text('body')),
        ),
      );
      final titleFinder = find.text('Hello');
      expect(titleFinder, findsOneWidget);
      expect(find.text('body'), findsOneWidget);
      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style, testWorkbenchTheme.sectionTitleStyle);
    });

    testWidgets('renders info tooltip when provided', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchSection(
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
          const WorkbenchSection(title: 'Hello', child: SizedBox.shrink()),
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

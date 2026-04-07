import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('omits tooltip icon when null', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const WorkbenchSection(title: 'Hello', child: SizedBox.shrink()),
        ),
      );
      expect(find.byIcon(Icons.info_outline), findsNothing);
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

  group('WorkbenchTextField', () {
    testWidgets('renders label and controller-backed input', (tester) async {
      final controller = TextEditingController(text: 'initial');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchTextField(label: 'Name', controller: controller),
        ),
      );
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('initial'), findsOneWidget);
    });

    testWidgets('renders helper text when provided', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchTextField(
            label: 'Name',
            controller: controller,
            helperText: 'helpful hint',
          ),
        ),
      );
      expect(find.text('helpful hint'), findsOneWidget);
    });
  });

  group('WorkbenchDropdown', () {
    testWidgets('renders label and selected value', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchDropdown<String>(
            label: 'Mode',
            value: 'a',
            items: const [
              WorkbenchDropdownItem(value: 'a', label: 'Alpha'),
              WorkbenchDropdownItem(value: 'b', label: 'Beta'),
            ],
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Mode'), findsOneWidget);
      expect(find.text('Alpha'), findsWidgets);
    });
  });

  group('WorkbenchToggle', () {
    testWidgets('renders label, description, and switch', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchToggle(
            label: 'Enable',
            description: 'turn it on',
            value: true,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.text('Enable'), findsOneWidget);
      expect(find.text('turn it on'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      final sw = tester.widget<Switch>(find.byType(Switch));
      expect(sw.value, isTrue);
    });
  });

  group('WorkbenchActionButton', () {
    testWidgets('renders label and optional icon', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchActionButton(
            label: 'Go',
            icon: Icons.play_arrow,
            onPressed: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Go'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      await tester.tap(find.byType(WorkbenchActionButton));
      expect(tapped, isTrue);
    });
  });

  group('WorkbenchEmptyState', () {
    testWidgets('renders icon, title, subtitle, and action', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          WorkbenchEmptyState(
            icon: Icons.inbox,
            title: 'Nothing here',
            subtitle: 'Try adding one',
            action: WorkbenchActionButton(label: 'Add', onPressed: () {}),
          ),
        ),
      );
      expect(find.byIcon(Icons.inbox), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Try adding one'), findsOneWidget);
      expect(find.text('Add'), findsOneWidget);
    });
  });
}

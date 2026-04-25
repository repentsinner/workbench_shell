// Widget test for the workbench_shell example app.
//
// Exercises the integration surface: the example renders the
// canonical VS Code five-panel set, both activity-bar sidebars
// switch on tap, and the initial active panel (Problems) renders
// its content body.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell_example/main.dart';

void main() {
  testWidgets('example renders five canonical panels and Problems content', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // Both activity-bar icons present.
    expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.search_rounded), findsOneWidget);

    // Default sidebar (Explorer) body rendered.
    expect(
      find.text('Explorer sidebar — host-supplied content lands here.'),
      findsOneWidget,
    );

    // All five canonical panels render their tab labels.
    for (final label in const [
      'Problems',
      'Output',
      'Debug Console',
      'Terminal',
      'Ports',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'tab "$label" missing');
    }

    // Problems is the initial tab — its content body shows.
    expect(
      find.text('Problems tab — host-supplied content lands here.'),
      findsOneWidget,
    );

    // Status bar item rendered.
    expect(find.text('workbench_shell example'), findsOneWidget);
  });

  testWidgets('tapping a second activity-bar item switches sidebars', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Symbols.search_rounded));
    await tester.pumpAndSettle();

    expect(
      find.text('Search sidebar — host-supplied content lands here.'),
      findsOneWidget,
    );
    expect(
      find.text('Explorer sidebar — host-supplied content lands here.'),
      findsNothing,
    );
  });
}

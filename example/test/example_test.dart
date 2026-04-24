// Widget test for the workbench_shell example app.
//
// Exercises the integration surface: ensures the example renders
// without error, both activity-bar icons are present, and the
// bottom panel's Output tab is visible on first frame.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell_example/main.dart';

void main() {
  testWidgets('example app renders chrome with both sidebars and panel tab', (
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

    // Bottom panel with Output tab rendered.
    expect(find.text('Output'), findsOneWidget);
    expect(
      find.text('Output tab — host-supplied content lands here.'),
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

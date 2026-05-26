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

    // All five canonical panels render their tab labels. The tab
    // strip uppercases labels per the §7.4 canon, so assert against
    // the uppercased form.
    for (final label in const [
      'PROBLEMS',
      'OUTPUT',
      'DEBUG CONSOLE',
      'TERMINAL',
      'PORTS',
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

  testWidgets('Settings sidebar renders auto-detect and three theme slots', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // Settings sits in the activity bar's bottom zone.
    await tester.tap(find.byIcon(Symbols.settings_rounded));
    await tester.pumpAndSettle();

    // Auto-detect checkbox row and the three labelled dropdown slots
    // render, mirroring VS Code's settings layout.
    expect(find.text('Auto detect color scheme'), findsOneWidget);
    expect(find.text('Color theme'), findsOneWidget);
    expect(find.text('Preferred dark color theme'), findsOneWidget);
    expect(find.text('Preferred light color theme'), findsOneWidget);
  });

  testWidgets('Notifications demo posts an info card via the host overlay', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // Notifications activity-bar item is present.
    expect(find.byIcon(Symbols.notifications_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Symbols.notifications_rounded));
    await tester.pumpAndSettle();

    // Sidebar exposes the trigger buttons.
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);

    // Triggering an info notification renders a card via the
    // NotificationHost overlay.
    await tester.tap(find.text('Info'));
    await tester.pump();
    expect(find.textContaining('Info notice'), findsOneWidget);
  });
}

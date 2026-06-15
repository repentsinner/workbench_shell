// Widget test for the workbench_shell example app.
//
// Exercises the integration surface: the example renders the
// canonical VS Code five-panel set, both activity-bar sidebars
// switch on tap, and the initial active panel (Problems) renders
// its content body.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';
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

    // Default sidebar (Explorer) renders its collapsible view panes
    // (§spec:section-disclosure). Titles uppercase per the pane-header canon.
    expect(find.text('OPEN EDITORS'), findsOneWidget);
    expect(find.text('OUTLINE'), findsOneWidget);
    expect(find.text('TIMELINE'), findsOneWidget);

    // All five canonical panels render their tab labels. The tab
    // strip uppercases labels per the §spec:tab-strip-canon canon, so assert against
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
    // Explorer's collapsible panes are gone once Search is active.
    expect(find.text('OPEN EDITORS'), findsNothing);
  });

  testWidgets('Explorer view pane collapses and expands on header tap', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // The "Open Editors" pane starts expanded: chevron down, body visible.
    expect(find.text('main.dart\nworkbench_content.dart'), findsOneWidget);
    expect(find.byIcon(Symbols.expand_more_rounded), findsWidgets);

    // Tapping the header collapses it — body hidden, chevron flips right.
    await tester.tap(find.text('OPEN EDITORS'));
    await tester.pumpAndSettle();
    expect(find.text('main.dart\nworkbench_content.dart'), findsNothing);

    // Tapping again restores the body.
    await tester.tap(find.text('OPEN EDITORS'));
    await tester.pumpAndSettle();
    expect(find.text('main.dart\nworkbench_content.dart'), findsOneWidget);
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

  testWidgets(
    'buttons review sidebar shows three flat VS Code tiers at rest (§spec:chrome-material-theming)',
    (tester) async {
      await tester.pumpWidget(const WorkbenchExampleApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Symbols.smart_button_rounded));
      await tester.pumpAndSettle();

      // Primary (FilledButton), secondary (FilledButton.tonal), and
      // text/link (TextButton) tiers each render once in the review.
      final primary = find.widgetWithText(FilledButton, 'Primary');
      final secondary = find.widgetWithText(FilledButton, 'Secondary');
      final link = find.widgetWithText(TextButton, 'Text / link');
      expect(primary, findsOneWidget);
      expect(secondary, findsOneWidget);
      expect(link, findsOneWidget);

      // All flat at rest: the filled tiers resolve 0 resting elevation
      // (no at-rest shadow) and VS Code's 4px shape, not Material 3's
      // pill. enabled == default WidgetState set.
      const resting = <WidgetState>{};
      for (final finder in [primary, secondary]) {
        final style = tester
            .widget<FilledButton>(finder)
            .defaultStyleOf(tester.element(finder));
        expect(style.elevation?.resolve(resting), 0);
      }
      final primaryShape = Theme.of(
        tester.element(primary),
      ).filledButtonTheme.style?.shape?.resolve(resting);
      expect(primaryShape, WorkbenchLayoutConstants.buttonShape);

      // Primary and secondary must render distinct fills — the tonal tier
      // pulls secondaryContainer, not the primary accent (§spec:chrome-material-theming).
      Color fillOf(Finder button) => tester
          .widgetList<Material>(
            find.descendant(of: button, matching: find.byType(Material)),
          )
          .first
          .color!;
      expect(fillOf(primary), isNot(fillOf(secondary)));
    },
  );
}

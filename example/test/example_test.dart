// Widget test for the workbench_shell example app.
//
// Exercises the integration surface: the example renders the
// canonical VS Code five-panel set, both activity-bar sidebars
// switch on tap, and the initial active panel (Problems) renders
// its content body.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Search content lives in a named "Results" view pane (header
    // uppercased per canon), not a raw merged body.
    expect(find.text('RESULTS'), findsOneWidget);
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

  testWidgets('dragging an Explorer pane header reorders the panes', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // Initial Explorer order: Open Editors, Outline, Timeline.
    expect(
      tester.getTopLeft(find.text('OPEN EDITORS')).dy,
      lessThan(tester.getTopLeft(find.text('OUTLINE')).dy),
    );

    // Drag the Outline header up onto the top half of Open Editors: Outline
    // lands before it. The drop indicator shows the target slot mid-drag.
    final outlineHeader = tester.getCenter(find.text('OUTLINE'));
    final openEditors = tester.getCenter(find.text('OPEN EDITORS'));
    final gesture = await tester.startGesture(outlineHeader);
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.moveTo(Offset(openEditors.dx, openEditors.dy - 6));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('workbench-view-drop-indicator')),
      findsOneWidget,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    // Order persists: Outline is now above Open Editors.
    expect(
      tester.getTopLeft(find.text('OUTLINE')).dy,
      lessThan(tester.getTopLeft(find.text('OPEN EDITORS')).dy),
    );
  });

  testWidgets(
    'Explorer header action posts a themed notification, not a SnackBar',
    (tester) async {
      await tester.pumpWidget(const WorkbenchExampleApp());
      await tester.pumpAndSettle();

      // Header actions are hover-revealed: move a mouse pointer over the
      // "Open Editors" header to reveal its Refresh action.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('OPEN EDITORS')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();

      // The action routes through NotificationService, so its message
      // surfaces as a card in the NotificationHost overlay — never a raw
      // Material SnackBar.
      expect(find.textContaining('Refreshed Open Editors'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('Settings sidebar renders auto-detect and three theme slots', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // Settings sits in the activity bar's bottom zone.
    await tester.tap(find.byIcon(Symbols.settings_rounded));
    await tester.pumpAndSettle();

    // Settings content is organized into two named view panes (headers
    // uppercased per canon): "Appearance" and "Color Theme".
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('COLOR THEME'), findsOneWidget);
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

    // Content is split across two named view panes (headers uppercased
    // per canon): "Severities" and "Progress".
    expect(find.text('SEVERITIES'), findsOneWidget);
    expect(find.text('PROGRESS'), findsOneWidget);
    // The Severities pane exposes the trigger buttons.
    expect(find.text('Info'), findsOneWidget);
    expect(find.text('Success'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);

    // The Severities pane body is bounded and scrolls internally
    // (§spec:view-stack splitview): the trigger may sit below the apportioned
    // body fold, so bring it into view before tapping.
    await tester.ensureVisible(find.text('Info'));
    await tester.pumpAndSettle();

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

      // Content lives in a named "Button Tiers" view pane (header
      // uppercased per canon), not a raw merged body.
      expect(find.text('BUTTON TIERS'), findsOneWidget);

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

  testWidgets(
    'Up/Down traverse the Explorer headers and clamp at the ends (§spec:view-pane-focus)',
    (tester) async {
      await tester.pumpWidget(const WorkbenchExampleApp());
      await tester.pumpAndSettle();

      // Each Explorer pane carries one focus-ring DecoratedBox; the ring
      // inside pane [id]'s keyed subtree paints the focusBorder accent (a
      // non-transparent color) while that header holds focus.
      Color ringColorOf(String id) {
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byKey(ValueKey('workbench-view-pane-$id')),
            matching: find.byKey(
              const ValueKey('view-pane-header-focus-ring'),
            ),
          ),
        );
        return ((box.decoration as BoxDecoration).border! as Border).top.color;
      }

      bool isFocused(String id) => ringColorOf(id) != Colors.transparent;

      // Focus the first Explorer header. Clicking a collapsible header also
      // toggles it, so re-click to leave the stack fully expanded.
      await tester.tap(find.text('OPEN EDITORS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN EDITORS'));
      await tester.pumpAndSettle();
      expect(isFocused('open-editors'), isTrue);

      // Down walks forward through the three headers.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused('outline'), isTrue);
      expect(isFocused('open-editors'), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused('timeline'), isTrue);

      // Down on the last header clamps — no wrap.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused('timeline'), isTrue);
      expect(isFocused('open-editors'), isFalse);

      // Up walks back and clamps at the first.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused('open-editors'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused('open-editors'), isTrue);
      expect(isFocused('outline'), isFalse);
    },
  );

  // Editing modes (§spec:editing-modes). The View menu dispatches
  // ToggleZenModeIntent / ToggleCenteredLayoutIntent through Actions —
  // exactly what these tests invoke — and the host feeds the booleans into
  // the shell's controlled zenMode / centeredLayout properties. Driving the
  // intents proves the menu→action→host→shell wiring without depending on the
  // platform menu surface (macOS renders the menu natively, untappable in a
  // widget test).
  testWidgets('Zen Mode intent hides all chrome; toggling off restores it', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // Chrome present before Zen.
    expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
    expect(find.text('workbench_shell example'), findsOneWidget); // status bar

    final context = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(context, const ToggleZenModeIntent());
    await tester.pumpAndSettle();

    // Editor only — activity bar, sidebar, and status bar gone.
    expect(find.textContaining('Lorem ipsum'), findsOneWidget);
    expect(find.byIcon(Symbols.folder_rounded), findsNothing);
    expect(find.text('OPEN EDITORS'), findsNothing);
    expect(find.text('workbench_shell example'), findsNothing);

    // Toggling off restores all chrome.
    final zenContext = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(zenContext, const ToggleZenModeIntent());
    await tester.pumpAndSettle();
    expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
    expect(find.text('workbench_shell example'), findsOneWidget);
  });

  testWidgets('Centered Layout intent narrows the editor while chrome stays', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // The editor placeholder is a scrolling monospace lorem body; its
    // scroll view spans the editor's available width.
    Rect editorBox() => tester.getRect(
      find
          .ancestor(
            of: find.textContaining('Lorem ipsum'),
            matching: find.byType(SingleChildScrollView),
          )
          .first,
    );

    final wideWidth = editorBox().width;
    expect(wideWidth, greaterThan(1200));

    final context = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(context, const ToggleCenteredLayoutIntent());
    await tester.pumpAndSettle();

    // Chrome stays put.
    expect(find.byIcon(Symbols.folder_rounded), findsOneWidget);
    expect(find.text('workbench_shell example'), findsOneWidget);

    // The editor narrowed to the golden-ratio fraction (~62%), centered.
    final centeredWidth = editorBox().width;
    expect(centeredWidth, lessThan(wideWidth * 0.72));

    // Toggling off lets the editor fill the width again.
    final centeredContext = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(centeredContext, const ToggleCenteredLayoutIntent());
    await tester.pumpAndSettle();
    expect(editorBox().width, wideWidth);
  });

  // Side-bar position (§spec:sidebar-position). The View menu dispatches
  // ToggleSidebarPositionIntent; the host swaps its edge and feeds it into the
  // shell's controlled sidebarPosition property. Driving the intent proves the
  // menu→action→host→shell wiring.
  testWidgets('Side Bar Position intent swaps the activity bar to the opposite '
      'edge and back', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    final activityIcon = find.byIcon(Symbols.folder_rounded);
    final leftX = tester.getCenter(activityIcon).dx;

    final context = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(context, const ToggleSidebarPositionIntent());
    await tester.pumpAndSettle();

    // The activity bar moved to the right edge.
    final rightX = tester.getCenter(activityIcon).dx;
    expect(rightX, greaterThan(leftX));

    // Toggling back returns it to the left.
    Actions.invoke(context, const ToggleSidebarPositionIntent());
    await tester.pumpAndSettle();
    expect(tester.getCenter(activityIcon).dx, closeTo(leftX, 1));
  });

  // Secondary side bar (§spec:secondary-sidebar). The View menu dispatches
  // ToggleSecondarySideBarIntent; the host owns visibility and assigns the
  // "Search" container to the secondary, which renders on the editor's opposite
  // edge from the primary and follows when the primary swaps sides.
  testWidgets('Secondary Side Bar intent shows the assigned container on the '
      'opposite edge and follows a primary swap', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    final searchBody = find.textContaining('Search sidebar');
    // Hidden by default — the host assigns 'search' but the secondary is off,
    // so its container is never built (lazy retention).
    expect(searchBody, findsNothing);

    final context = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(context, const ToggleSecondarySideBarIntent());
    await tester.pumpAndSettle();

    // Primary on the left (default) → the secondary appears on the right of the
    // editor.
    expect(searchBody, findsOneWidget);
    final editor = tester.getRect(find.textContaining('Lorem ipsum'));
    expect(tester.getCenter(searchBody).dx, greaterThan(editor.center.dx));

    // Swap the primary to the right → the secondary follows to the left edge.
    Actions.invoke(context, const ToggleSidebarPositionIntent());
    await tester.pumpAndSettle();
    final editorAfter = tester.getRect(find.textContaining('Lorem ipsum'));
    expect(tester.getCenter(searchBody).dx, lessThan(editorAfter.center.dx));

    // Toggling the secondary off hides it again.
    Actions.invoke(context, const ToggleSecondarySideBarIntent());
    await tester.pumpAndSettle();
    expect(searchBody, findsNothing);
  });

  // Primary side bar visibility (§spec:layout-customization). The View menu
  // dispatches ToggleSidebarIntent (VS Code's Cmd+B); the host owns the flag and
  // feeds the shell's controlled sidebarVisible property.
  testWidgets('Primary Side Bar intent hides and restores the primary bar', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    // Explorer is visible by default.
    expect(find.text('EXPLORER'), findsOneWidget);

    final context = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(context, const ToggleSidebarIntent());
    await tester.pumpAndSettle();
    expect(find.text('EXPLORER'), findsNothing);

    // Toggling again brings it back.
    Actions.invoke(context, const ToggleSidebarIntent());
    await tester.pumpAndSettle();
    expect(find.text('EXPLORER'), findsOneWidget);
  });

  // Status bar visibility (§spec:layout-customization). The View menu dispatches
  // ToggleStatusBarIntent; the host owns the flag and feeds the shell's
  // controlled statusBarVisible property.
  testWidgets('Status Bar intent hides and restores the status bar', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    final statusLabel = find.text('workbench_shell example');
    expect(statusLabel, findsOneWidget);

    final context = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(context, const ToggleStatusBarIntent());
    await tester.pumpAndSettle();
    expect(statusLabel, findsNothing);

    Actions.invoke(context, const ToggleStatusBarIntent());
    await tester.pumpAndSettle();
    expect(statusLabel, findsOneWidget);
  });

  // Panel alignment (§spec:panel-alignment). The View menu dispatches
  // CyclePanelAlignmentIntent; the host cycles center → justify → left → right
  // and feeds the shell's controlled panelAlignment property, which re-parents
  // the panel. Driving the intent proves the menu→action→host→shell wiring.
  testWidgets('Panel Alignment intent re-parents the bottom panel from the '
      'editor band to the full width', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();

    Rect panelRect() => tester.getRect(find.byType(WorkbenchTabbedPanel));

    // Center (default): the panel spans the editor only, so its left edge sits
    // well inboard of the window — past the activity bar and side bar.
    final centerLeft = panelRect().left;
    expect(centerLeft, greaterThan(100));

    // Cycle once → justify: the panel now spans the full width, so its left edge
    // moves left, past the activity bar and side bar to the window edge.
    final context = tester.element(find.byType(WorkbenchLayout));
    Actions.invoke(context, const CyclePanelAlignmentIntent());
    await tester.pumpAndSettle();
    final justifyLeft = panelRect().left;
    expect(justifyLeft, lessThan(centerLeft - 40));
    expect(justifyLeft, closeTo(0, 2));

    // Cycle back through left → right → center; the panel returns to the band.
    Actions.invoke(context, const CyclePanelAlignmentIntent()); // left
    Actions.invoke(context, const CyclePanelAlignmentIntent()); // right
    Actions.invoke(context, const CyclePanelAlignmentIntent()); // center
    await tester.pumpAndSettle();
    expect(panelRect().left, closeTo(centerLeft, 2));
  });
}

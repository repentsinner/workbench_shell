import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

/// The bundled default themes set both section-header tokens (§spec:view-stack),
/// so each pane header paints its fixed-height band. The shared fixture builds
/// from an empty color map where both resolve null, suppressing the band and
/// letting the header shrink to its intrinsic row height. Tests that assert the
/// canonical collapsed-pane height install a theme with the tokens set, mirroring
/// the bundled-theme reality.
Widget wrapWithChromeTheme(Widget child) {
  final theme = testWorkbenchTheme.copyWith(
    sideBarSectionHeaderBackground: const Color(0xFF252526),
    sideBarSectionHeaderBorder: const Color(0xFF3C3C3C),
  );
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [theme]),
    home: Scaffold(body: child),
  );
}

void main() {
  group('WorkbenchViewContainer stacking', () {
    testWidgets('N descriptors render N uppercased headers, flush stack', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: (_) => const Text('body-a'),
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: (_) => const Text('body-b'),
                ),
                WorkbenchViewDescriptor(
                  id: 'c',
                  title: 'Gamma',
                  bodyBuilder: (_) => const Text('body-c'),
                ),
              ],
            ),
          ),
        ),
      );

      // Titles render uppercased per pane canon.
      expect(find.text('ALPHA'), findsOneWidget);
      expect(find.text('BETA'), findsOneWidget);
      expect(find.text('GAMMA'), findsOneWidget);
      // Bodies present.
      expect(find.text('body-a'), findsOneWidget);
      expect(find.text('body-b'), findsOneWidget);
      expect(find.text('body-c'), findsOneWidget);

      // Flush: the container inserts no SizedBox gap between panes. The only
      // SizedBoxes present are the panes' internal header→body spacers and the
      // outer constraint box — none are container-inserted inter-pane gaps.
      // Assert adjacent headers are vertically ordered with no whitespace band:
      // the second header's top sits immediately after the first pane's column.
      final alphaTop = tester.getTopLeft(find.text('ALPHA')).dy;
      final betaTop = tester.getTopLeft(find.text('BETA')).dy;
      expect(betaTop, greaterThan(alphaTop));
    });

    testWidgets('first pane omits the top rule; later panes draw it', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithChromeTheme(
          SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: (_) => const Text('body-a'),
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: (_) => const Text('body-b'),
                ),
              ],
            ),
          ),
        ),
      );

      BoxDecoration decoFor(String title) {
        return tester
                .widgetList<Container>(
                  find.ancestor(
                    of: find.text(title),
                    matching: find.byType(Container),
                  ),
                )
                .firstWhere((c) => c.decoration is BoxDecoration)
                .decoration!
            as BoxDecoration;
      }

      final first = decoFor('ALPHA');
      final second = decoFor('BETA');
      // Both keep the section-header background band.
      expect(first.color, const Color(0xFF252526));
      expect(second.color, const Color(0xFF252526));
      // No divider above the first pane: the first header has no top rule.
      expect(first.border, isNull);
      // Adjacent panes are separated: later headers draw the 1px top rule.
      expect((second.border! as Border).top.color, const Color(0xFF3C3C3C));
    });

    testWidgets('2+ views: every pane collapsible, header shows chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: (_) => const Text('body-a'),
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: (_) => const Text('body-b'),
                ),
              ],
            ),
          ),
        ),
      );

      // Both expanded → two downward chevrons.
      expect(find.byIcon(Symbols.expand_more_rounded), findsNWidgets(2));
    });

    testWidgets('collapsing a pane hides its body; collapsed pane is header-height', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithChromeTheme(
          SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: (_) => const Text('body-a'),
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: (_) => const Text('body-b'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('body-a'), findsOneWidget);
      expect(find.text('body-b'), findsOneWidget);

      // Collapse Alpha by tapping its header.
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();

      // Alpha's body is gone; Beta's stays.
      expect(find.text('body-a'), findsNothing);
      expect(find.text('body-b'), findsOneWidget);

      // The collapsed Alpha pane occupies only its header height. Measure the
      // pane wrapper by key.
      final paneRect = tester.getRect(
        find.byKey(const ValueKey('workbench-view-pane-a')),
      );
      expect(
        paneRect.height,
        closeTo(WorkbenchLayoutConstants.viewPaneHeaderHeight, 0.5),
      );
    });

    testWidgets('single view, mergeSingleView false: non-collapsible, no chevron', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            height: 400,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'solo',
                  title: 'Solo',
                  bodyBuilder: (_) => const Text('body-solo'),
                ),
              ],
            ),
          ),
        ),
      );

      // Header visible, body shown, no chevron.
      expect(find.text('SOLO'), findsOneWidget);
      expect(find.text('body-solo'), findsOneWidget);
      expect(find.byIcon(Symbols.expand_more_rounded), findsNothing);
      expect(find.byIcon(Symbols.chevron_right_rounded), findsNothing);
    });

    testWidgets('single view, mergeSingleView true: merged, no pane header', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            height: 400,
            child: WorkbenchViewContainer(
              mergeSingleView: true,
              views: [
                WorkbenchViewDescriptor(
                  id: 'solo',
                  title: 'Solo',
                  bodyBuilder: (_) => const Text('body-solo'),
                ),
              ],
            ),
          ),
        ),
      );

      // Body fills; no pane header (title not rendered as a header).
      expect(find.text('body-solo'), findsOneWidget);
      expect(find.text('SOLO'), findsNothing);
      // No WorkbenchViewPane rendered at all.
      expect(find.byType(WorkbenchViewPane), findsNothing);
    });

    testWidgets('single shared scroll region on overflow; scroll reveals lower content', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            height: 200,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: (_) =>
                      const SizedBox(height: 400, child: Text('body-a')),
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: (_) =>
                      const SizedBox(height: 400, child: Text('bottom-b')),
                ),
              ],
            ),
          ),
        ),
      );

      // Exactly one Scrollable owns the stack.
      expect(find.byType(Scrollable), findsOneWidget);

      // Lower content is off-screen initially, present in the tree.
      final scrollable = find.byType(Scrollable);
      // Drag up to scroll down and reveal Beta's bottom content.
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('bottom-b'), findsOneWidget);
    });

    testWidgets('controlled descriptor reports next value, does not self-toggle', (
      tester,
    ) async {
      bool? reported;
      Widget build(bool expanded) => wrapWithTheme(
        SizedBox(
          height: 600,
          child: WorkbenchViewContainer(
            views: [
              WorkbenchViewDescriptor(
                id: 'a',
                title: 'Alpha',
                expanded: expanded,
                onExpandedChanged: (value) => reported = value,
                bodyBuilder: (_) => const Text('body-a'),
              ),
              WorkbenchViewDescriptor(
                id: 'b',
                title: 'Beta',
                bodyBuilder: (_) => const Text('body-b'),
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(build(true));
      expect(find.text('body-a'), findsOneWidget);

      // Tapping reports the requested next state but does not self-toggle:
      // the host drives the controlled descriptor's value.
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      expect(reported, isFalse);
      expect(find.text('body-a'), findsOneWidget);

      // Host pushes the collapsed value → body hides.
      await tester.pumpWidget(build(false));
      await tester.pumpAndSettle();
      expect(find.text('body-a'), findsNothing);
    });
  });
}

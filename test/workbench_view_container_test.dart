import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

      // Flush: the container inserts no SizedBox gap between panes. Assert
      // adjacent headers are vertically ordered, the later header below the
      // earlier one.
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
  });

  group('WorkbenchViewContainer splitview apportionment', () {
    // Helper: read a pane wrapper's rect by descriptor id.
    Rect paneRect(WidgetTester tester, String id) =>
        tester.getRect(find.byKey(ValueKey('workbench-view-pane-$id')));

    testWidgets('expanded panes with short content share the height evenly, '
        'no inner scroll engaged', (tester) async {
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      // The two panes together fill the container height: it is a fixed-height
      // splitview, not a natural-height column. Each body is taller than its
      // short content (the pane was given more than it needed).
      final a = paneRect(tester, 'a');
      final b = paneRect(tester, 'b');
      expect(a.height + b.height, closeTo(containerHeight, 1.0));
      // Even split: equal share among expanded panes.
      expect(a.height, closeTo(b.height, 1.0));
      expect(
        a.height,
        greaterThan(WorkbenchLayoutConstants.viewPaneHeaderHeight),
      );

      // No pane's internal body scroller can scroll — content is shorter than
      // the allotment.
      final scrollables = tester.widgetList<Scrollable>(
        find.byType(Scrollable),
      );
      for (final scrollable in scrollables) {
        final state = tester.state<ScrollableState>(find.byWidget(scrollable));
        expect(state.position.maxScrollExtent, 0.0);
      }
    });

    testWidgets('a pane whose content exceeds its share scrolls internally; '
        'siblings stay fixed and the container does not scroll', (tester) async {
      const containerHeight = 400.0;
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'tall',
                  title: 'Tall',
                  bodyBuilder: _tallBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'short',
                  title: 'Short',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      // Both panes fit within the container height (fixed-height splitview).
      final tall = paneRect(tester, 'tall');
      final short = paneRect(tester, 'short');
      expect(tall.height + short.height, closeTo(containerHeight, 1.0));

      // The tall pane's body is bounded and scrolls internally — its own
      // viewport can scroll.
      final tallScroller = tester.state<ScrollableState>(
        find.descendant(
          of: find.byKey(const ValueKey('workbench-view-pane-tall')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tallScroller.position.maxScrollExtent, greaterThan(0.0));

      // The short pane's header stays fixed when the tall body scrolls.
      final shortHeaderTopBefore = tester.getTopLeft(find.text('SHORT')).dy;
      await tester.drag(
        find.descendant(
          of: find.byKey(const ValueKey('workbench-view-pane-tall')),
          matching: find.byType(Scrollable),
        ),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      final shortHeaderTopAfter = tester.getTopLeft(find.text('SHORT')).dy;
      expect(shortHeaderTopAfter, closeTo(shortHeaderTopBefore, 0.5));

      // The container itself did not scroll the whole stack: the tall pane is
      // still anchored at the top and the short pane unchanged.
      final tallAfter = paneRect(tester, 'tall');
      final shortAfter = paneRect(tester, 'short');
      expect(tallAfter.top, closeTo(0.0, 0.5));
      expect(shortAfter.height, closeTo(short.height, 0.5));
    });

    testWidgets('collapsing a pane redistributes its freed height to the '
        'expanded siblings', (tester) async {
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithChromeTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'c',
                  title: 'Gamma',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      final aBefore = paneRect(tester, 'a').height;

      // Collapse Gamma.
      await tester.tap(find.text('GAMMA'));
      await tester.pumpAndSettle();

      // Gamma now occupies only its header height.
      expect(
        paneRect(tester, 'c').height,
        closeTo(WorkbenchLayoutConstants.viewPaneHeaderHeight, 0.5),
      );

      // The freed body height flowed to the still-expanded siblings: A grew.
      final aAfter = paneRect(tester, 'a').height;
      expect(aAfter, greaterThan(aBefore));

      // The stack still fills the container height exactly (no whole-stack
      // scroll, no gap).
      final total = paneRect(tester, 'a').height +
          paneRect(tester, 'b').height +
          paneRect(tester, 'c').height;
      expect(total, closeTo(containerHeight, 1.0));
    });

    testWidgets('overflow fallback: the whole stack scrolls only when the '
        'expanded panes cannot fit at their minimum body heights', (
      tester,
    ) async {
      // Three expanded panes need 3 * (header + minBody) of height. Make the
      // container shorter than that so the overflow fallback engages.
      const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;
      const header = WorkbenchLayoutConstants.viewPaneHeaderHeight;
      const containerHeight = 2 * (header + minBody); // room for ~2 of 3.
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'c',
                  title: 'Gamma',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      // The whole stack scrolls as one region: the outer scroll view owns the
      // stack. Its Scrollable is the outermost match under the stack-scroll key.
      final outerScrollable = find
          .descendant(
            of: find.byKey(const ValueKey('workbench-view-stack-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final outer = tester.state<ScrollableState>(outerScrollable);
      expect(outer.position.maxScrollExtent, greaterThan(0.0));

      // Each expanded pane sits at its minimum body height (header + minBody).
      expect(paneRect(tester, 'a').height, closeTo(header + minBody, 1.0));

      // Scrolling the outer region keeps the third pane's header reachable.
      await tester.drag(outerScrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('GAMMA'), findsOneWidget);
    });

    testWidgets('dragging the sash transfers body height between adjacent '
        'expanded panes and the new sizes hold after release', (tester) async {
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      final aBefore = paneRect(tester, 'a').height;
      final bBefore = paneRect(tester, 'b').height;
      // Even split to start.
      expect(aBefore, closeTo(bBefore, 1.0));

      // The sash sits on the boundary between A and B — keyed on the lower
      // pane (the second expanded pane). Drag it down: the upper pane grows
      // and the lower shrinks by the same amount (height is conserved).
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();

      final aAfter = paneRect(tester, 'a').height;
      final bAfter = paneRect(tester, 'b').height;
      // Upper grew, lower shrank.
      expect(aAfter, greaterThan(aBefore + 20));
      expect(bAfter, lessThan(bBefore - 20));
      // The transfer is conserved: whatever A gained, B lost.
      expect(aAfter - aBefore, closeTo(bBefore - bAfter, 1.0));
      // The stack still fills the container exactly.
      expect(aAfter + bAfter, closeTo(containerHeight, 1.0));

      // The manual sizing holds: a rebuild keeps the user-set proportions.
      await tester.pump();
      expect(paneRect(tester, 'a').height, closeTo(aAfter, 1.0));
      expect(paneRect(tester, 'b').height, closeTo(bAfter, 1.0));
    });

    testWidgets('the sash drag is clamped so neither body shrinks below the '
        'minimum body height', (tester) async {
      const minBody = WorkbenchLayoutConstants.viewPaneMinBodyHeight;
      const header = WorkbenchLayoutConstants.viewPaneHeaderHeight;
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      // Drag far past the lower pane's minimum. The lower pane clamps at
      // header + minBody; the upper takes the rest.
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();

      expect(paneRect(tester, 'b').height, closeTo(header + minBody, 1.0));
      expect(
        paneRect(tester, 'a').height,
        closeTo(containerHeight - (header + minBody), 1.0),
      );

      // Drag the other way past the upper pane's minimum: the upper clamps.
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(paneRect(tester, 'a').height, closeTo(header + minBody, 1.0));
      expect(
        paneRect(tester, 'b').height,
        closeTo(containerHeight - (header + minBody), 1.0),
      );
    });

    testWidgets('the sash stays locked to the cursor after overshooting a '
        'clamp — no accumulated offset', (tester) async {
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      final sash = tester.getCenter(
        find.byKey(const ValueKey('workbench-view-sash-b')),
      );
      final gesture = await tester.startGesture(sash);

      // Overshoot far past the lower pane's minimum: the upper pane clamps at
      // its maximum height.
      await gesture.moveBy(const Offset(0, 1000));
      await tester.pump();
      final aClamped = paneRect(tester, 'a').height;

      // Reverse by far less than the overshoot. The cursor is still well past
      // the clamp boundary, so an absolute drag keeps the sash parked — it must
      // NOT pick up the reversal yet (the delta-accumulation bug would shrink
      // the upper pane immediately, offset from the cursor by the overshoot).
      await gesture.moveBy(const Offset(0, -50));
      await tester.pump();
      expect(paneRect(tester, 'a').height, closeTo(aClamped, 0.5));

      // Bring the cursor back near where it started: the sash re-tracks with no
      // accumulated offset, so the split returns toward even.
      await gesture.moveBy(const Offset(0, -900));
      await tester.pump();
      expect(paneRect(tester, 'a').height, lessThan(aClamped - 40));

      await gesture.up();
    });

    testWidgets('the sash cursor reflects the clamp direction', (tester) async {
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      MouseCursor sashCursor() => tester
          .widget<MouseRegion>(
            find.descendant(
              of: find.byKey(const ValueKey('workbench-view-sash-b')),
              matching: find.byType(MouseRegion),
            ),
          )
          .cursor;

      // Free: bidirectional up/down (VS Code ns-resize).
      expect(sashCursor(), SystemMouseCursors.resizeUpDown);

      // Drag down past the lower pane's minimum: only "up" remains → up arrow
      // (VS Code n-resize / .maximum).
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      expect(sashCursor(), SystemMouseCursors.resizeUp);

      // Drag up past the upper pane's minimum: only "down" remains → down arrow
      // (VS Code s-resize / .minimum).
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();
      expect(sashCursor(), SystemMouseCursors.resizeDown);
    });

    testWidgets('a collapsed neighbor has no sash', (tester) async {
      await tester.pumpWidget(
        wrapWithChromeTheme(
          const SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      // Two expanded panes: the second pane carries a sash (the first never
      // does — no expanded pane precedes it).
      expect(
        find.byKey(const ValueKey('workbench-view-sash-a')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        findsOneWidget,
      );

      // Collapse Alpha: Beta's sash disappears — its only expanded neighbor
      // (Alpha) is gone, so there is no body boundary to drag.
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        findsNothing,
      );
    });

    testWidgets('collapsing a pane after an uneven resize fills the height '
        'with no dead space and preserves the survivors\' ratio', (
      tester,
    ) async {
      const header = WorkbenchLayoutConstants.viewPaneHeaderHeight;
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithChromeTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'c',
                  title: 'Gamma',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      // Size A's body clearly taller than B's by dragging the A/B sash down.
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 90),
      );
      await tester.pumpAndSettle();
      final aBody = paneRect(tester, 'a').height - header;
      final bBody = paneRect(tester, 'b').height - header;
      expect(aBody, greaterThan(bBody));
      final ratioBefore = aBody / bBody;

      // Collapse Gamma. Its freed body must be absorbed by the two survivors
      // in proportion to their weights — no dead space at the bottom, and the
      // A:B ratio holds.
      await tester.tap(find.text('GAMMA'));
      await tester.pumpAndSettle();

      // Gamma now occupies only its header height.
      expect(
        paneRect(tester, 'c').height,
        closeTo(header, 0.5),
      );

      // No dead space: the laid-out stack exactly fills the container height.
      final total = paneRect(tester, 'a').height +
          paneRect(tester, 'b').height +
          paneRect(tester, 'c').height;
      expect(total, closeTo(containerHeight, 1.0));

      // The survivors absorbed the freed body in proportion: their ratio holds.
      final aBodyAfter = paneRect(tester, 'a').height - header;
      final bBodyAfter = paneRect(tester, 'b').height - header;
      expect(aBodyAfter, greaterThan(aBody));
      expect(bBodyAfter, greaterThan(bBody));
      expect(aBodyAfter / bBodyAfter, closeTo(ratioBefore, 0.05));
    });

    testWidgets('re-expanding a collapsed pane restores its prior body height '
        'and shrinks the others proportionally', (tester) async {
      const header = WorkbenchLayoutConstants.viewPaneHeaderHeight;
      const containerHeight = 600.0;
      await tester.pumpWidget(
        wrapWithChromeTheme(
          const SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'c',
                  title: 'Gamma',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      // Size A taller than B so the layout is non-trivial.
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 90),
      );
      await tester.pumpAndSettle();
      final cBodyBefore = paneRect(tester, 'c').height - header;
      final aBodyBefore = paneRect(tester, 'a').height - header;
      final bBodyBefore = paneRect(tester, 'b').height - header;

      // Collapse Gamma, then expand it again. VS Code SplitView canon: the
      // re-expanded pane returns to its prior size and the others shrink back.
      await tester.tap(find.text('GAMMA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GAMMA'));
      await tester.pumpAndSettle();

      // Gamma is restored to its prior body height (not reset to even).
      expect(paneRect(tester, 'c').height - header, closeTo(cBodyBefore, 1.5));
      // A and B shrink back to their pre-collapse heights.
      expect(paneRect(tester, 'a').height - header, closeTo(aBodyBefore, 1.5));
      expect(paneRect(tester, 'b').height - header, closeTo(bBodyBefore, 1.5));

      // The stack still fills the container exactly.
      final total = paneRect(tester, 'a').height +
          paneRect(tester, 'b').height +
          paneRect(tester, 'c').height;
      expect(total, closeTo(containerHeight, 1.0));
    });

    testWidgets('controlled sizes: a sash drag notifies without self-mutating, '
        'and the host-supplied map drives apportionment', (tester) async {
      const header = WorkbenchLayoutConstants.viewPaneHeaderHeight;
      const containerHeight = 600.0;
      Map<String, double>? reported;
      // Controlled from the start: an even split of the body pool drives the
      // initial apportionment so the container is in controlled mode for the
      // first drag (a null map would fall back to the shell-owned default).
      final evenBody = (containerHeight - 2 * header) / 2;
      Map<String, double>? hostSizes = {'a': evenBody, 'b': evenBody};
      Widget build() => wrapWithTheme(
        SizedBox(
          height: containerHeight,
          child: WorkbenchViewContainer(
            sizes: hostSizes,
            onSizesChanged: (next) => reported = next,
            views: const [
              WorkbenchViewDescriptor(
                id: 'a',
                title: 'Alpha',
                bodyBuilder: _shortBody,
              ),
              WorkbenchViewDescriptor(
                id: 'b',
                title: 'Beta',
                bodyBuilder: _shortBody,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(build());

      final aBefore = paneRect(tester, 'a').height;
      final bBefore = paneRect(tester, 'b').height;
      expect(aBefore, closeTo(bBefore, 1.0));

      // Drag the sash. In controlled mode the shell does NOT self-mutate; the
      // on-screen apportionment is unchanged until the host pushes a new map.
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();

      expect(reported, isNotNull);
      // The notification carries the full next sizes map with both neighbors.
      expect(reported!.containsKey('a'), isTrue);
      expect(reported!.containsKey('b'), isTrue);
      expect(reported!['a']!, greaterThan(reported!['b']!));
      // No self-mutation: the render is unchanged from before the drag.
      expect(paneRect(tester, 'a').height, closeTo(aBefore, 1.0));
      expect(paneRect(tester, 'b').height, closeTo(bBefore, 1.0));

      // The host applies the reported map → the render follows it.
      hostSizes = reported;
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      // Body heights match the supplied apportionment (pane = header + body).
      expect(
        paneRect(tester, 'a').height,
        closeTo(header + hostSizes!['a']!, 1.0),
      );
      expect(
        paneRect(tester, 'b').height,
        closeTo(header + hostSizes['b']!, 1.0),
      );
    });

    testWidgets('uncontrolled sizes still drag the shell-owned apportionment '
        'and fire onSizesChanged', (tester) async {
      const containerHeight = 600.0;
      Map<String, double>? reported;
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(
            height: containerHeight,
            child: WorkbenchViewContainer(
              onSizesChanged: (next) => reported = next,
              views: const [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      final aBefore = paneRect(tester, 'a').height;
      final bBefore = paneRect(tester, 'b').height;

      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();

      // Shell-owned apportionment updated on screen (existing behavior).
      final aAfter = paneRect(tester, 'a').height;
      final bAfter = paneRect(tester, 'b').height;
      expect(aAfter, greaterThan(aBefore + 20));
      expect(bAfter, lessThan(bBefore - 20));
      // And the optional notification fired with the new map.
      expect(reported, isNotNull);
      expect(reported!['a']!, greaterThan(reported!['b']!));
    });

    testWidgets('dragging a pane header reorders the shell-owned stack and '
        'reports the move', (tester) async {
      const views = <WorkbenchViewDescriptor>[
        WorkbenchViewDescriptor(id: 'a', title: 'Alpha', bodyBuilder: _shortBody),
        WorkbenchViewDescriptor(id: 'b', title: 'Beta', bodyBuilder: _shortBody),
        WorkbenchViewDescriptor(id: 'c', title: 'Gamma', bodyBuilder: _shortBody),
      ];
      (int, int)? reported;

      // The host does NOT manage order — the shell owns it. onReorder is an
      // optional notification (e.g. for persistence), not a control input; it
      // does not re-supply the views list.
      await tester.pumpWidget(
        wrapWithChromeTheme(
          SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: views,
              onReorder: (oldIndex, newIndex) => reported = (oldIndex, newIndex),
            ),
          ),
        ),
      );

      // Initial order: Alpha, Beta, Gamma.
      final alphaTop0 = tester.getTopLeft(find.text('ALPHA')).dy;
      final betaTop0 = tester.getTopLeft(find.text('BETA')).dy;
      final gammaTop0 = tester.getTopLeft(find.text('GAMMA')).dy;
      expect(alphaTop0, lessThan(betaTop0));
      expect(betaTop0, lessThan(gammaTop0));

      // Drag the third pane (Gamma) header up onto the first pane (Alpha):
      // dropping on Alpha's top half inserts Gamma before Alpha.
      final gammaHeader = tester.getCenter(find.text('GAMMA'));
      final alphaCenter = tester.getCenter(
        find.byKey(const ValueKey('workbench-view-pane-a')),
      );
      final gesture = await tester.startGesture(gammaHeader);
      await tester.pump(const Duration(milliseconds: 200));
      // Move toward Alpha's top half.
      await gesture.moveTo(Offset(alphaCenter.dx, alphaCenter.dy - 8));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Notified of the move (Gamma index 2 → 0)…
      expect(reported, (2, 0));
      // …and the shell itself reordered the rendered stack: Gamma, Alpha, Beta.
      final gammaTop1 = tester.getTopLeft(find.text('GAMMA')).dy;
      final alphaTop1 = tester.getTopLeft(find.text('ALPHA')).dy;
      final betaTop1 = tester.getTopLeft(find.text('BETA')).dy;
      expect(gammaTop1, lessThan(alphaTop1));
      expect(alphaTop1, lessThan(betaTop1));
    });

    testWidgets('reorder needs no onReorder — the shell owns the order', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithChromeTheme(
          const SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.text('ALPHA')).dy,
        lessThan(tester.getTopLeft(find.text('BETA')).dy),
      );

      // Drag Beta's header onto Alpha's top half → Beta before Alpha, with no
      // host order state and no onReorder callback at all.
      final betaHeader = tester.getCenter(find.text('BETA'));
      final alphaCenter = tester.getCenter(
        find.byKey(const ValueKey('workbench-view-pane-a')),
      );
      final gesture = await tester.startGesture(betaHeader);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(Offset(alphaCenter.dx, alphaCenter.dy - 8));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(find.text('BETA')).dy,
        lessThan(tester.getTopLeft(find.text('ALPHA')).dy),
      );
    });

    testWidgets('a drop indicator overlay shows the target slot during a drag', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrapWithChromeTheme(
          const SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
                WorkbenchViewDescriptor(
                  id: 'b',
                  title: 'Beta',
                  bodyBuilder: _shortBody,
                ),
              ],
              onReorder: _noopReorder,
            ),
          ),
        ),
      );

      // No drop indicator before a drag begins.
      expect(
        find.byKey(const ValueKey('workbench-view-drop-indicator')),
        findsNothing,
      );

      // Start dragging Alpha's header and move over Beta.
      final alphaHeader = tester.getCenter(find.text('ALPHA'));
      final betaCenter = tester.getCenter(
        find.byKey(const ValueKey('workbench-view-pane-b')),
      );
      final gesture = await tester.startGesture(alphaHeader);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(Offset(betaCenter.dx, betaCenter.dy + 8));
      await tester.pump();

      // The drop indicator overlay is shown over the hovered target slot.
      expect(
        find.byKey(const ValueKey('workbench-view-drop-indicator')),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pumpAndSettle();

      // It vanishes once the drag ends.
      expect(
        find.byKey(const ValueKey('workbench-view-drop-indicator')),
        findsNothing,
      );
    });

    testWidgets('a single-view container is not reorderable (no drop handle)', (
      tester,
    ) async {
      // Reorder needs distinct slots, so a lone (non-collapsible) pane has no
      // drag handle — its header cannot move (§spec:view-stack).
      await tester.pumpWidget(
        wrapWithChromeTheme(
          const SizedBox(
            height: 600,
            child: WorkbenchViewContainer(
              views: [
                WorkbenchViewDescriptor(
                  id: 'a',
                  title: 'Alpha',
                  bodyBuilder: _shortBody,
                ),
              ],
            ),
          ),
        ),
      );

      final alphaHeader = tester.getCenter(find.text('ALPHA'));
      final gesture = await tester.startGesture(alphaHeader);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(Offset(alphaHeader.dx, alphaHeader.dy + 60));
      await tester.pump();

      // No reorder machinery for a single pane: no drop indicator appears.
      expect(
        find.byKey(const ValueKey('workbench-view-drop-indicator')),
        findsNothing,
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('a controlled order defers to the host: a drag notifies but '
        'does not self-reorder', (tester) async {
      (int, int)? reported;
      Widget build(List<String> order) => wrapWithChromeTheme(
        SizedBox(
          height: 600,
          child: WorkbenchViewContainer(
            order: order,
            onReorder: (oldIndex, newIndex) => reported = (oldIndex, newIndex),
            views: const [
              WorkbenchViewDescriptor(
                id: 'a',
                title: 'Alpha',
                bodyBuilder: _shortBody,
              ),
              WorkbenchViewDescriptor(
                id: 'b',
                title: 'Beta',
                bodyBuilder: _shortBody,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(build(const ['a', 'b']));
      expect(
        tester.getTopLeft(find.text('ALPHA')).dy,
        lessThan(tester.getTopLeft(find.text('BETA')).dy),
      );

      // Drag Beta onto Alpha's top half.
      final betaHeader = tester.getCenter(find.text('BETA'));
      final alphaCenter = tester.getCenter(
        find.byKey(const ValueKey('workbench-view-pane-a')),
      );
      final gesture = await tester.startGesture(betaHeader);
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveTo(Offset(alphaCenter.dx, alphaCenter.dy - 8));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Reports the move, but the shell does NOT self-reorder — the controlled
      // order still renders Alpha, Beta until the host pushes a new order.
      expect(reported, (1, 0));
      expect(
        tester.getTopLeft(find.text('ALPHA')).dy,
        lessThan(tester.getTopLeft(find.text('BETA')).dy),
      );

      // Host applies the move → the render follows.
      await tester.pumpWidget(build(const ['b', 'a']));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('BETA')).dy,
        lessThan(tester.getTopLeft(find.text('ALPHA')).dy),
      );
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

  group('WorkbenchViewContainer header focus traversal (§spec:view-pane-focus)', () {
    // The container moves focus between header focus stops on Down/Up. Each
    // pane carries one focus-ring DecoratedBox, painted focusBorder while
    // focused; the ring inside pane [id]'s keyed subtree reports which header
    // owns focus.
    const paneRingKey = ValueKey('view-pane-header-focus-ring');

    Color ringColorOf(WidgetTester tester, String id) {
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(ValueKey('workbench-view-pane-$id')),
          matching: find.byKey(paneRingKey),
        ),
      );
      return ((box.decoration as BoxDecoration).border! as Border).top.color;
    }

    bool isFocused(WidgetTester tester, String id) =>
        ringColorOf(tester, id) == testWorkbenchTheme.focusBorder;

    Future<void> pumpStack(
      WidgetTester tester,
      List<WorkbenchViewDescriptor> views,
    ) async {
      await tester.pumpWidget(
        wrapWithTheme(
          SizedBox(height: 600, child: WorkbenchViewContainer(views: views)),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<WorkbenchViewDescriptor> threeViews() => [
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
    ];

    testWidgets('Down walks forward through headers and clamps at the last', (
      tester,
    ) async {
      await pumpStack(tester, threeViews());

      // Focus the first header by clicking it. Clicking a collapsible header
      // toggles it, so re-expand to keep the stack expanded for the test.
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'a'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'b'), isTrue);
      expect(isFocused(tester, 'a'), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'c'), isTrue);

      // Down on the last header is a no-op: focus stays on the last (no wrap).
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'c'), isTrue);
      expect(isFocused(tester, 'a'), isFalse);
    });

    testWidgets('clicking a sash-wrapped header keeps focus on it through the '
        'collapse reparent', (tester) async {
      // Regression (§spec:view-pane-focus): an expanded non-first pane is
      // wrapped in a sash Stack; collapsing it on click removes that wrapper,
      // reparenting the pane and rebuilding its State — which detaches the
      // header Focus and drops the focus the click just placed. A stable key on
      // the pane must move the element instead, so the ring stays and Up/Down
      // resume from the clicked header. The standalone-pane focus tests miss
      // this: only the container adds the sash wrapper.
      await pumpStack(tester, threeViews());

      // Beta has a sash above it (Alpha is expanded). Clicking toggles Beta
      // collapsed and must leave focus on Beta's header.
      await tester.tap(find.text('BETA'));
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'b'), isTrue);
      expect(isFocused(tester, 'a'), isFalse);

      // Focus was seeded on Beta, so Down resumes from there → Gamma, not from
      // the top of the stack.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'c'), isTrue);
    });

    testWidgets('a tap outside a focused header clears its ring', (
      tester,
    ) async {
      // §spec:view-pane-focus: focus does not linger. Flutter keeps focus until
      // another control claims it; the header drops it on a tap outside so the
      // ring does not stay on a header the user has left.
      await pumpStack(tester, threeViews());

      // Focus Beta by clicking it (also collapses it; focus stays on its header).
      await tester.tap(find.text('BETA'));
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'b'), isTrue);

      // Tap a non-header surface — Alpha's still-visible body — and Beta's ring
      // clears.
      await tester.tap(find.text('body-a'));
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'b'), isFalse);
    });

    testWidgets('Up walks back through headers and clamps at the first', (
      tester,
    ) async {
      await pumpStack(tester, threeViews());

      // Drive focus to the last header via Down, then walk back with Up.
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'c'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'b'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'a'), isTrue);

      // Up on the first header is a no-op: focus stays on the first.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'a'), isTrue);
      expect(isFocused(tester, 'b'), isFalse);
    });

    testWidgets('traversal does not engage with a single view', (tester) async {
      await pumpStack(tester, [
        WorkbenchViewDescriptor(
          id: 'solo',
          title: 'Solo',
          bodyBuilder: (_) => const Text('body-solo'),
        ),
      ]);

      // A lone non-collapsible header is focusable; click focuses it.
      await tester.tap(find.text('SOLO'));
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'solo'), isTrue);

      // No second header exists, so Down/Up are no-ops: focus stays put.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'solo'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'solo'), isTrue);
    });

    testWidgets('Down/Up move focus only, never toggling expansion', (
      tester,
    ) async {
      await pumpStack(tester, threeViews());

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      // All bodies visible (every pane expanded).
      expect(find.text('body-a'), findsOneWidget);
      expect(find.text('body-b'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      // Traversal moved the ring but left every pane expanded.
      expect(isFocused(tester, 'b'), isTrue);
      expect(find.text('body-a'), findsOneWidget);
      expect(find.text('body-b'), findsOneWidget);
      expect(find.text('body-c'), findsOneWidget);
    });

    testWidgets('clamping does not escape to focusables outside the stack', (
      tester,
    ) async {
      // Outer focus stops bracket the container. Strict clamp (§spec:view-pane-focus)
      // means Down on the last header and Up on the first stay on the header —
      // focus never escapes to the surrounding controls.
      final outerAbove = FocusNode(debugLabel: 'outer-above');
      final outerBelow = FocusNode(debugLabel: 'outer-below');
      addTearDown(outerAbove.dispose);
      addTearDown(outerBelow.dispose);
      await tester.pumpWidget(
        wrapWithTheme(
          Column(
            children: [
              Focus(focusNode: outerAbove, child: const SizedBox(height: 20)),
              SizedBox(
                height: 500,
                child: WorkbenchViewContainer(views: threeViews()),
              ),
              Focus(focusNode: outerBelow, child: const SizedBox(height: 20)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();

      // Up on the first header clamps — does not escape to outerAbove.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'a'), isTrue);
      expect(outerAbove.hasFocus, isFalse);

      // Down to the last, then Down again clamps — does not escape to outerBelow.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'c'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'c'), isTrue);
      expect(outerBelow.hasFocus, isFalse);
    });

    testWidgets('Down skips focusable pane bodies, landing only on headers', (
      tester,
    ) async {
      // Bodies host their own focusable controls. Traversal is over the
      // headers only (§spec:view-pane-focus) — Down must skip the body's
      // focus stop and land on the next header, never descend into the body.
      await pumpStack(tester, [
        WorkbenchViewDescriptor(
          id: 'a',
          title: 'Alpha',
          bodyBuilder: (_) => const TextField(key: ValueKey('field-a')),
        ),
        WorkbenchViewDescriptor(
          id: 'b',
          title: 'Beta',
          bodyBuilder: (_) => const TextField(key: ValueKey('field-b')),
        ),
      ]);

      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'a'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      // Landed on the second header, not Alpha's body field.
      expect(isFocused(tester, 'b'), isTrue);
      expect(
        tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('field-a')),
            matching: find.byType(EditableText),
          ),
        ).focusNode.hasFocus,
        isFalse,
      );
    });

    testWidgets('a collapsed pane keeps its header as a traversal target', (
      tester,
    ) async {
      await pumpStack(tester, threeViews());

      // Collapse the middle pane (click toggles it).
      await tester.tap(find.text('BETA'));
      await tester.pumpAndSettle();
      expect(find.text('body-b'), findsNothing);

      // Focus the first header (re-expand after the toggling click), then
      // traverse: Down still lands on the collapsed pane's header.
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ALPHA'));
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'a'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'b'), isTrue);
      // Still collapsed — traversal did not expand it.
      expect(find.text('body-b'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(isFocused(tester, 'c'), isTrue);
    });
  });
}

/// Short body: well under any minimum body allotment, so its pane never engages
/// internal scroll in a tall container.
Widget _shortBody(BuildContext _) => const Text('short');

/// No-op reorder callback: enables the drag machinery without mutating order.
void _noopReorder(int oldIndex, int newIndex) {}

/// Tall body: far exceeds any plausible apportioned height, so its pane bounds
/// the body and scrolls internally.
Widget _tallBody(BuildContext _) =>
    const SizedBox(height: 2000, child: Text('tall-top'));

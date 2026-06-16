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

    testWidgets('collapse then expand redistributes evenly after a manual '
        'resize', (tester) async {
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

      // Manually resize the A/B boundary so they are no longer even.
      await tester.drag(
        find.byKey(const ValueKey('workbench-view-sash-b')),
        const Offset(0, 50),
      );
      await tester.pumpAndSettle();
      expect(
        paneRect(tester, 'a').height,
        greaterThan(paneRect(tester, 'b').height),
      );

      // Collapse Gamma, then expand it again. Re-apportionment is sensible:
      // the re-expanded pane gets a fair (even) share alongside the others.
      await tester.tap(find.text('GAMMA'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GAMMA'));
      await tester.pumpAndSettle();

      // Gamma is expanded again with a real body share, and the stack fills.
      final total = paneRect(tester, 'a').height +
          paneRect(tester, 'b').height +
          paneRect(tester, 'c').height;
      expect(total, closeTo(containerHeight, 1.0));
      expect(
        paneRect(tester, 'c').height,
        greaterThan(WorkbenchLayoutConstants.viewPaneHeaderHeight + 1),
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
}

/// Short body: well under any minimum body allotment, so its pane never engages
/// internal scroll in a tall container.
Widget _shortBody(BuildContext _) => const Text('short');

/// Tall body: far exceeds any plausible apportioned height, so its pane bounds
/// the body and scrolls internally.
Widget _tallBody(BuildContext _) =>
    const SizedBox(height: 2000, child: Text('tall-top'));

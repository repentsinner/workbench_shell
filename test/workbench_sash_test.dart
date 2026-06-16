import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/src/workbench_sash.dart';

/// Pump a static [WorkbenchSash] at [value] for cursor assertions.
Future<void> pumpSash(
  WidgetTester tester, {
  required Axis axis,
  required double growSign,
  required double value,
  double min = 100,
  double max = 300,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: WorkbenchSash(
            key: const Key('sash'),
            axis: axis,
            value: value,
            min: min,
            max: max,
            growSign: growSign,
            onChanged: (_) {},
            child: const SizedBox(width: 24, height: 24),
          ),
        ),
      ),
    ),
  );
}

MouseCursor sashCursor(WidgetTester tester) => tester
    .widget<MouseRegion>(
      find
          .descendant(
            of: find.byKey(const Key('sash')),
            matching: find.byType(MouseRegion),
          )
          .first,
    )
    .cursor;

void main() {
  group('WorkbenchSash cursor', () {
    testWidgets('horizontal (grow right) reflects the clamp state', (
      tester,
    ) async {
      // Free: bidirectional (VS Code ew-resize).
      await pumpSash(tester, axis: Axis.horizontal, growSign: 1, value: 200);
      expect(sashCursor(tester), SystemMouseCursors.resizeLeftRight);

      // At min: only "grow right" remains → right arrow (e-resize / .minimum).
      await pumpSash(tester, axis: Axis.horizontal, growSign: 1, value: 100);
      expect(sashCursor(tester), SystemMouseCursors.resizeRight);

      // At max: only "shrink left" remains → left arrow (w-resize / .maximum).
      await pumpSash(tester, axis: Axis.horizontal, growSign: 1, value: 300);
      expect(sashCursor(tester), SystemMouseCursors.resizeLeft);
    });

    testWidgets('vertical (grow up) reflects the clamp state', (tester) async {
      // Free: bidirectional (VS Code ns-resize).
      await pumpSash(tester, axis: Axis.vertical, growSign: -1, value: 200);
      expect(sashCursor(tester), SystemMouseCursors.resizeUpDown);

      // At min: panel grows by dragging up → up arrow.
      await pumpSash(tester, axis: Axis.vertical, growSign: -1, value: 100);
      expect(sashCursor(tester), SystemMouseCursors.resizeUp);

      // At max: only shrink (drag down) remains → down arrow.
      await pumpSash(tester, axis: Axis.vertical, growSign: -1, value: 300);
      expect(sashCursor(tester), SystemMouseCursors.resizeDown);
    });
  });

  testWidgets('drag is absolute-anchored: overshoot parks at the clamp, then '
      're-tracks without offset', (tester) async {
    var value = 200.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => WorkbenchSash(
                key: const Key('sash'),
                axis: Axis.horizontal,
                value: value,
                min: 100,
                max: 300,
                growSign: 1,
                onChanged: (next) => setState(() => value = next),
                child: const SizedBox(width: 24, height: 24),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sash'))),
    );

    // Overshoot far past the max: value clamps.
    await gesture.moveBy(const Offset(500, 0));
    await tester.pump();
    expect(value, 300);

    // Reverse by far less than the overshoot. The pointer is still well past
    // the clamp, so the sash stays parked — a delta-accumulating drag would
    // drop below the max here (trailing the cursor by the overshoot).
    await gesture.moveBy(const Offset(-50, 0));
    await tester.pump();
    expect(value, 300);

    // Bring the pointer back near the start: the value re-tracks off the clamp.
    await gesture.moveBy(const Offset(-450, 0));
    await tester.pump();
    expect(value, lessThan(290));

    await gesture.up();
  });
}

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/src/workbench_sash.dart';

import 'test_theme.dart';

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

  testWidgets('highlight: none idle, subtle on hover, full while dragging', (
    tester,
  ) async {
    const sashColor = Color(0xFF44AAFF);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [
            testWorkbenchTheme.copyWith(sashHoverBorder: sashColor),
          ],
        ),
        home: Scaffold(
          body: Center(
            child: WorkbenchSash(
              key: const Key('sash'),
              axis: Axis.horizontal,
              growSign: 1,
              value: 200,
              min: 100,
              max: 300,
              onChanged: (_) {},
              child: const SizedBox(width: 24, height: 24),
            ),
          ),
        ),
      ),
    );

    Color? bandColor() {
      final boxes = tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byKey(const Key('sash')),
          matching: find.byType(ColoredBox),
        ),
      );
      return boxes.isEmpty ? null : boxes.first.color;
    }

    // Idle: no highlight band.
    expect(bandColor(), isNull);

    // Hover: a subtle (half-alpha) band of the sash color.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(const Key('sash'))));
    await tester.pump();
    expect(bandColor(), sashColor.withValues(alpha: sashColor.a * 0.5));

    // Dragging: the full color.
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('sash'))),
    );
    await drag.moveBy(const Offset(10, 0));
    await tester.pump();
    expect(bandColor(), sashColor);
    await drag.up();
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

  testWidgets('onChangeEnd fires once on release with the final clamped value, '
      'never per frame (§spec:resize-geometry)', (tester) async {
    var value = 200.0;
    final ends = <double>[];
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
                onChangeEnd: ends.add,
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

    // Several frames of movement: onChangeEnd stays silent throughout.
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(ends, isEmpty);

    // Release: exactly one commit, carrying the final clamped value.
    await gesture.up();
    await tester.pump();
    expect(ends, [value]);
    expect(value, 240);
  });

  group('double-click reset (§spec:workbench-layout)', () {
    Widget buildResettable({
      required VoidCallback onReset,
      ValueChanged<double>? onChangeEnd,
      ValueChanged<double>? onChanged,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: WorkbenchSash(
              key: const Key('sash'),
              axis: Axis.horizontal,
              value: 200,
              min: 100,
              max: 300,
              growSign: 1,
              onChanged: onChanged ?? (_) {},
              onChangeEnd: onChangeEnd,
              onReset: onReset,
              child: const SizedBox(width: 24, height: 24),
            ),
          ),
        ),
      );
    }

    testWidgets('a double-click fires onReset', (tester) async {
      var resets = 0;
      await tester.pumpWidget(buildResettable(onReset: () => resets++));

      final center = tester.getCenter(find.byKey(const Key('sash')));
      await tester.tapAt(center);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(center);
      await tester.pump();

      expect(resets, 1);
    });

    testWidgets('onReset present does not delay the live drag — the first move '
        'updates immediately (no double-tap arbiter in the arena)', (
      tester,
    ) async {
      var value = 200.0;
      await tester.pumpWidget(
        buildResettable(
          onReset: () {},
          onChanged: (n) => value = n,
        ),
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('sash'))),
      );
      // A single move must register live — a DoubleTapGestureRecognizer would
      // hold the arena and swallow this first delta.
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(value, 240);
      await gesture.up();
    });

    testWidgets('a stationary click does not commit a no-op onChangeEnd', (
      tester,
    ) async {
      final ends = <double>[];
      await tester.pumpWidget(
        buildResettable(onReset: () {}, onChangeEnd: ends.add),
      );

      await tester.tapAt(tester.getCenter(find.byKey(const Key('sash'))));
      await tester.pump();

      expect(ends, isEmpty);
    });
  });
}

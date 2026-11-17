import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';
import 'package:workbench_shell_example/main.dart';

const Duration _tick = Duration(milliseconds: 50);
const Duration _patience = Duration(minutes: 2);

/// The app content size the README recording captures, in logical pixels.
const Size _recordingSize = Size(1020, 510);

/// Pumps frames until [done] holds, failing after [_patience].
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var waited = Duration.zero; !done(); waited += _tick) {
    if (waited > _patience) fail('condition not met within $_patience');
    await tester.pump(_tick);
  }
}

WorkbenchLayout _layout(WidgetTester tester) =>
    tester.widget<WorkbenchLayout>(find.byType(WorkbenchLayout));

WorkbenchThemeController _themes(WidgetTester tester) =>
    tester.widget<WorkbenchHome>(find.byType(WorkbenchHome)).themeController;

/// Counts the tour's cycle markers while a test runs.
int _cycleMarkers = 0;

/// Defines a widget test that counts the tour's cycle markers. The test
/// harness checks that `debugPrint` is restored before tear-down runs, so
/// the body restores it itself.
void _testTour(String description, WidgetTesterCallback body) {
  testWidgets(description, (tester) async {
    // The bundle caches each asset's load future. One cached by an earlier
    // test belongs to that test's fake clock and never completes here, which
    // would stall the tour's first theme pick.
    rootBundle.clear();
    // Lay out at the size the README recording captures, so the controls the
    // tour taps are on screen exactly when they are in the recording.
    tester.view.physicalSize = _recordingSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    _cycleMarkers = 0;
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message?.startsWith('tour cycle start') ?? false) _cycleMarkers++;
    };
    try {
      await body(tester);
    } finally {
      debugPrint = originalDebugPrint;
    }
  });
}

void main() {
  /// Pumps until the tour starts its second cycle, calling [observe] on
  /// every frame of the first.
  Future<void> runOneCycle(WidgetTester tester, void Function() observe) {
    return _pumpUntil(tester, () {
      observe();
      return _cycleMarkers >= 2;
    });
  }

  _testTour('the tour shows several themes and returns to the first', (
    tester,
  ) async {
    await tester.pumpWidget(const WorkbenchExampleApp(tour: true));

    final seen = <String>{};
    await runOneCycle(tester, () => seen.add(_themes(tester).selectedFilename));

    expect(seen.length, greaterThanOrEqualTo(4));
    expect(seen, contains('light_modern.json'));
    expect(_themes(tester).selectedFilename, 'dark_modern.json');
  });

  _testTour('the tour opens the Settings view container', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp(tour: true));

    var sawSettings = false;
    await runOneCycle(tester, () {
      sawSettings |= find
          .text('Preferred dark color theme')
          .evaluate()
          .isNotEmpty;
    });

    expect(sawSettings, isTrue);
  });

  _testTour('the tour switches the bottom panel to Terminal', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp(tour: true));

    var sawTerminal = false;
    await runOneCycle(tester, () {
      sawTerminal |= find.textContaining('Terminal tab').evaluate().isNotEmpty;
    });

    expect(sawTerminal, isTrue);
  });

  _testTour('the tour posts a warning and clears it', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp(tour: true));

    var sawWarning = false;
    await runOneCycle(tester, () {
      sawWarning |=
          tester
              .widget<WorkbenchStatusBarProblemsItem>(
                find.byType(WorkbenchStatusBarProblemsItem),
              )
              .warningCount >
          0;
    });

    expect(sawWarning, isTrue);
    expect(
      tester
          .widget<WorkbenchStatusBarProblemsItem>(
            find.byType(WorkbenchStatusBarProblemsItem),
          )
          .warningCount,
      0,
    );
  });

  _testTour('the tour rearranges the layout and restores it', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp(tour: true));

    var sawSecondary = false;
    var sawRight = false;
    var sawFlat = false;
    await runOneCycle(tester, () {
      final layout = _layout(tester);
      sawSecondary |= layout.secondarySideBarVisible ?? false;
      sawRight |= layout.sidebarPosition == WorkbenchSidebarPosition.right;
      sawFlat |= layout.modernUI == false;
    });

    expect(sawSecondary, isTrue);
    expect(sawRight, isTrue);
    expect(sawFlat, isTrue);
    final layout = _layout(tester);
    expect(layout.secondarySideBarVisible, isFalse);
    expect(layout.sidebarPosition, WorkbenchSidebarPosition.left);
    expect(layout.modernUI, isTrue);
  });

  _testTour('without the tour flag the app stays put', (tester) async {
    await tester.pumpWidget(const WorkbenchExampleApp());
    await tester.pumpAndSettle();
    final theme = _themes(tester).selectedFilename;

    await tester.pump(const Duration(seconds: 30));

    expect(_cycleMarkers, 0);
    expect(_themes(tester).selectedFilename, theme);
    expect(_layout(tester).secondarySideBarVisible, isFalse);
    expect(find.text('Preferred dark color theme'), findsNothing);
  });
}

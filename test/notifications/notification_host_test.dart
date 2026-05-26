// Widget tests for the NotificationHost overlay (SPEC §10).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import '../test_theme.dart';

Widget _host(NotificationService service, {Widget? child}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: [testWorkbenchTheme]),
    home: Scaffold(
      body: NotificationHost(service: service, child: child),
    ),
  );
}

void main() {
  group('NotificationHost rendering', () {
    testWidgets('shows nothing when the service has no notifications', (
      tester,
    ) async {
      final service = NotificationService();
      await tester.pumpWidget(_host(service));
      expect(find.text('Clear All'), findsNothing);
      // No card text either.
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('renders a single card for a single info notification', (
      tester,
    ) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'Saved.');
      await tester.pumpWidget(_host(service));
      await tester.pump();
      expect(find.text('Saved.'), findsOneWidget);
      // Single card, no Clear All control.
      expect(find.text('Clear All'), findsNothing);
    });

    testWidgets('renders Clear All when at least two cards exist', (
      tester,
    ) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'A');
      service.show(severity: NotificationSeverity.info, message: 'B');
      await tester.pumpWidget(_host(service));
      await tester.pump();
      expect(find.text('Clear All'), findsOneWidget);
    });

    testWidgets('renders newest at the bottom of the stack', (tester) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'oldest');
      service.show(severity: NotificationSeverity.info, message: 'middle');
      service.show(severity: NotificationSeverity.info, message: 'newest');
      await tester.pumpWidget(_host(service));
      await tester.pump();

      final oldest = tester.getCenter(find.text('oldest'));
      final newest = tester.getCenter(find.text('newest'));
      expect(newest.dy, greaterThan(oldest.dy));
    });

    testWidgets('Clear All dismisses every notification', (tester) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'A');
      service.show(severity: NotificationSeverity.warning, message: 'B');
      await tester.pumpWidget(_host(service));
      await tester.pump();
      expect(service.notifications, hasLength(2));

      await tester.tap(find.text('Clear All'));
      await tester.pump();
      expect(service.notifications, isEmpty);
    });
  });

  group('NotificationHost auto-dismiss', () {
    testWidgets('info notification self-dismisses after 6 seconds', (
      tester,
    ) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'A');
      await tester.pumpWidget(_host(service));
      await tester.pump();
      expect(service.notifications, hasLength(1));

      // Wait 5s — still visible.
      await tester.pump(const Duration(seconds: 5));
      expect(service.notifications, hasLength(1));

      // Wait the remaining ~1.2s — the timer fires, the dismiss is
      // scheduled at animation priority, then the rebuild lands.
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(service.notifications, isEmpty);
    });

    testWidgets('error notification persists indefinitely', (tester) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.error, message: 'Bad');
      await tester.pumpWidget(_host(service));
      await tester.pump();

      await tester.pump(const Duration(seconds: 30));
      expect(service.notifications, hasLength(1));
    });

    testWidgets('warning notification persists indefinitely', (tester) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.warning, message: 'Hmm');
      await tester.pumpWidget(_host(service));
      await tester.pump();

      await tester.pump(const Duration(seconds: 30));
      expect(service.notifications, hasLength(1));
    });

    testWidgets('hover pauses the auto-dismiss timer', (tester) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'Hold me');
      await tester.pumpWidget(_host(service));
      await tester.pump();

      // Move pointer onto the card.
      final card = tester.getCenter(find.text('Hold me'));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: const Offset(0, 0));
      await gesture.moveTo(card);
      await tester.pump();

      // Wait well past the 6 s budget. The card stays.
      await tester.pump(const Duration(seconds: 10));
      expect(service.notifications, hasLength(1));

      // Leave the card — the timer resumes.
      await gesture.moveTo(const Offset(0, 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(service.notifications, isEmpty);

      await gesture.removePointer();
    });

    testWidgets('losing window focus pauses the timer', (tester) async {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'Bg');
      await tester.pumpWidget(_host(service));
      await tester.pump();

      // Background the app.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      // Wait well past the budget.
      await tester.pump(const Duration(seconds: 10));
      expect(service.notifications, hasLength(1));

      // Refocus.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();
      expect(service.notifications, isEmpty);
    });
  });

  group('NotificationHost actions', () {
    testWidgets('action callback fires and the card dismisses in the same '
        'frame', (tester) async {
      final service = NotificationService();
      var invoked = 0;
      service.show(
        severity: NotificationSeverity.info,
        message: 'Confirm?',
        actions: [NotificationAction(label: 'Undo', onInvoke: () => invoked++)],
      );
      await tester.pumpWidget(_host(service));
      await tester.pump();

      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(invoked, 1);
      expect(service.notifications, isEmpty);
    });
  });

  group('NotificationHost overflow', () {
    testWidgets('shows +N more when more than five cards exist', (
      tester,
    ) async {
      final service = NotificationService();
      for (var i = 0; i < 7; i++) {
        service.show(severity: NotificationSeverity.info, message: 'Card $i');
      }
      await tester.pumpWidget(_host(service));
      await tester.pump();
      // Two cards overflow.
      expect(find.text('+2 more'), findsOneWidget);
      // The five newest cards (2–6) are visible.
      expect(find.text('Card 6'), findsOneWidget);
      expect(find.text('Card 2'), findsOneWidget);
      // The two oldest are hidden until the summary is expanded.
      expect(find.text('Card 0'), findsNothing);
      expect(find.text('Card 1'), findsNothing);
    });

    testWidgets('tapping the summary expands overflow into a scrollable list', (
      tester,
    ) async {
      final service = NotificationService();
      for (var i = 0; i < 7; i++) {
        service.show(severity: NotificationSeverity.info, message: 'Card $i');
      }
      await tester.pumpWidget(_host(service));
      await tester.pump();

      await tester.tap(find.text('+2 more'));
      await tester.pump();

      // The previously-hidden cards appear.
      expect(find.text('Card 0'), findsOneWidget);
      expect(find.text('Card 1'), findsOneWidget);
    });

    testWidgets(
      'persistent cards stay visible and push transients into overflow',
      (tester) async {
        final service = NotificationService();
        // Warning + two infos + three more infos → 6 total, persistent
        // warning must stay visible.
        service.show(
          severity: NotificationSeverity.warning,
          message: 'persistent-warn',
        );
        service.show(severity: NotificationSeverity.info, message: 'i1');
        service.show(severity: NotificationSeverity.info, message: 'i2');
        service.show(severity: NotificationSeverity.info, message: 'i3');
        service.show(severity: NotificationSeverity.info, message: 'i4');
        service.show(severity: NotificationSeverity.info, message: 'i5');
        await tester.pumpWidget(_host(service));
        await tester.pump();

        // 6 total, budget 5 → 1 transient overflows.
        expect(find.text('+1 more'), findsOneWidget);
        // The warning is one of the visible cards.
        expect(find.text('persistent-warn'), findsOneWidget);
        // The oldest transient (i1) was evicted into overflow.
        expect(find.text('i1'), findsNothing);
        // The newest infos remain visible.
        expect(find.text('i5'), findsOneWidget);
      },
    );
  });
}

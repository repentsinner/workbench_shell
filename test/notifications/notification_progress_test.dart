// Tests for the NotificationService progress API (SPEC §10
// "Progress notifications").
//
// Pure-Dart tests — the controller has no widget dependencies; the
// progress card variant is exercised by `notification_host_test.dart`.

import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  group('NotificationService.showProgress', () {
    test('appends a progress notification with severity progress', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');

      expect(service.notifications, hasLength(1));
      final n = service.notifications.single;
      expect(n.severity, NotificationSeverity.progress);
      expect(n.message, 'Working');
      expect(n.progress, isNull, reason: 'Indeterminate by default');
      expect(n.cancellable, isFalse, reason: 'Not cancellable by default');
      expect(controller, isNotNull);
      expect(controller.isActive, isTrue);
    });

    test('cancellable: true exposes a cancellation future', () {
      final service = NotificationService();
      final controller = service.showProgress(
        message: 'Saving',
        cancellable: true,
      );
      expect(controller.cancellation, isA<Future<void>>());
      expect(service.notifications.single.cancellable, isTrue);
    });

    test('non-cancellable still exposes a cancellation future', () {
      // Hosts that pass `cancellable: false` should not crash if they
      // read `controller.cancellation`. The future simply never
      // completes via cancel — `complete`/`fail` still resolves the
      // controller.
      final service = NotificationService();
      final controller = service.showProgress(message: 'Saving');
      expect(controller.cancellation, isA<Future<void>>());
    });

    test('report updates the live notification in place (same id)', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      final originalId = service.notifications.single.id;

      controller.report(progress: 0.25, message: 'Working 25%');

      expect(service.notifications, hasLength(1));
      final n = service.notifications.single;
      expect(n.id, originalId, reason: 'Update must not re-stack');
      expect(n.progress, 0.25);
      expect(n.message, 'Working 25%');
    });

    test('report keeps unspecified fields unchanged', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Saving');

      controller.report(progress: 0.5);
      expect(service.notifications.single.message, 'Saving');
      expect(service.notifications.single.progress, 0.5);

      controller.report(message: 'Saving still');
      expect(service.notifications.single.message, 'Saving still');
      expect(service.notifications.single.progress, 0.5);
    });

    test('report clamps progress to [0.0, 1.0]', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');

      controller.report(progress: -0.5);
      expect(service.notifications.single.progress, 0.0);

      controller.report(progress: 2.0);
      expect(service.notifications.single.progress, 1.0);
    });

    test('report notifies listeners', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      var notifications = 0;
      service.addListener(() => notifications++);

      controller.report(progress: 0.5);

      expect(notifications, 1);
    });
  });

  group('NotificationProgressController.complete', () {
    test('without successMessage dismisses the notification', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      controller.complete();

      expect(service.notifications, isEmpty);
      expect(controller.isActive, isFalse);
    });

    test('with successMessage converts to success severity (same id)', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      final originalId = service.notifications.single.id;

      controller.complete(successMessage: 'Done');

      expect(service.notifications, hasLength(1));
      final n = service.notifications.single;
      expect(n.id, originalId);
      expect(n.severity, NotificationSeverity.success);
      expect(n.message, 'Done');
      expect(n.progress, isNull);
      expect(controller.isActive, isFalse);
    });

    test('is a no-op after the controller has terminated', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      controller.complete(successMessage: 'Done');
      // Second call should not throw, should not re-add a notification.
      controller.complete(successMessage: 'Again');
      expect(service.notifications, hasLength(1));
      expect(service.notifications.single.message, 'Done');
    });
  });

  group('NotificationProgressController.fail', () {
    test('converts to error severity with the failure message', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      final originalId = service.notifications.single.id;

      controller.fail('Out of disk');

      expect(service.notifications, hasLength(1));
      final n = service.notifications.single;
      expect(n.id, originalId);
      expect(n.severity, NotificationSeverity.error);
      expect(n.message, 'Out of disk');
      expect(n.progress, isNull);
      expect(controller.isActive, isFalse);
    });

    test('is a no-op after the controller has terminated', () {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      controller.complete();
      controller.fail('Late failure');
      expect(service.notifications, isEmpty);
    });
  });

  group('NotificationProgressController.cancel', () {
    test('cancellation future fires when cancel is invoked', () async {
      final service = NotificationService();
      final controller = service.showProgress(
        message: 'Working',
        cancellable: true,
      );

      var cancelled = false;
      // ignore: unawaited_futures
      controller.cancellation.then((_) => cancelled = true);

      controller.cancel();
      // Let the microtask flush.
      await Future<void>.delayed(Duration.zero);

      expect(cancelled, isTrue);
      // Card persists until host calls complete/fail.
      expect(service.notifications, hasLength(1));
      expect(controller.isActive, isTrue);
    });

    test('cancel fires only once even when called repeatedly', () async {
      final service = NotificationService();
      final controller = service.showProgress(
        message: 'Working',
        cancellable: true,
      );
      var fires = 0;
      // ignore: unawaited_futures
      controller.cancellation.then((_) => fires++);

      controller.cancel();
      controller.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(fires, 1);
    });

    test('cancel on a non-cancellable controller is a no-op', () async {
      final service = NotificationService();
      final controller = service.showProgress(message: 'Working');
      var cancelled = false;
      // ignore: unawaited_futures
      controller.cancellation.then((_) => cancelled = true);

      controller.cancel();
      await Future<void>.delayed(Duration.zero);

      expect(cancelled, isFalse);
    });

    test(
      'dismissing the notification externally resolves cancellation',
      () async {
        // If the host dismisses the progress card before the operator
        // hits cancel, the cancellation future still completes so the
        // host code awaiting it doesn't leak.
        final service = NotificationService();
        final controller = service.showProgress(
          message: 'Working',
          cancellable: true,
        );
        var settled = false;
        // ignore: unawaited_futures
        controller.cancellation.then((_) => settled = true);

        controller.complete();
        await Future<void>.delayed(Duration.zero);

        expect(settled, isTrue);
      },
    );
  });

  group('NotificationSeverity.progress', () {
    test('persists is true (no auto-dismiss timer)', () {
      // Progress cards are terminated by the host (`complete`/`fail`)
      // or operator cancel; they must not be killed by the auto-
      // dismiss timer in the meantime.
      expect(NotificationSeverity.progress.persists, isTrue);
    });
  });
}

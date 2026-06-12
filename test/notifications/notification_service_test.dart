// Tests for the NotificationService API surface (SPEC §spec:notification-center).
//
// Pure-Dart tests — the service has no widget dependencies, so
// `package:test` is sufficient. Widget tests for the host overlay live
// alongside the host widget.

import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  group('NotificationService.show', () {
    test('appends a notification and notifies listeners', () {
      final service = NotificationService();
      var notifications = 0;
      service.addListener(() => notifications++);

      final id = service.show(
        severity: NotificationSeverity.info,
        message: 'Hello',
      );

      expect(service.notifications, hasLength(1));
      expect(service.notifications.single.id, id);
      expect(service.notifications.single.severity, NotificationSeverity.info);
      expect(service.notifications.single.message, 'Hello');
      expect(service.notifications.single.actions, isEmpty);
      expect(notifications, 1);
    });

    test('mints distinct ids for successive notifications', () {
      final service = NotificationService();
      final a = service.show(severity: NotificationSeverity.info, message: 'A');
      final b = service.show(severity: NotificationSeverity.info, message: 'B');
      expect(a, isNot(equals(b)));
    });

    test('returns notifications in insertion order (oldest first)', () {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'A');
      service.show(severity: NotificationSeverity.info, message: 'B');
      service.show(severity: NotificationSeverity.info, message: 'C');

      expect(service.notifications.map((n) => n.message), ['A', 'B', 'C']);
    });

    test('exposes notifications as an unmodifiable view', () {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'A');

      expect(
        () => service.notifications.add(
          WorkbenchNotification(
            id: Object(),
            severity: NotificationSeverity.info,
            message: 'B',
            createdAt: DateTime.now(),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('uses the injected clock for createdAt', () {
      final fixed = DateTime.utc(2026, 1, 2, 3, 4, 5);
      final service = NotificationService(now: () => fixed);
      service.show(severity: NotificationSeverity.info, message: 'A');
      expect(service.notifications.single.createdAt, fixed);
    });

    test('preserves the supplied actions list', () {
      var invoked = 0;
      final action = NotificationAction(
        label: 'Undo',
        onInvoke: () => invoked++,
      );
      final service = NotificationService();
      service.show(
        severity: NotificationSeverity.success,
        message: 'Saved',
        actions: [action],
      );

      expect(service.notifications.single.actions, [action]);
      service.notifications.single.actions.single.onInvoke();
      expect(invoked, 1);
    });
  });

  group('NotificationService.dismiss', () {
    test('removes a notification by id and notifies listeners', () {
      final service = NotificationService();
      final id = service.show(
        severity: NotificationSeverity.info,
        message: 'A',
      );
      var notifications = 0;
      service.addListener(() => notifications++);

      service.dismiss(id);

      expect(service.notifications, isEmpty);
      expect(notifications, 1);
    });

    test('is a silent no-op for unknown ids', () {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'A');
      var notifications = 0;
      service.addListener(() => notifications++);

      service.dismiss(Object());

      expect(service.notifications, hasLength(1));
      expect(notifications, 0);
    });

    test('only removes the matching notification', () {
      final service = NotificationService();
      final a = service.show(severity: NotificationSeverity.info, message: 'A');
      service.show(severity: NotificationSeverity.info, message: 'B');

      service.dismiss(a);

      expect(service.notifications.map((n) => n.message), ['B']);
    });
  });

  group('NotificationService.clear', () {
    test('removes all notifications and notifies once', () {
      final service = NotificationService();
      service.show(severity: NotificationSeverity.info, message: 'A');
      service.show(severity: NotificationSeverity.warning, message: 'B');
      var notifications = 0;
      service.addListener(() => notifications++);

      service.clear();

      expect(service.notifications, isEmpty);
      expect(notifications, 1);
    });

    test('is a silent no-op when the queue is empty', () {
      final service = NotificationService();
      var notifications = 0;
      service.addListener(() => notifications++);

      service.clear();

      expect(notifications, 0);
    });
  });

  group('NotificationSeverity.persists', () {
    test('warning and error persist; info and success do not', () {
      expect(NotificationSeverity.info.persists, isFalse);
      expect(NotificationSeverity.success.persists, isFalse);
      expect(NotificationSeverity.warning.persists, isTrue);
      expect(NotificationSeverity.error.persists, isTrue);
    });
  });
}

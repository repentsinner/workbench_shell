// Unit tests for the WorkbenchPanel descriptor surface (descriptor
// equality, badge value semantics, lifecycle transitions). Uses
// flutter_test for symmetry with the rest of the workbench_shell test
// suite — nothing here mounts a widget, but flutter_test re-exports
// package:test's API and is already a dev dependency.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

class _FocusFooIntent extends Intent {
  const _FocusFooIntent();
}

void main() {
  group('PanelTabBadge', () {
    test('equality keys on count', () {
      const a = PanelTabBadge(count: 3);
      const b = PanelTabBadge(count: 3);
      const c = PanelTabBadge(count: 4);

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('WorkbenchPanel', () {
    test('equality keys on id only', () {
      final a = WorkbenchPanel(
        id: 'output',
        label: 'Output',
        contentBuilder: (_, _) => const SizedBox.shrink(),
      );
      final b = WorkbenchPanel(
        id: 'output',
        label: 'Different label, same id',
        contentBuilder: (_, _) => const Text('different content'),
        focusIntent: const _FocusFooIntent(),
        badge: const PanelTabBadge(count: 2),
      );
      final c = WorkbenchPanel(
        id: 'problems',
        label: 'Output',
        contentBuilder: (_, _) => const SizedBox.shrink(),
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    test('captures all optional fields', () {
      final panel = WorkbenchPanel(
        id: 'mdi',
        label: 'MDI',
        contentBuilder: (_, _) => const SizedBox.shrink(),
        shortcut: const SingleActivator(LogicalKeyboardKey.keyA, control: true),
        badge: const PanelTabBadge(count: 1),
        focusIntent: const _FocusFooIntent(),
      );

      expect(panel.shortcut, isNotNull);
      expect(panel.badge?.count, 1);
      expect(panel.focusIntent, isA<_FocusFooIntent>());
    });
  });

  group('PanelLifecycleController', () {
    test('isFocused starts at the supplied initial value', () {
      final defaulted = PanelLifecycleController();
      addTearDown(defaulted.dispose);
      expect(defaulted.isFocused.value, isFalse);

      final focused = PanelLifecycleController(initialFocused: true);
      addTearDown(focused.dispose);
      expect(focused.isFocused.value, isTrue);
    });

    test('focused setter notifies listeners on transition', () {
      final controller = PanelLifecycleController();
      addTearDown(controller.dispose);

      var notifications = 0;
      controller.isFocused.addListener(() => notifications++);

      controller.focused = true;
      controller.focused = true; // No-op — same value, no notification.
      controller.focused = false;

      expect(notifications, 2);
      expect(controller.isFocused.value, isFalse);
    });
  });
}

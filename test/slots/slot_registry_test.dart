import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  group('SlotRegistry', () {
    test('empty registry returns null for all slots', () {
      const registry = SlotRegistry.empty();
      expect(registry.has(.sidebarExtension), isFalse);
      expect(registry.has(.bottomPanelExtension), isFalse);
      expect(registry.has(.statusBarExtension), isFalse);
      expect(registry.hasSidebarSlots, isFalse);
    });

    test('has() returns true when builder registered', () {
      final registry = SlotRegistry(
        builders: {.sidebarExtension: (_) => const SizedBox()},
      );
      expect(registry.has(.sidebarExtension), isTrue);
      expect(registry.has(.bottomPanelExtension), isFalse);
    });

    test('has(statusBarExtension) returns false when not registered', () {
      const registry = SlotRegistry.empty();
      expect(registry.has(.statusBarExtension), isFalse);
    });

    test('has(statusBarExtension) returns true when registered', () {
      final registry = SlotRegistry(
        builders: {.statusBarExtension: (_) => const SizedBox()},
      );
      expect(registry.has(.statusBarExtension), isTrue);
    });

    testWidgets('build() returns widget from registered builder', (
      tester,
    ) async {
      final registry = SlotRegistry(
        builders: {.sidebarExtension: (_) => const Text('Pro Sidebar')},
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final widget = registry.build(context, .sidebarExtension);
              return widget ?? const SizedBox();
            },
          ),
        ),
      );

      expect(find.text('Pro Sidebar'), findsOneWidget);
    });

    testWidgets('build() returns null for unregistered slot', (tester) async {
      const registry = SlotRegistry.empty();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final widget = registry.build(context, .sidebarExtension);
              return widget ?? const Text('fallback');
            },
          ),
        ),
      );

      expect(find.text('fallback'), findsOneWidget);
    });

    test('hasSidebarSlots returns true when slots registered', () {
      final registry = SlotRegistry(
        sidebarSlots: [
          SidebarSlot(
            id: 'test',
            label: 'Test',
            icon: const IconData(0xe001),
            contentBuilder: (_) => const SizedBox(),
          ),
        ],
      );
      expect(registry.hasSidebarSlots, isTrue);
    });
  });

  group('SidebarSlot', () {
    test('equality is by id', () {
      final slot1 = SidebarSlot(
        id: 'abc',
        label: 'A',
        icon: const IconData(0xe001),
        contentBuilder: (_) => const SizedBox(),
      );
      final slot2 = SidebarSlot(
        id: 'abc',
        label: 'B',
        icon: const IconData(0xe002),
        contentBuilder: (_) => const SizedBox(),
      );
      expect(slot1, equals(slot2));
    });

    test('different ids are not equal', () {
      final slot1 = SidebarSlot(
        id: 'abc',
        label: 'A',
        icon: const IconData(0xe001),
        contentBuilder: (_) => const SizedBox(),
      );
      final slot2 = SidebarSlot(
        id: 'xyz',
        label: 'A',
        icon: const IconData(0xe001),
        contentBuilder: (_) => const SizedBox(),
      );
      expect(slot1, isNot(equals(slot2)));
    });
  });
}

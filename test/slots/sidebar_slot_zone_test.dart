import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  group('SidebarSlot zone and sortOrder', () {
    test('defaults to main zone with sortOrder 250', () {
      final slot = SidebarSlot(
        id: 'test',
        label: 'Test',
        icon: const IconData(0xe001),
        contentBuilder: (_) => const SizedBox(),
      );

      expect(slot.zone, SidebarZone.main);
      expect(slot.sortOrder, 250.0);
    });

    test('accepts custom zone and sortOrder', () {
      final slot = SidebarSlot(
        id: 'test',
        label: 'Test',
        icon: const IconData(0xe001),
        contentBuilder: (_) => const SizedBox(),
        zone: .bottom,
        sortOrder: 850.0,
      );

      expect(slot.zone, SidebarZone.bottom);
      expect(slot.sortOrder, 850.0);
    });

    test('equality ignores zone and sortOrder (id-only)', () {
      final slot1 = SidebarSlot(
        id: 'abc',
        label: 'A',
        icon: const IconData(0xe001),
        contentBuilder: (_) => const SizedBox(),
        sortOrder: 100.0,
      );
      final slot2 = SidebarSlot(
        id: 'abc',
        label: 'B',
        icon: const IconData(0xe002),
        contentBuilder: (_) => const SizedBox(),
        zone: .bottom,
        sortOrder: 900.0,
      );
      expect(slot1, equals(slot2));
    });
  });
}

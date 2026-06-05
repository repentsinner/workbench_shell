import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'test_theme.dart';

void main() {
  group('applyWorkbenchChrome', () {
    final base = ThemeData.dark();
    final result = applyWorkbenchChrome(base, testWorkbenchTheme);

    test('installs the WorkbenchTheme extension', () {
      expect(result.extension<WorkbenchTheme>(), same(testWorkbenchTheme));
    });

    test('preserves the host base brightness', () {
      expect(result.brightness, base.brightness);
    });

    test('elevated button theme carries the 4px buttonShape', () {
      final shape = result.elevatedButtonTheme.style?.shape?.resolve({});
      expect(shape, WorkbenchLayoutConstants.buttonShape);
    });

    test('outlined button theme carries the 4px buttonShape', () {
      final shape = result.outlinedButtonTheme.style?.shape?.resolve({});
      expect(shape, WorkbenchLayoutConstants.buttonShape);
    });

    test('text button theme carries the 4px buttonShape', () {
      final shape = result.textButtonTheme.style?.shape?.resolve({});
      expect(shape, WorkbenchLayoutConstants.buttonShape);
    });

    test('preserves host extensions already on the base', () {
      final withDomain = base.copyWith(
        extensions: const [_FakeDomainExtension()],
      );
      final composed = applyWorkbenchChrome(withDomain, testWorkbenchTheme);
      expect(composed.extension<_FakeDomainExtension>(), isNotNull);
      expect(composed.extension<WorkbenchTheme>(), same(testWorkbenchTheme));
    });

    test('replaces a stale WorkbenchTheme already on the base', () {
      final stale = WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(name: 'Stale', baseType: 'vs-dark', colors: {}),
      );
      final withStale = base.copyWith(extensions: [stale]);
      final composed = applyWorkbenchChrome(withStale, testWorkbenchTheme);
      expect(composed.extension<WorkbenchTheme>(), same(testWorkbenchTheme));
    });
  });
}

class _FakeDomainExtension extends ThemeExtension<_FakeDomainExtension> {
  const _FakeDomainExtension();

  @override
  _FakeDomainExtension copyWith() => this;

  @override
  _FakeDomainExtension lerp(_FakeDomainExtension? other, double t) => this;
}

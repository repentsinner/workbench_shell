import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  group('ToggleBottomPanelIntent', () {
    test('is a const-constructible public Intent', () {
      const intent = ToggleBottomPanelIntent();
      expect(intent, isA<Intent>());
    });

    test('identical const instances share identity', () {
      const a = ToggleBottomPanelIntent();
      const b = ToggleBottomPanelIntent();
      expect(identical(a, b), isTrue);
    });
  });
}

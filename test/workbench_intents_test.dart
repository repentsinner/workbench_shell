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

  group('Editor tab intents (§spec:editor-tab-interaction)', () {
    test('are const-constructible public Intents', () {
      const intents = <Intent>[
        ActivateNextEditorTabIntent(),
        ActivatePreviousEditorTabIntent(),
        CloseActiveEditorTabIntent(),
        ActivateEditorTabAtIndexIntent(0),
        ActivateLastEditorTabIntent(),
      ];
      expect(intents, everyElement(isA<Intent>()));
    });

    test('the index intent carries its zero-based position', () {
      expect(const ActivateEditorTabAtIndexIntent(3).index, 3);
    });
  });
}

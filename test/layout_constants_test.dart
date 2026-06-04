import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  group('WorkbenchLayoutConstants button shape', () {
    test('buttonRadius is a 4px circular radius (VS Code button.css)', () {
      expect(
        WorkbenchLayoutConstants.buttonRadius,
        const BorderRadius.all(Radius.circular(4)),
      );
    });

    test('buttonShape is a RoundedRectangleBorder built from buttonRadius', () {
      expect(
        WorkbenchLayoutConstants.buttonShape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      );
      expect(
        WorkbenchLayoutConstants.buttonShape.borderRadius,
        WorkbenchLayoutConstants.buttonRadius,
      );
    });
  });
}

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

  group('WorkbenchLayoutConstants VS Code canon (SPEC §8.1)', () {
    // Records the canonical literal values so an accidental edit fails
    // loudly. Each value cites its VS Code upstream in SPEC §8.1's
    // canonical source table.
    test('statusBarHeight matches statusbarpart.css (22px)', () {
      expect(WorkbenchLayoutConstants.statusBarHeight, 22.0);
    });

    test('sidebarMinWidth matches sidebarPart.ts minimumWidth (170)', () {
      expect(WorkbenchLayoutConstants.sidebarMinWidth, 170.0);
    });

    test('panelMinHeight matches panelPart.ts minimumHeight (77)', () {
      expect(WorkbenchLayoutConstants.panelMinHeight, 77.0);
    });

    test('notificationCardWidth matches notificationsToasts.ts MAX_WIDTH '
        '(450)', () {
      expect(WorkbenchLayoutConstants.notificationCardWidth, 450.0);
    });

    test('panelTabStripHeight matches part.css .part > .title (35px)', () {
      expect(WorkbenchLayoutConstants.panelTabStripHeight, 35.0);
    });

    test('sidebarHeadingHeight shares the 35px .part > .title container', () {
      expect(
        WorkbenchLayoutConstants.sidebarHeadingHeight,
        WorkbenchLayoutConstants.panelTabStripHeight,
      );
    });
  });
}

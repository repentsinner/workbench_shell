import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  group('WorkbenchLayoutConstants corner radius ladder', () {
    // VS Code registers the ladder in `baseSizes.ts`; these assertions pin
    // each package name to the value upstream registers for it
    // (SPEC §spec:design-size-ladders).
    test('cornerRadius ladder matches baseSizes.ts registrations', () {
      expect(WorkbenchLayoutConstants.cornerRadiusXSmall, 2.0);
      expect(WorkbenchLayoutConstants.cornerRadiusSmall, 4.0);
      expect(WorkbenchLayoutConstants.cornerRadiusMedium, 6.0);
      expect(WorkbenchLayoutConstants.cornerRadiusLarge, 8.0);
      expect(WorkbenchLayoutConstants.cornerRadiusXLarge, 12.0);
      expect(WorkbenchLayoutConstants.cornerRadiusCircle, 9999.0);
    });

    test('strokeThickness matches baseSizes.ts strokeThickness (1px)', () {
      expect(WorkbenchLayoutConstants.strokeThickness, 1.0);
    });

    test('buttonShape rounds to the controls tier (cornerRadius.small)', () {
      expect(
        WorkbenchLayoutConstants.buttonShape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      );
    });
  });

  group('WorkbenchLayoutConstants spacing ramp', () {
    // Every step VS Code registers in `baseSizes.ts`, pinned to the value
    // upstream registers for it (SPEC §spec:design-size-ladders).
    test('spacing ramp matches baseSizes.ts registrations', () {
      expect(WorkbenchLayoutConstants.spacingNone, 0.0);
      expect(WorkbenchLayoutConstants.spacingSize20, 2.0);
      expect(WorkbenchLayoutConstants.spacingSize40, 4.0);
      expect(WorkbenchLayoutConstants.spacingSize60, 6.0);
      expect(WorkbenchLayoutConstants.spacingSize80, 8.0);
      expect(WorkbenchLayoutConstants.spacingSize100, 10.0);
      expect(WorkbenchLayoutConstants.spacingSize120, 12.0);
      expect(WorkbenchLayoutConstants.spacingSize160, 16.0);
      expect(WorkbenchLayoutConstants.spacingSize200, 20.0);
      expect(WorkbenchLayoutConstants.spacingSize240, 24.0);
      expect(WorkbenchLayoutConstants.spacingSize280, 28.0);
      expect(WorkbenchLayoutConstants.spacingSize320, 32.0);
      expect(WorkbenchLayoutConstants.spacingSize360, 36.0);
      expect(WorkbenchLayoutConstants.spacingSize400, 40.0);
    });

    test('notification stack metrics sit on the ramp', () {
      // Pins the chosen step, not the definition. Asserting against
      // `spacingSize160` would restate how the constant is declared and
      // could never fail; the literal makes a re-tiering visible in the diff.
      expect(WorkbenchLayoutConstants.notificationStackInset, 16.0);
      expect(WorkbenchLayoutConstants.notificationStackGap, 8.0);
    });
  });

  group(
    'WorkbenchLayoutConstants VS Code canon (SPEC §spec:layout-constants-canon)',
    () {
      // Records the canonical literal values so an accidental edit fails
      // loudly. Each value cites its VS Code upstream in SPEC §spec:layout-constants-canon's
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
    },
  );

  group('WorkbenchLayoutConstants Modern UI surface treatment', () {
    // Pins the values VS Code 1.138.0 uses for the floating-card treatment
    // (SPEC §spec:modern-ui-surfaces). Each constant's doc comment cites the
    // upstream registration it came from.
    test('floatingCardGap matches layoutService.ts FLOATING_PANEL_MARGIN', () {
      expect(WorkbenchLayoutConstants.floatingCardGap, 4.0);
    });

    test('floatingCardRadius takes the cornerRadius.large tier', () {
      expect(WorkbenchLayoutConstants.floatingCardRadius, 8.0);
    });
  });
}

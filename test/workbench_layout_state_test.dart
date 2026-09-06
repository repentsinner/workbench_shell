import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workbench_shell/workbench_shell.dart';

WorkbenchViewDescriptor _view(
  String id, {
  bool visible = true,
  bool initiallyExpanded = true,
  bool? expanded,
  double? maximumBodySize,
  ValueChanged<bool>? onVisibleChanged,
}) {
  return WorkbenchViewDescriptor(
    id: id,
    title: id,
    visible: visible,
    initiallyExpanded: initiallyExpanded,
    expanded: expanded,
    maximumBodySize: maximumBodySize,
    onVisibleChanged: onVisibleChanged,
    bodyBuilder: (_) => const SizedBox.shrink(),
  );
}

void main() {
  group('toJson/fromJson', () {
    test('round-trips through jsonEncode with only JSON primitives', () {
      const state = WorkbenchLayoutState(
        sizes: {
          'explorer': {'folders': 120.5, 'outline': 90.0},
        },
        order: {
          'explorer': ['folders', 'outline', 'timeline'],
        },
        expanded: {
          'explorer': {'folders': true, 'outline': false},
        },
        hidden: {
          'explorer': {'open-editors'},
        },
      );

      // jsonEncode throws if any value is not a JSON primitive — this is the
      // Set-safety guard: hidden must serialize as a list.
      final encoded = jsonEncode(state.toJson());
      expect(encoded.contains('"hidden":{"explorer":["open-editors"]}'), isTrue);

      final decoded = WorkbenchLayoutState.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.sizes['explorer'], {'folders': 120.5, 'outline': 90.0});
      expect(decoded.order['explorer'], ['folders', 'outline', 'timeline']);
      expect(decoded.expanded['explorer'], {'folders': true, 'outline': false});
      expect(decoded.hidden['explorer'], {'open-editors'});
    });

    test('hidden list with duplicates dedupes into a set on read', () {
      final decoded = WorkbenchLayoutState.fromJson({
        'hidden': {
          'explorer': ['a', 'a', 'b'],
        },
      });
      expect(decoded.hidden['explorer'], {'a', 'b'});
    });

    test('tolerant: absent concerns default empty, unknown concerns ignored', () {
      final decoded = WorkbenchLayoutState.fromJson({
        'order': {
          'explorer': ['a'],
        },
        'somethingNewerShellsAdded': 42,
      });
      expect(decoded.order['explorer'], ['a']);
      expect(decoded.sizes, isEmpty);
      expect(decoded.expanded, isEmpty);
      expect(decoded.hidden, isEmpty);
    });

    test('tolerant: malformed entries are dropped, not thrown', () {
      final decoded = WorkbenchLayoutState.fromJson({
        'sizes': {
          'explorer': {'folders': 'not-a-number', 'outline': 80},
        },
        'order': 'not-a-map',
        'hidden': {
          'explorer': [1, 'valid'],
        },
      });
      expect(decoded.sizes['explorer'], {'outline': 80.0});
      expect(decoded.order, isEmpty);
      expect(decoded.hidden['explorer'], {'valid'});
    });
  });

  group('reconcile', () {
    test('drops stale containers and views, admits new views at defaults', () {
      const persisted = WorkbenchLayoutState(
        order: {
          'explorer': ['gone', 'folders'],
          'removed-container': ['x'],
        },
        expanded: {
          'explorer': {'gone': false, 'folders': false},
        },
        hidden: {
          'explorer': {'gone'},
        },
      );

      final reconciled = persisted.reconcile({
        'explorer': [
          _view('folders'),
          // A newly declared view that starts hidden and collapsed by default.
          _view('new-view', visible: false, initiallyExpanded: false),
        ],
      });

      // Stale container dropped.
      expect(reconciled.order.containsKey('removed-container'), isFalse);
      // Stale view 'gone' dropped from order; new view appended.
      expect(reconciled.order['explorer'], ['folders', 'new-view']);
      // Persisted expansion for surviving view kept; new view at descriptor default.
      expect(reconciled.expanded['explorer'], {
        'folders': false,
        'new-view': false,
      });
      // New view starting hidden is admitted to the hidden set; stale 'gone' gone.
      expect(reconciled.hidden['explorer'], {'new-view'});
    });

    test('clamps persisted sizes to pane geometry', () {
      const persisted = WorkbenchLayoutState(
        sizes: {
          'explorer': {'capped': 500.0, 'stale': 100.0},
        },
      );
      final reconciled = persisted.reconcile({
        'explorer': [_view('capped', maximumBodySize: 200.0)],
      });
      expect(reconciled.sizes['explorer'], {'capped': 200.0});
    });

    test('excludes controlled-visibility views from the hidden store', () {
      const persisted = WorkbenchLayoutState(
        hidden: {
          'explorer': {'controlled'},
        },
      );
      final reconciled = persisted.reconcile({
        'explorer': [
          _view('controlled', visible: false, onVisibleChanged: (_) {}),
        ],
      });
      expect(reconciled.hidden.containsKey('explorer'), isFalse);
    });
  });

  group('applyReorder', () {
    test('splices a visible-index move past a hidden slot', () {
      // Full order: [a(hidden), b, c, d]. Visible: [b, c, d].
      // Move visible index 0 (b) to visible index 2 → visible [c, d, b].
      final result = WorkbenchLayoutState.applyReorder(
        ['a', 'b', 'c', 'd'],
        {'a'},
        0,
        2,
      );
      // Hidden 'a' keeps its absolute leading slot; visible panes permuted.
      expect(result, ['a', 'c', 'd', 'b']);
    });

    test('out-of-range from index is a no-op', () {
      final result = WorkbenchLayoutState.applyReorder(
        ['a', 'b'],
        const {},
        5,
        0,
      );
      expect(result, ['a', 'b']);
    });
  });
}

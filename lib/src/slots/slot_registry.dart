import 'package:flutter/widgets.dart';

import 'sidebar_slot.dart';
import 'slot_id.dart';

/// Registry mapping [SlotId]s to widget builders and holding
/// [SidebarSlot] registrations for the activity bar.
///
/// The pro edition populates slots during DI configuration.
/// The open edition registers an empty registry (all slots return null).
class SlotRegistry {
  final Map<SlotId, Widget Function(BuildContext)> _builders;
  final List<SidebarSlot> sidebarSlots;

  const SlotRegistry({
    Map<SlotId, Widget Function(BuildContext)> builders = const {},
    this.sidebarSlots = const [],
  }) : _builders = builders;

  /// Backward-compatible unnamed constructor for open edition.
  const SlotRegistry.empty() : _builders = const {}, sidebarSlots = const [];

  /// Returns the widget for [id], or null if no builder is registered.
  Widget? build(BuildContext context, SlotId id) {
    final builder = _builders[id];
    return builder?.call(context);
  }

  /// Whether a builder is registered for [id].
  bool has(SlotId id) => _builders.containsKey(id);

  /// Whether any sidebar slots are registered.
  bool get hasSidebarSlots => sidebarSlots.isNotEmpty;
}

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Zone within the activity bar where an item icon renders.
///
/// [main] items appear in the upper group.
/// [bottom] items appear in the lower group.
enum ActivityBarZone { main, bottom }

/// Descriptor for a single activity bar icon.
///
/// The workbench layout renders these as icon buttons in the activity
/// bar. Tapping an item calls the layout's section-change callback
/// with [id]. The layout tracks which [id] is active.
@immutable
class ActivityBarItem extends Equatable {
  /// Unique identifier for this item. Used to match the active section.
  final String id;

  /// Tooltip and section heading text.
  final String label;

  /// Icon displayed in the activity bar.
  final IconData icon;

  /// Which zone the icon renders in (upper or lower group).
  final ActivityBarZone zone;

  /// Position within the zone. Lower values render first.
  final double sortOrder;

  const ActivityBarItem({
    required this.id,
    required this.label,
    required this.icon,
    this.zone = ActivityBarZone.main,
    this.sortOrder = 0,
  });

  @override
  List<Object?> get props => [id];
}

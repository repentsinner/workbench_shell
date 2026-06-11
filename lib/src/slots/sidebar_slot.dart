import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'sidebar_zone.dart';

/// A sidebar extension slot registered by the host.
///
/// Each slot appears as an icon in the activity bar and renders
/// its [contentBuilder] in the primary sidebar when selected.
///
/// [zone] controls whether the icon appears in the upper ([SidebarZone.main])
/// or lower ([SidebarZone.bottom]) group. [sortOrder] determines position
/// within the zone — lower values render first.
@immutable
class SidebarSlot extends Equatable {
  final String id;
  final String label;
  final IconData icon;
  final WidgetBuilder contentBuilder;
  final SidebarZone zone;
  final double sortOrder;

  const SidebarSlot({
    required this.id,
    required this.label,
    required this.icon,
    required this.contentBuilder,
    this.zone = .main,
    this.sortOrder = 250.0,
  });

  @override
  List<Object?> get props => [id];
}

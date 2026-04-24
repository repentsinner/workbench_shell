/// Identifiers for UI extension slots.
///
/// The pro edition registers custom widget builders for these slots.
/// The open edition leaves them empty (default behavior).
enum SlotId {
  /// Additional sidebar sections (e.g., pro-only tools).
  sidebarExtension,

  /// Additional bottom panel tabs (e.g., advanced diagnostics).
  bottomPanelExtension,

  /// Additional status bar indicators (e.g., license status).
  statusBarExtension,

  /// Replaces the default jog controls in session initialization.
  jogControls,

  /// Pro route settings inserted after the clearance height fields
  /// in Machine Profile settings. Empty in opencore.
  proRouteSettings,
}

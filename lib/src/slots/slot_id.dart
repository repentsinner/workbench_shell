/// Identifiers for UI extension slots a host can populate.
///
/// A host registers custom widget builders for these slots through a
/// [SlotRegistry]; an empty registry leaves them unpopulated, so the
/// shell renders only its built-in chrome.
enum SlotId {
  /// Additional sidebar sections contributed by the host.
  sidebarExtension,

  /// Additional bottom-panel tabs contributed by the host.
  bottomPanelExtension,

  /// Additional status-bar indicators contributed by the host.
  statusBarExtension,
}

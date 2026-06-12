import 'package:flutter/widgets.dart';

/// Workbench command intents published by `workbench_shell`.
///
/// Intents are Flutter's built-in dispatch primitive for decoupling a
/// command's surface (menu item, keyboard shortcut) from the widget that
/// owns the target state. The shell surfaces commands by invoking an
/// intent via `Actions.invoke`; hosts register `Action<Intent>` handlers
/// at the widget that owns the underlying state.
///
/// The shell publishes exactly one intent — [ToggleBottomPanelIntent].
/// Host-specific commands (e.g. focusing a particular bottom-panel tab)
/// use host-defined intents; `WorkbenchViewMenuTab` carries an arbitrary
/// [Intent] so hosts can wire their own vocabulary through the menu.
///
/// See package SPEC §spec:action-dispatch for rationale.

/// Toggles bottom-panel visibility. Emitted by the View menu's "Panel"
/// entry and by the default Cmd+J / Ctrl+J keyboard binding installed
/// by `WorkbenchShortcuts`.
class ToggleBottomPanelIntent extends Intent {
  const ToggleBottomPanelIntent();
}

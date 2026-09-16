import 'package:flutter/widgets.dart';

/// Workbench command intents published by `workbench_shell`.
///
/// Intents are Flutter's built-in dispatch primitive for decoupling a
/// command's surface (menu item, keyboard shortcut) from the widget that
/// owns the target state. The shell surfaces commands by invoking an
/// intent via `Actions.invoke`; hosts register `Action<Intent>` handlers
/// at the widget that owns the underlying state.
///
/// The shell publishes only commands that name nothing host-specific:
/// [ToggleBottomPanelIntent] and the editor-tab commands. Host-specific
/// commands (e.g. focusing a particular bottom-panel tab) use host-defined
/// intents; `WorkbenchViewMenuTab` carries an arbitrary [Intent] so hosts can
/// wire their own vocabulary through the menu.
///
/// See package SPEC §spec:action-dispatch for rationale.

/// Toggles bottom-panel visibility. Emitted by the View menu's "Panel"
/// entry and by the default Cmd+J / Ctrl+J keyboard binding installed
/// by `WorkbenchShortcuts`.
class ToggleBottomPanelIntent extends Intent {
  const ToggleBottomPanelIntent();
}

// Editor tab commands (§spec:editor-tab-interaction). A `WorkbenchLayout`
// with editor tabs handles each one and binds VS Code's per-platform default
// chords to it. Each names no tab, so it means the same thing in every host.

/// Activates the tab after the active editor tab, wrapping from the last to
/// the first. VS Code `workbench.action.nextEditor`.
class ActivateNextEditorTabIntent extends Intent {
  const ActivateNextEditorTabIntent();
}

/// Activates the tab before the active editor tab, wrapping from the first to
/// the last. VS Code `workbench.action.previousEditor`.
class ActivatePreviousEditorTabIntent extends Intent {
  const ActivatePreviousEditorTabIntent();
}

/// Requests the close of the active editor tab through
/// `WorkbenchLayout.onEditorTabCloseRequested`. Disabled while the layout has
/// no close handler. VS Code `workbench.action.closeActiveEditor`.
class CloseActiveEditorTabIntent extends Intent {
  const CloseActiveEditorTabIntent();
}

/// Activates the editor tab at [index] in strip order; an index past the last
/// tab does nothing. VS Code `workbench.action.openEditorAtIndex1` through
/// `openEditorAtIndex9`.
class ActivateEditorTabAtIndexIntent extends Intent {
  /// Zero-based position in the strip.
  final int index;

  const ActivateEditorTabAtIndexIntent(this.index);
}

/// Activates the last editor tab in the strip. VS Code
/// `workbench.action.lastEditorInGroup`.
class ActivateLastEditorTabIntent extends Intent {
  const ActivateLastEditorTabIntent();
}

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Typed badge payload rendered inline next to a tab label.
///
/// Replaces the ad-hoc "tab label as `Widget`" escape hatch — hosts
/// declare a count, and the shell paints the canonical VS Code-style
/// pill in the panel-active accent colour regardless of which consumer
/// surfaces the tab.
///
/// VS Code does not vary the badge background by severity (a multi-
/// severity collection such as a task list has no obvious "summary
/// severity" — highest? most populous? — so painting one colour per
/// tab would surface an arbitrary choice). The pill simply communicates
/// "N items" using the tab strip's own accent.
@immutable
class PanelTabBadge extends Equatable {
  /// Number rendered inside the pill. Hosts pass zero to omit the
  /// badge entirely (callers typically build the badge only when the
  /// underlying collection is non-empty).
  final int count;

  const PanelTabBadge({required this.count});

  @override
  List<Object?> get props => [count];
}

/// Read-only handle a panel content widget consumes to react to focus
/// transitions. Surfaced as a [ValueListenable<bool>] so consumers
/// subscribe through the standard Flutter listenable patterns
/// (`ListenableBuilder`, `addListener`).
///
/// Hosts produce instances via [PanelLifecycleController] — that class
/// owns the writable side, this one stays read-only so panel content
/// cannot flip focus state out from under the host.
abstract class PanelLifecycle {
  /// True when the panel's containing tab is the active tab AND the
  /// bottom panel itself is visible. False otherwise.
  ValueListenable<bool> get isFocused;
}

/// Concrete [PanelLifecycle] backed by a [ValueNotifier]. The host
/// (typically `WorkbenchPanelHost`) owns the controller and flips
/// [isFocused] as visibility and the active tab change; panel content
/// only sees the listenable view.
class PanelLifecycleController implements PanelLifecycle {
  final ValueNotifier<bool> _isFocused;

  PanelLifecycleController({bool initialFocused = false})
    : _isFocused = ValueNotifier<bool>(initialFocused);

  @override
  ValueListenable<bool> get isFocused => _isFocused;

  /// Updates the focus state. No-op when the value is unchanged.
  set focused(bool value) {
    _isFocused.value = value;
  }

  /// Disposes the underlying notifier. Call from the owning state's
  /// `dispose()` once the controller is no longer in use.
  void dispose() {
    _isFocused.dispose();
  }
}

/// Builder signature for panel content. Receives the surrounding
/// [BuildContext] and the per-panel [PanelLifecycle] so content widgets
/// can subscribe to focus transitions (replay an animation when
/// refocused, pause heavy work when blurred, etc.).
typedef PanelContentBuilder =
    Widget Function(BuildContext context, PanelLifecycle lifecycle);

/// Single declaration of one bottom-panel tab.
///
/// Carries everything `WorkbenchPanelHost` needs to wire the View
/// menu, keyboard shortcut binding, tab strip entry, and lifecycle
/// signaling for one panel. Replaces the paired-descriptor pattern
/// (`WorkbenchViewMenuTab` + `WorkbenchPanelTab`) consumers maintained
/// previously.
///
/// `id` is typed `Object` so consumers supply values from their own
/// enum or sealed type — the shell imposes no tab vocabulary.
/// Equality is keyed on [id] only because [WidgetBuilder] and [Intent]
/// are not equatable; descriptor lists are diffed by id when the host
/// rebuilds.
@immutable
class WorkbenchPanel {
  /// Stable identity. Compared with `==`. Hosts typically pass enum
  /// values from their own tab vocabulary.
  final Object id;

  /// Natural-case label (`'Output'`, `'Debug Console'`). The shell
  /// uppercases when rendering the tab strip.
  final String label;

  /// Builds the body for this panel. Receives the per-panel
  /// [PanelLifecycle] so content reacts to focus changes.
  final PanelContentBuilder contentBuilder;

  /// Optional shortcut hint shown next to the View menu entry. Hosts
  /// install the matching activator on a surrounding `Shortcuts`
  /// widget (the shell does not bind tab-focus shortcuts itself).
  final MenuSerializableShortcut? shortcut;

  /// Optional inline badge rendered next to the label in the tab
  /// strip — typed payload (count), not a widget. The shell paints
  /// the pill in the panel-active accent colour; consumers do not
  /// pick the colour.
  final PanelTabBadge? badge;

  /// Intent dispatched when the View menu entry for this panel is
  /// selected. When null, the menu entry renders disabled — consumers
  /// that want focus-on-menu-select supply their own intent type and
  /// register a matching `Action<Intent>` in the surrounding
  /// `Actions` widget.
  final Intent? focusIntent;

  const WorkbenchPanel({
    required this.id,
    required this.label,
    required this.contentBuilder,
    this.shortcut,
    this.badge,
    this.focusIntent,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is WorkbenchPanel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

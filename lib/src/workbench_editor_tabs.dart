import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:meta/meta.dart';

import 'layout_constants.dart';
import 'workbench_intents.dart';
import 'workbench_theme.dart';

/// One editor the host offers as a tab in the editor area
/// (§spec:editor-tabs).
///
/// The host owns which tabs exist and what each shows; the shell renders the
/// strip, owns which tab is active, and builds [contentBuilder] beneath it.
/// The label is a `String` and the icon an [IconData] so the shell keeps its
/// hold on type, size and colour (§spec:capability-boundary).
@immutable
class WorkbenchEditorTab {
  /// Stable identity. The shell keys the active tab, the tab order and each
  /// tab's retained content by it, so it shall be unique within a layout and
  /// survive rebuilds.
  final String id;

  /// The tab's label, rendered in the casing the host supplies.
  final String label;

  /// Optional icon rendered before the label, VS Code's
  /// `workbench.editor.showIcons`.
  final IconData? icon;

  /// Whether the editor has unsaved changes. A dirty tab shows a filled dot in
  /// place of its close button and exposes the state to assistive technology
  /// (§spec:editor-tab-rendering).
  final bool isDirty;

  /// Builds the editor shown while the tab is active. Called only once the
  /// tab has first become active; the result is retained offstage while
  /// another tab is active (§spec:editor-tab-interaction).
  final WidgetBuilder contentBuilder;

  const WorkbenchEditorTab({
    required this.id,
    required this.label,
    required this.contentBuilder,
    this.icon,
    this.isDirty = false,
  });
}

/// VS Code's default editor-tab chords for [platform]
/// (§spec:editor-tab-interaction), from `editorCommands.ts` and
/// `editorActions.ts`. Apple platforms take the macOS set; every other
/// platform takes the Windows / Linux set, with Ctrl+F4 on Windows alone. The
/// close chord is bound only when [closable].
@internal
Map<ShortcutActivator, Intent> editorTabShortcuts({
  required TargetPlatform platform,
  required bool closable,
}) {
  final apple =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;
  // Editor positions 1–9 in order; 0 selects the last editor.
  const digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];
  SingleActivator position(LogicalKeyboardKey key) => apple
      ? SingleActivator(key, control: true)
      : SingleActivator(key, alt: true);
  return {
    if (apple) ...{
      const SingleActivator(
        LogicalKeyboardKey.arrowRight,
        meta: true,
        alt: true,
      ): const ActivateNextEditorTabIntent(),
      const SingleActivator(
        LogicalKeyboardKey.bracketRight,
        meta: true,
        shift: true,
      ): const ActivateNextEditorTabIntent(),
      const SingleActivator(
        LogicalKeyboardKey.arrowLeft,
        meta: true,
        alt: true,
      ): const ActivatePreviousEditorTabIntent(),
      const SingleActivator(
        LogicalKeyboardKey.bracketLeft,
        meta: true,
        shift: true,
      ): const ActivatePreviousEditorTabIntent(),
      if (closable)
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true):
            const CloseActiveEditorTabIntent(),
    } else ...{
      const SingleActivator(LogicalKeyboardKey.pageDown, control: true):
          const ActivateNextEditorTabIntent(),
      const SingleActivator(LogicalKeyboardKey.pageUp, control: true):
          const ActivatePreviousEditorTabIntent(),
      if (closable) ...{
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            const CloseActiveEditorTabIntent(),
        if (platform == TargetPlatform.windows)
          const SingleActivator(LogicalKeyboardKey.f4, control: true):
              const CloseActiveEditorTabIntent(),
      },
    },
    for (final (index, key) in digits.indexed)
      position(key): ActivateEditorTabAtIndexIntent(index),
    position(LogicalKeyboardKey.digit0): const ActivateLastEditorTabIntent(),
  };
}

/// The editor part with tabs: the strip over a retained stack of opened tab
/// content (§spec:editor-tab-rendering, §spec:editor-tab-interaction).
///
/// Internal: `WorkbenchLayout.editorTabs` is the host-facing surface, and the
/// layout owns the state this widget renders.
@internal
class EditorTabsPart extends StatelessWidget {
  /// Tabs in display order.
  final List<WorkbenchEditorTab> tabs;

  /// The active tab's id; one of [tabs].
  final String activeId;

  /// Ids whose content has been built, in first-open order. Only these
  /// contribute content, so a tab never shown costs nothing.
  final List<String> openedIds;

  /// Activates a tab from a click.
  final ValueChanged<String> onSelected;

  /// Requests a tab's close. Null renders no close buttons.
  final ValueChanged<String>? onCloseRequested;

  final WorkbenchTheme theme;

  const EditorTabsPart({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.openedIds,
    required this.onSelected,
    required this.onCloseRequested,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final byId = {for (final tab in tabs) tab.id: tab};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EditorTabStrip(
          tabs: tabs,
          activeId: activeId,
          onSelected: onSelected,
          onCloseRequested: onCloseRequested,
          theme: theme,
        ),
        Expanded(
          // One slot per opened tab, keyed by id so each keeps its element
          // and State. Inactive slots stay in the tree offstage with tickers
          // disabled, as retained view containers do
          // (§spec:view-container-state).
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final id in openedIds)
                if (byId[id] case final tab?)
                  Offstage(
                    key: ValueKey(id),
                    offstage: id != activeId,
                    child: TickerMode(
                      enabled: id == activeId,
                      // A hidden editor cannot keep focus, so keys never land
                      // in content the user cannot see.
                      child: ExcludeFocus(
                        excluding: id != activeId,
                        child: Builder(builder: tab.contentBuilder),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

/// VS Code's classic multi-tab strip (§spec:editor-tab-rendering): a
/// [WorkbenchLayoutConstants.editorTabHeight] row in
/// `editorGroupHeader.tabsBackground`, one `fit`-sized tab per editor.
///
/// Tabs past the strip's width are clipped at its trailing edge until
/// overflow scrolling lands (§spec:editor-tab-interaction).
@internal
class EditorTabStrip extends StatelessWidget {
  final List<WorkbenchEditorTab> tabs;
  final String activeId;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onCloseRequested;
  final WorkbenchTheme theme;

  const EditorTabStrip({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelected,
    required this.onCloseRequested,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final onClose = onCloseRequested;
    return SizedBox(
      height: WorkbenchLayoutConstants.editorTabHeight,
      child: ColoredBox(
        color: theme.editorGroupHeaderTabsBackground,
        child: Semantics(
          role: SemanticsRole.tabBar,
          container: true,
          child: ClipRect(
            // Lets the row keep its natural width without an overflow
            // warning; the clip hides whatever runs past the strip.
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              maxWidth: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final tab in tabs)
                    _EditorTab(
                      key: ValueKey('editor-tab-${tab.id}'),
                      tab: tab,
                      active: tab.id == activeId,
                      onSelected: () => onSelected(tab.id),
                      onClose: onClose == null ? null : () => onClose(tab.id),
                      theme: theme,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab in the base treatment, per `multieditortabscontrol.css`.
class _EditorTab extends StatefulWidget {
  final WorkbenchEditorTab tab;
  final bool active;
  final VoidCallback onSelected;

  /// Requests this tab's close. Null renders no close button.
  final VoidCallback? onClose;
  final WorkbenchTheme theme;

  const _EditorTab({
    super.key,
    required this.tab,
    required this.active,
    required this.onSelected,
    required this.onClose,
    required this.theme,
  });

  @override
  State<_EditorTab> createState() => _EditorTabState();
}

class _EditorTabState extends State<_EditorTab> {
  /// The pointer is over the tab, which reveals its close button.
  bool _tabHovered = false;

  /// The pointer is over the action column itself, which swaps a dirty tab's
  /// dot back to the close glyph (`.action-label:not(:hover)::before`).
  bool _actionHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final tab = widget.tab;
    final active = widget.active;
    final foreground = active
        ? theme.tabActiveForeground
        : theme.tabInactiveForeground;
    // `.tab-actions` shows for a closable tab and for a dirty one: the
    // unsaved dot is state, so it stays even with no close affordance.
    final showsActions = widget.onClose != null || tab.isDirty;
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      selected: active,
      value: tab.isDirty ? 'unsaved changes' : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _tabHovered = true),
        onExit: (_) => setState(() => _tabHovered = false),
        child: GestureDetector(
          onTap: widget.onSelected,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: WorkbenchLayoutConstants.editorTabMinWidth,
            ),
            decoration: BoxDecoration(
              color: active
                  ? theme.tabActiveBackground
                  : theme.tabInactiveBackground,
              border: Border(right: BorderSide(color: theme.tabBorder)),
            ),
            child: _activeRules(
              Padding(
                // The action column supplies the trailing room when it shows
                // (`.close-action-off` pads only when it does not).
                padding: EdgeInsetsDirectional.only(
                  start: WorkbenchLayoutConstants.editorTabPaddingStart,
                  end: showsActions
                      ? 0
                      : WorkbenchLayoutConstants.editorTabPaddingEnd,
                ),
                child: Row(
                  // `.tab-label { flex: 1 }` pushes the actions to the
                  // trailing edge of a tab wider than its content. The strip
                  // lays tabs out at their natural width, so the free space
                  // is distributed rather than flexed into.
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tab.icon case final icon?) ...[
                          Icon(
                            icon,
                            size: WorkbenchLayoutConstants.iconMd,
                            color: foreground,
                          ),
                          const SizedBox(
                            width: WorkbenchLayoutConstants.editorTabIconGap,
                          ),
                        ],
                        Text(
                          tab.label,
                          maxLines: 1,
                          softWrap: false,
                          style: theme.editorTabLabel.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                    if (showsActions) _buildActions(foreground),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The trailing action column: the close button, or a dirty tab's dot.
  ///
  /// Upstream's `.tab-actions` rules show it on the active tab, on hover, and
  /// on a dirty tab, and hide it (opacity 0) otherwise. A hidden button takes
  /// no pointer, so a tap there activates the tab instead of closing an
  /// editor the user cannot see a button for.
  Widget _buildActions(Color foreground) {
    final tab = widget.tab;
    final onClose = widget.onClose;
    final visible = widget.active || _tabHovered || tab.isDirty;
    final showsDot = tab.isDirty && (onClose == null || !_actionHovered);
    final glyph = Icon(
      showsDot ? Symbols.fiber_manual_record : Symbols.close_rounded,
      fill: showsDot ? 1 : 0,
      size: WorkbenchLayoutConstants.iconMd,
      color: foreground,
    );
    return Opacity(
      key: const ValueKey('editor-tab-actions'),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: SizedBox(
          width: WorkbenchLayoutConstants.editorTabActionsWidth,
          child: onClose == null
              ? Center(child: glyph)
              : Semantics(
                  container: true,
                  button: true,
                  label: 'Close',
                  excludeSemantics: true,
                  onTap: onClose,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _actionHovered = true),
                    onExit: (_) => setState(() => _actionHovered = false),
                    child: GestureDetector(
                      onTap: onClose,
                      child: Center(child: glyph),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  /// The active tab's 1px top and bottom rules, drawn over its content
  /// inside the divider, each only when the theme sets its token.
  Widget _activeRules(Widget child) {
    if (!widget.active) return child;
    final theme = widget.theme;
    BorderSide rule(Color? color) => color == null
        ? BorderSide.none
        : BorderSide(
            color: color,
            // Stated so the rule tracks `strokeThickness` if upstream moves
            // it, rather than silently keeping Flutter's 1px default.
            // ignore: avoid_redundant_argument_values
            width: WorkbenchLayoutConstants.strokeThickness,
          );
    return DecoratedBox(
      key: const ValueKey('editor-tab-active-rules'),
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          top: rule(theme.tabActiveBorderTop),
          bottom: rule(theme.tabActiveBorder),
        ),
      ),
      child: child,
    );
  }
}

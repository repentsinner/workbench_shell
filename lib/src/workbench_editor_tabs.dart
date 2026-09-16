import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'layout_constants.dart';
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
  /// Stable identity. The shell keys the active tab and each tab's retained
  /// content by it, so it shall be unique within a layout and survive
  /// rebuilds.
  final String id;

  /// The tab's label, rendered in the casing the host supplies.
  final String label;

  /// Optional icon rendered before the label, VS Code's
  /// `workbench.editor.showIcons`.
  final IconData? icon;

  /// Whether the editor has unsaved changes. The shell exposes the state to
  /// assistive technology.
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

  final WorkbenchTheme theme;

  const EditorTabsPart({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.openedIds,
    required this.onSelected,
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
                      child: Builder(builder: tab.contentBuilder),
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
  final WorkbenchTheme theme;

  const EditorTabStrip({
    super.key,
    required this.tabs,
    required this.activeId,
    required this.onSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
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
class _EditorTab extends StatelessWidget {
  final WorkbenchEditorTab tab;
  final bool active;
  final VoidCallback onSelected;
  final WorkbenchTheme theme;

  const _EditorTab({
    super.key,
    required this.tab,
    required this.active,
    required this.onSelected,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = active
        ? theme.tabActiveForeground
        : theme.tabInactiveForeground;
    return Semantics(
      container: true,
      role: SemanticsRole.tab,
      selected: active,
      value: tab.isDirty ? 'unsaved changes' : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onSelected,
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
                padding: const EdgeInsetsDirectional.only(
                  start: WorkbenchLayoutConstants.editorTabPaddingStart,
                  end: WorkbenchLayoutConstants.editorTabPaddingEnd,
                ),
                child: Row(
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
                      style: theme.editorTabLabel.copyWith(color: foreground),
                    ),
                  ],
                ),
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
    if (!active) return child;
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

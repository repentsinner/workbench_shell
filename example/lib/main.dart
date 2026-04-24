// workbench_shell example app.
//
// Renders a minimal workbench with two activity-bar entries (Explorer
// and Search), a sidebar per entry, a tabbed bottom panel, and a
// status bar. Panel visibility is toggled through the View menu
// (Cmd+J / Ctrl+J) — the idiomatic place for chrome visibility.

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

void main() {
  runApp(const WorkbenchExampleApp());
}

class WorkbenchExampleApp extends StatelessWidget {
  const WorkbenchExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Build a dark WorkbenchTheme from an empty VS Code color map so
    // every token resolves to its built-in fallback. Mirrors the
    // pattern used by the package's own test harness.
    final theme = WorkbenchTheme.fromVscodeColorMap(
      const VscodeColorMap(
        name: 'Example Dark',
        baseType: 'vs-dark',
        colors: {},
      ),
    );

    return MaterialApp(
      title: 'workbench_shell example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(extensions: [theme]),
      home: const WorkbenchHome(),
    );
  }
}

class WorkbenchHome extends StatefulWidget {
  const WorkbenchHome({super.key});

  @override
  State<WorkbenchHome> createState() => _WorkbenchHomeState();
}

class _WorkbenchHomeState extends State<WorkbenchHome> {
  bool _panelVisible = true;

  static const _activityBarItems = [
    ActivityBarItem(
      id: 'explorer',
      label: 'Explorer',
      icon: Symbols.folder_rounded,
    ),
    ActivityBarItem(
      id: 'search',
      label: 'Search',
      icon: Symbols.search_rounded,
    ),
  ];

  static const _viewMenuTabs = [
    WorkbenchViewMenuTab(id: 'output', label: 'Output'),
  ];

  void _togglePanel() {
    setState(() => _panelVisible = !_panelVisible);
  }

  void _selectTab(String _) {
    // Single-tab example: selecting it from the View menu just
    // ensures the panel is visible. Hosts with multiple tabs would
    // focus the picked tab or hide the panel if already focused.
    setState(() => _panelVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    return WorkbenchShortcuts(
      onToggleBottomPanel: _togglePanel,
      child: WorkbenchMenuBar(
        onToggleBottomPanel: _togglePanel,
        tabs: _viewMenuTabs,
        onSelectTab: _selectTab,
        child: WorkbenchLayout(
          activityBarItems: _activityBarItems,
          sidebarBuilder: _buildSidebar,
          editor: const _EditorPlaceholder(),
          bottomPanel: WorkbenchTabbedPanel(
            tabs: [
              WorkbenchPanelTab(
                id: 'output',
                label: const Tab(text: 'Output'),
                contentBuilder: (context) => const _PanelBodyPlaceholder(
                  text: 'Output tab — host-supplied content lands here.',
                ),
              ),
            ],
            onTogglePanel: _togglePanel,
          ),
          showBottomPanel: _panelVisible,
          statusBar: const WorkbenchStatusBar(
            leading: [
              WorkbenchStatusBarItem(
                icon: Symbols.info_rounded,
                label: 'workbench_shell example',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildSidebar(String sectionId) {
    switch (sectionId) {
      case 'explorer':
        return const _SidebarBodyPlaceholder(
          text: 'Explorer sidebar — host-supplied content lands here.',
        );
      case 'search':
        return const _SidebarBodyPlaceholder(
          text: 'Search sidebar — host-supplied content lands here.',
        );
    }
    return null;
  }
}

class _EditorPlaceholder extends StatelessWidget {
  const _EditorPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Center(
      child: Text(
        'Editor area',
        style: theme.bodyStyle.copyWith(color: theme.descriptionForeground),
      ),
    );
  }
}

class _SidebarBodyPlaceholder extends StatelessWidget {
  const _SidebarBodyPlaceholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Padding(
      padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
      child: Text(text, style: theme.bodyStyle),
    );
  }
}

class _PanelBodyPlaceholder extends StatelessWidget {
  const _PanelBodyPlaceholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Padding(
      padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
      child: Text(text, style: theme.bodyStyle),
    );
  }
}

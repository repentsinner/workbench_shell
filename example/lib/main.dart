// workbench_shell example app.
//
// Renders a minimal workbench with two activity-bar sidebars (Explorer
// and Search), VS Code's five canonical bottom panels (Problems,
// Output, Debug Console, Terminal, Ports) with their default keyboard
// bindings, and a status bar. Demonstrates the canonical integration
// pattern for pub.dev consumers: host owns its tab vocabulary and
// focus intent; the shell owns chrome and the panel-toggle default.
//
// The Output panel observes its `PanelLifecycle.isFocused` to drive
// a once-per-second counter that pauses while the tab is blurred or
// the bottom panel is hidden — the canonical focus-aware-content
// pattern.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// The five canonical bottom-panel tabs VS Code ships by default.
/// Lives in the host (this example), not in `workbench_shell` — the
/// shell does not opine about tab vocabulary.
enum ExamplePanel {
  problems('Problems'),
  output('Output'),
  debugConsole('Debug Console'),
  terminal('Terminal'),
  ports('Ports');

  const ExamplePanel(this.label);
  final String label;
}

/// Host-defined intent for focusing a specific bottom-panel tab.
/// `workbench_shell` ships only `ToggleBottomPanelIntent`; consumers
/// declare their own intents for host-specific commands.
class FocusExamplePanelIntent extends Intent {
  const FocusExamplePanelIntent(this.panel);
  final ExamplePanel panel;
}

class WorkbenchHome extends StatefulWidget {
  const WorkbenchHome({super.key});

  @override
  State<WorkbenchHome> createState() => _WorkbenchHomeState();
}

class _WorkbenchHomeState extends State<WorkbenchHome> {
  bool _panelVisible = true;
  void Function(Object id)? _focusPanelById;

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

  void _togglePanel() {
    setState(() => _panelVisible = !_panelVisible);
  }

  /// VS Code's defaults: Shift+Cmd+M Problems, Shift+Cmd+U Output,
  /// Shift+Cmd+Y Debug Console, Ctrl+` Terminal (Ctrl on every
  /// platform — matches VS Code itself). Ports has no default
  /// keyboard binding in VS Code.
  static MenuSerializableShortcut? _shortcutFor(ExamplePanel panel) {
    switch (panel) {
      case ExamplePanel.problems:
        return const SingleActivator(
          LogicalKeyboardKey.keyM,
          meta: true,
          shift: true,
        );
      case ExamplePanel.output:
        return const SingleActivator(
          LogicalKeyboardKey.keyU,
          meta: true,
          shift: true,
        );
      case ExamplePanel.debugConsole:
        return const SingleActivator(
          LogicalKeyboardKey.keyY,
          meta: true,
          shift: true,
        );
      case ExamplePanel.terminal:
        return const SingleActivator(
          LogicalKeyboardKey.backquote,
          control: true,
        );
      case ExamplePanel.ports:
        return null;
    }
  }

  /// `WorkbenchPanelHost.shortcuts` covers the meta-key variant of
  /// each tab's keybinding. To stay aligned with VS Code on Linux and
  /// Windows we install the parallel control-key bindings here.
  static const _ctrlVariantShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyM, control: true, shift: true):
        FocusExamplePanelIntent(ExamplePanel.problems),
    SingleActivator(LogicalKeyboardKey.keyU, control: true, shift: true):
        FocusExamplePanelIntent(ExamplePanel.output),
    SingleActivator(LogicalKeyboardKey.keyY, control: true, shift: true):
        FocusExamplePanelIntent(ExamplePanel.debugConsole),
  };

  Widget _buildPanelContent(ExamplePanel panel, PanelLifecycle lifecycle) {
    if (panel == ExamplePanel.output) {
      return _OutputCounterBody(lifecycle: lifecycle);
    }
    return _PanelBodyPlaceholder(panel: panel);
  }

  List<WorkbenchPanel> _buildPanels() {
    return [
      for (final panel in ExamplePanel.values)
        WorkbenchPanel(
          id: panel,
          label: panel.label,
          shortcut: _shortcutFor(panel),
          focusIntent: FocusExamplePanelIntent(panel),
          contentBuilder: (ctx, lifecycle) =>
              _buildPanelContent(panel, lifecycle),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return WorkbenchPanelHost(
      panels: _buildPanels(),
      panelVisible: _panelVisible,
      onTogglePanel: _togglePanel,
      initialActiveId: ExamplePanel.problems,
      onRegisterFocus: (focusById) => _focusPanelById = focusById,
      builder: (ctx, scope) {
        return Shortcuts(
          shortcuts: {...scope.shortcuts, ..._ctrlVariantShortcuts},
          child: WorkbenchShortcuts(
            child: Actions(
              actions: <Type, Action<Intent>>{
                ToggleBottomPanelIntent:
                    CallbackAction<ToggleBottomPanelIntent>(
                      onInvoke: (_) {
                        _togglePanel();
                        return null;
                      },
                    ),
                FocusExamplePanelIntent:
                    CallbackAction<FocusExamplePanelIntent>(
                      onInvoke: (intent) {
                        if (!_panelVisible) {
                          setState(() => _panelVisible = true);
                        }
                        _focusPanelById?.call(intent.panel);
                        return null;
                      },
                    ),
              },
              child: WorkbenchMenuBar(
                tabs: scope.viewMenuTabs,
                child: WorkbenchLayout(
                  activityBarItems: _activityBarItems,
                  sidebarBuilder: _buildSidebar,
                  editor: const _EditorPlaceholder(),
                  bottomPanel: scope.tabbedPanel,
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
            ),
          ),
        );
      },
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
  const _PanelBodyPlaceholder({required this.panel});
  final ExamplePanel panel;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Padding(
      padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
      child: Text(
        '${panel.label} tab — host-supplied content lands here.',
        style: theme.bodyStyle,
      ),
    );
  }
}

/// Output panel content — increments a counter once per second while
/// the panel is focused, pauses while blurred. Demonstrates the
/// canonical [PanelLifecycle] pattern for pub.dev consumers.
class _OutputCounterBody extends StatefulWidget {
  const _OutputCounterBody({required this.lifecycle});
  final PanelLifecycle lifecycle;

  @override
  State<_OutputCounterBody> createState() => _OutputCounterBodyState();
}

class _OutputCounterBodyState extends State<_OutputCounterBody> {
  Timer? _timer;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    widget.lifecycle.isFocused.addListener(_handleFocusChanged);
    if (widget.lifecycle.isFocused.value) _startTimer();
  }

  @override
  void dispose() {
    widget.lifecycle.isFocused.removeListener(_handleFocusChanged);
    _timer?.cancel();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (widget.lifecycle.isFocused.value) {
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _count++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Padding(
      padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Output tab — increments once per second while focused.',
            style: theme.bodyStyle,
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingMd),
          Text(
            'Counter: $_count',
            style: theme.sectionTitle.copyWith(color: theme.foreground),
          ),
        ],
      ),
    );
  }
}

// workbench_shell example app.
//
// Renders a minimal workbench with five activity-bar items
// (Explorer, Search, Buttons, Notifications, Settings), VS Code's five
// canonical bottom panels (Problems, Output, Debug Console, Terminal,
// Ports) with their default keyboard bindings, a notification-center
// demo, and a status bar. Demonstrates the canonical integration
// pattern for pub.dev consumers: host owns its tab vocabulary and focus
// intent; the shell owns chrome and the panel-toggle default.
//
// The Output panel observes its `PanelLifecycle.isFocused` to drive
// a once-per-second counter that pauses while the tab is blurred or
// the bottom panel is hidden — the canonical focus-aware-content
// pattern.
//
// The Settings sidebar mirrors VS Code's color-theme settings layout:
// an "Auto detect color scheme" checkbox plus three dropdown fields
// — "Color theme" (active when auto-detect is off), "Preferred dark
// color theme", and "Preferred light color theme" — driven by
// `WorkbenchThemeController`. Switching themes rebuilds the
// `MaterialApp.theme` extension; every chrome surface (tab strip,
// status bar, sidebar headings) updates in the same frame, and the
// controller's brightness signal is forwarded across the canonical
// `workbench_shell/window_chrome` method channel so the macOS /
// Windows title bar tracks the workbench appearance (SPEC §spec:platform-brightness-sync).

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

/// Canonical method channel for forwarding workbench brightness to the
/// host-window runner.
///
/// **Method:** `setBrightness`
/// **Argument:** `String` — `'light'` or `'dark'`
/// **Return:** none
///
/// The macOS and Windows runners in this example's source tree implement
/// the receiver (the title bar tracks the workbench appearance). The
/// published package archive omits the platform folders, so a consumer
/// who regenerates runners with `flutter create .` gets no receiver until
/// they add one. The channel is unidirectional Dart→host; Dart treats
/// `MissingPluginException` as a no-op, so the signal degrades cleanly
/// where no receiver exists (e.g. Linux, iOS, or a fresh runner).
const MethodChannel _windowChromeChannel = MethodChannel(
  'workbench_shell/window_chrome',
);

/// String payload for the canonical `setBrightness` method. Kept
/// stable so hosts can wire their runners against the same vocabulary
/// without depending on Flutter's `Brightness` enum encoding.
String _brightnessPayload(Brightness brightness) =>
    brightness == Brightness.dark ? 'dark' : 'light';

/// Forward [brightness] to the host-window runner. Best-effort —
/// platforms without a receiver report `MissingPluginException`,
/// which the example treats as a benign no-op.
Future<void> _publishBrightness(Brightness brightness) async {
  // The channel is only meaningful on the desktop targets that ship a
  // window runner. Skip the round-trip on platforms where no native
  // implementation exists; the platform's own appearance handling is
  // already correct on those targets.
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      break;
    case TargetPlatform.linux:
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return;
  }
  try {
    await _windowChromeChannel.invokeMethod<void>(
      'setBrightness',
      _brightnessPayload(brightness),
    );
  } on MissingPluginException {
    // Host has not registered the receiver yet (e.g. development
    // start-up race). Subsequent calls succeed once the runner wires
    // up.
  } on PlatformException {
    // Receiver rejected the payload. Swallow rather than crash the
    // example — the chrome still flips in-process.
  }
}

void main() {
  runApp(const WorkbenchExampleApp());
}

class WorkbenchExampleApp extends StatefulWidget {
  const WorkbenchExampleApp({super.key});

  @override
  State<WorkbenchExampleApp> createState() => _WorkbenchExampleAppState();
}

class _WorkbenchExampleAppState extends State<WorkbenchExampleApp> {
  late final WorkbenchThemeController _themeController;
  Brightness? _publishedBrightness;

  @override
  void initState() {
    super.initState();
    // Seed with a synchronous fallback theme so the first frame
    // paints with usable chrome. The controller resolves the real
    // bundled asset for the current brightness slot asynchronously
    // (default themeMode: system), notifyListeners fires when it
    // lands, and the AnimatedBuilder below rebuilds.
    _themeController = WorkbenchThemeController(
      initialTheme: WorkbenchTheme.fromVscodeColorMap(
        const VscodeColorMap(
          name: 'Example Dark',
          baseType: 'vs-dark',
          colors: {},
        ),
      ),
    );
    _themeController.addListener(_handleControllerChanged);
    // Push the initial brightness once after the first frame so the
    // host-window runner has its method channel registered before we
    // call.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleControllerChanged();
    });
  }

  void _handleControllerChanged() {
    final next = _themeController.brightness;
    if (next == _publishedBrightness) return;
    _publishedBrightness = next;
    unawaited(_publishBrightness(next));
  }

  @override
  void dispose() {
    _themeController.removeListener(_handleControllerChanged);
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        final isDark = _themeController.brightness == Brightness.dark;
        return MaterialApp(
          title: 'workbench_shell example',
          debugShowCheckedModeBanner: false,
          // Build the example's ThemeData through the chrome helper so
          // the VS Code button tiers render with their resting fills and
          // 4px corners sourced from the chrome — no host wiring needed.
          // This makes the example a self-contained chrome review surface
          // (SPEC §spec:chrome-material-theming): chrome styling changes are reviewable by
          // running the example standalone.
          theme: applyWorkbenchChrome(
            isDark ? ThemeData.dark() : ThemeData.light(),
            _themeController.theme,
          ),
          home: WorkbenchHome(themeController: _themeController),
        );
      },
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
  const WorkbenchHome({super.key, required this.themeController});

  final WorkbenchThemeController themeController;

  @override
  State<WorkbenchHome> createState() => _WorkbenchHomeState();
}

class _WorkbenchHomeState extends State<WorkbenchHome> {
  bool _panelVisible = true;
  void Function(Object id)? _focusPanelById;
  final NotificationService _notificationService = NotificationService();

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }

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
    ActivityBarItem(
      id: 'buttons',
      label: 'Buttons',
      icon: Symbols.smart_button_rounded,
    ),
    ActivityBarItem(
      id: 'notifications',
      label: 'Notifications',
      icon: Symbols.notifications_rounded,
    ),
    ActivityBarItem(
      id: 'settings',
      label: 'Settings',
      icon: Symbols.settings_rounded,
      zone: ActivityBarZone.bottom,
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
                child: NotificationHost(
                  service: _notificationService,
                  bottomInset: WorkbenchLayoutConstants.statusBarHeight,
                  child: WorkbenchLayout(
                    activityBarItems: _activityBarItems,
                    containerBuilder: _buildContainerSpec,
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
          ),
        );
      },
    );
  }

  /// Map an activity-bar container id to its typed view-descriptor spec
  /// (§spec:view-stack). Explorer is a real three-view stack; the
  /// single-purpose containers each return one merged view so the body fills
  /// the sidebar (no lone non-collapsible header).
  WorkbenchViewContainerSpec _buildContainerSpec(String containerId) {
    switch (containerId) {
      case 'explorer':
        return WorkbenchViewContainerSpec(
          views: _explorerViews(_notificationService),
        );
      case 'search':
        return _mergedView(
          id: 'search',
          title: 'Search',
          body: (_) => const _SidebarBodyPlaceholder(
            text: 'Search sidebar — host-supplied content lands here.',
          ),
        );
      case 'buttons':
        return _mergedView(
          id: 'buttons',
          title: 'Buttons',
          body: (_) => const _ButtonsReviewSidebar(),
        );
      case 'notifications':
        return _mergedView(
          id: 'notifications',
          title: 'Notifications',
          body: (_) => _NotificationsDemoSidebar(service: _notificationService),
        );
      case 'settings':
        return _mergedView(
          id: 'settings',
          title: 'Settings',
          body: (_) => _SettingsSidebar(themeController: widget.themeController),
        );
    }
    return const WorkbenchViewContainerSpec(views: []);
  }

  /// A single-purpose container: one merged view whose body fills the
  /// sidebar, preserving the full-body appearance these sidebars had before
  /// the view-stack inversion.
  WorkbenchViewContainerSpec _mergedView({
    required String id,
    required String title,
    required WidgetBuilder body,
  }) {
    return WorkbenchViewContainerSpec(
      mergeSingleView: true,
      views: [WorkbenchViewDescriptor(id: id, title: title, bodyBuilder: body)],
    );
  }
}

/// Notifications demo sidebar — triggers cards through the
/// [NotificationService] so an operator can exercise every API
/// surface from the example app (SPEC §spec:notification-center verify criteria).
class _NotificationsDemoSidebar extends StatefulWidget {
  const _NotificationsDemoSidebar({required this.service});

  final NotificationService service;

  @override
  State<_NotificationsDemoSidebar> createState() =>
      _NotificationsDemoSidebarState();
}

class _NotificationsDemoSidebarState extends State<_NotificationsDemoSidebar> {
  int _counter = 0;

  /// Outstanding progress demos so cancel/cleanup can find them. Keyed
  /// by the controller's notification id.
  final Map<Object, _DemoProgressJob> _jobs = {};

  @override
  void dispose() {
    for (final job in _jobs.values) {
      job.dispose();
    }
    _jobs.clear();
    super.dispose();
  }

  void _show(NotificationSeverity severity, String message) {
    widget.service.show(severity: severity, message: '$message #${++_counter}');
  }

  void _showBurst(int count, NotificationSeverity severity) {
    for (var i = 0; i < count; i++) {
      _show(severity, severity.name);
    }
  }

  void _showOverflowMix() {
    widget.service.show(
      severity: NotificationSeverity.warning,
      message: 'Persistent warning — stays in the visible stack',
    );
    for (var i = 0; i < 5; i++) {
      _show(NotificationSeverity.info, 'Burst info');
    }
  }

  /// Determinate progress — ticks from 0 to 100 % over ~5 s, then
  /// converts the card to a 6 s success toast via
  /// `complete(successMessage:)`.
  void _showDeterminateProgress() {
    final controller = widget.service.showProgress(
      message: 'Saving project file…',
    );
    final job = _DemoProgressJob(controller);
    _jobs[controller.id] = job;
    job.runDeterminate(onDone: () => _jobs.remove(controller.id));
  }

  /// Indeterminate progress — runs until the demo timer elapses or the
  /// host's `dispose` cleans it up. Demonstrates the spinner variant.
  void _showIndeterminateProgress() {
    final controller = widget.service.showProgress(
      message: 'Refreshing index…',
    );
    final job = _DemoProgressJob(controller);
    _jobs[controller.id] = job;
    job.runIndeterminate(onDone: () => _jobs.remove(controller.id));
  }

  /// Cancellable indeterminate progress. When the operator presses
  /// Cancel, the demo observes the cancellation future and converts
  /// the card to a persistent error toast via `fail`.
  void _showCancellableProgress() {
    final controller = widget.service.showProgress(
      message: 'Long-running upload…',
      cancellable: true,
    );
    final job = _DemoProgressJob(controller);
    _jobs[controller.id] = job;
    job.runCancellable(onDone: () => _jobs.remove(controller.id));
  }

  void _showWithAction() {
    var dismissedId = Object();
    dismissedId = widget.service.show(
      severity: NotificationSeverity.info,
      message: 'Tap Undo to dismiss in the same frame',
      actions: [
        NotificationAction(
          label: 'Undo',
          onInvoke: () {
            // Demonstrate a follow-up notification — the action card
            // is dismissed by the host immediately, so a new card
            // here is the canonical pattern for "keep state visible".
            widget.service.show(
              severity: NotificationSeverity.success,
              message: 'Undone (action ran on #${dismissedId.hashCode})',
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Notifications',
            style: theme.sectionTitle.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
          Text(
            'Cards anchor bottom-right. Info and success self-dismiss '
            'after 6 s; warning and error persist until dismissed. '
            'Hover or backgrounding the window pauses the timer.',
            style: theme.bodyText.copyWith(color: theme.descriptionForeground),
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(
            label: 'Info',
            onTap: () => _show(NotificationSeverity.info, 'Info notice'),
          ),
          _DemoButton(
            label: 'Success',
            onTap: () => _show(NotificationSeverity.success, 'Saved'),
          ),
          _DemoButton(
            label: 'Warning',
            onTap: () => _show(NotificationSeverity.warning, 'Heads up'),
          ),
          _DemoButton(
            label: 'Error',
            onTap: () => _show(NotificationSeverity.error, 'Failed'),
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(
            label: 'Burst: 3 info (stack)',
            onTap: () => _showBurst(3, NotificationSeverity.info),
          ),
          _DemoButton(
            label: 'Burst: 7 info (overflow)',
            onTap: () => _showBurst(7, NotificationSeverity.info),
          ),
          _DemoButton(label: 'Mix: warning + 5 info', onTap: _showOverflowMix),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(label: 'With action button', onTap: _showWithAction),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(
            label: 'Progress: determinate (5 s → success)',
            onTap: _showDeterminateProgress,
          ),
          _DemoButton(
            label: 'Progress: indeterminate (4 s → success)',
            onTap: _showIndeterminateProgress,
          ),
          _DemoButton(
            label: 'Progress: cancellable (cancel → error)',
            onTap: _showCancellableProgress,
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(label: 'Clear all', onTap: widget.service.clear),
        ],
      ),
    );
  }
}

/// Compact button used by the notifications demo sidebar. Renders the
/// themed secondary tier ([FilledButton.tonal]); `applyWorkbenchChrome`
/// supplies its neutral fill, label, and 4px shape — no hand-rolled
/// chrome here (§spec:chrome-material-theming).
class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: WorkbenchLayoutConstants.spacingXxs,
      ),
      child: FilledButton.tonal(onPressed: onTap, child: Text(label)),
    );
  }
}

/// Settings sidebar — exposes the brightness-paired theme controls
/// driven by [WorkbenchThemeController], mirroring VS Code's own
/// settings layout: an "Auto detect color scheme" checkbox plus three
/// dropdown fields ("Color theme", "Preferred dark color theme",
/// "Preferred light color theme"). When auto-detect is on, the
/// "Color theme" field is disabled and the active theme is paired to
/// system brightness via the two preferred slots; when off, the
/// active theme is whatever the "Color theme" dropdown picks.
class _SettingsSidebar extends StatelessWidget {
  const _SettingsSidebar({required this.themeController});

  final WorkbenchThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isSystem = themeController.themeMode == ThemeMode.system;
        final lightThemes = themeController.availableThemes
            .where((e) => e.brightness == Brightness.light)
            .toList();
        final darkThemes = themeController.availableThemes
            .where((e) => e.brightness == Brightness.dark)
            .toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AutoDetectToggle(
                isOn: isSystem,
                onChanged: (next) {
                  if (next) {
                    themeController.themeMode = ThemeMode.system;
                  } else {
                    // Pin to whichever brightness is currently
                    // displayed so flipping auto-detect off doesn't
                    // visibly change the active theme.
                    themeController.themeMode =
                        themeController.brightness == Brightness.light
                        ? ThemeMode.light
                        : ThemeMode.dark;
                  }
                },
              ),
              const SizedBox(height: WorkbenchLayoutConstants.spacingXl),
              _ThemeDropdownField(
                label: 'Color theme',
                description:
                    'Specifies the color theme used in the workbench '
                    'when "Auto detect color scheme" is off.',
                entries: themeController.availableThemes,
                value: themeController.selectedFilename,
                enabled: !isSystem,
                onChanged: (filename) {
                  if (filename != null) {
                    themeController.selectTheme(filename);
                  }
                },
              ),
              const SizedBox(height: WorkbenchLayoutConstants.spacingXl),
              _ThemeDropdownField(
                label: 'Preferred dark color theme',
                description:
                    'Used when the system is in dark mode and '
                    '"Auto detect color scheme" is on.',
                entries: darkThemes,
                value: themeController.preferredDark,
                enabled: true,
                onChanged: (filename) {
                  if (filename != null) {
                    themeController.preferredDark = filename;
                  }
                },
              ),
              const SizedBox(height: WorkbenchLayoutConstants.spacingXl),
              _ThemeDropdownField(
                label: 'Preferred light color theme',
                description:
                    'Used when the system is in light mode and '
                    '"Auto detect color scheme" is on.',
                entries: lightThemes,
                value: themeController.preferredLight,
                enabled: true,
                onChanged: (filename) {
                  if (filename != null) {
                    themeController.preferredLight = filename;
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// "Auto detect color scheme" checkbox row. Toggles
/// [WorkbenchThemeController.themeMode] between [ThemeMode.system] and
/// the manual slot matching whichever brightness is currently
/// displayed, so flipping the checkbox doesn't visibly swap the theme
/// the user is looking at.
class _AutoDetectToggle extends StatelessWidget {
  const _AutoDetectToggle({required this.isOn, required this.onChanged});

  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return InkWell(
      onTap: () => onChanged(!isOn),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: WorkbenchLayoutConstants.spacingSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isOn ? Symbols.check_box : Symbols.check_box_outline_blank,
              size: 18,
              fill: isOn ? 1 : 0,
              color: isOn
                  ? theme.tabBarIndicatorColor
                  : theme.descriptionForeground,
            ),
            const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto detect color scheme',
                    style: theme.bodyStyle.copyWith(
                      color: theme.foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: WorkbenchLayoutConstants.spacingXxs),
                  Text(
                    'Automatically select a color theme based on the '
                    'system color mode.',
                    style: theme.bodyStyle.copyWith(
                      color: theme.descriptionForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Labelled dropdown for a single theme slot. Disabled state greys
/// out the control and ignores taps — used for "Color theme" while
/// auto-detect is on, where the active theme is derived from the
/// preferred slots rather than picked directly.
class _ThemeDropdownField extends StatelessWidget {
  const _ThemeDropdownField({
    required this.label,
    required this.description,
    required this.entries,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String description;
  final List<WorkbenchThemeEntry> entries;
  final String value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    final labelColor = enabled
        ? theme.foreground
        : theme.foreground.withValues(alpha: 0.55);
    final descriptionColor = enabled
        ? theme.descriptionForeground
        : theme.descriptionForeground.withValues(alpha: 0.55);
    final itemColor = enabled
        ? theme.foreground
        : theme.foreground.withValues(alpha: 0.55);
    // Defensive: if the supplied value isn't in the entry list (a
    // stored preference for a theme that's no longer bundled), pass
    // null to the dropdown so it doesn't assert. The user can pick a
    // new value from the menu to re-seed the slot.
    final resolvedValue = entries.any((e) => e.filename == value)
        ? value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Form label — settings dropdown caption follows the §spec:chrome-typography-canon
        // `labelText` tier (13 / w500), not the pane-header tier
        // that `sectionTitle` reserves for sidebar/panel grouping.
        Text(label, style: theme.labelText.copyWith(color: labelColor)),
        const SizedBox(height: WorkbenchLayoutConstants.spacingXxs),
        Text(
          description,
          style: theme.bodyStyle.copyWith(color: descriptionColor),
        ),
        const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
        Container(
          decoration: BoxDecoration(
            color: theme.inputBackground,
            borderRadius: WorkbenchLayoutConstants.containerRadius,
            border: Border.all(color: theme.inputBorder),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: WorkbenchLayoutConstants.spacingSm,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: resolvedValue,
              isExpanded: true,
              isDense: true,
              dropdownColor: theme.dropdownBackground,
              style: theme.bodyStyle.copyWith(color: itemColor),
              iconEnabledColor: theme.descriptionForeground,
              iconDisabledColor: theme.descriptionForeground.withValues(
                alpha: 0.5,
              ),
              items: [
                for (final entry in entries)
                  DropdownMenuItem<String>(
                    value: entry.filename,
                    child: Text(
                      entry.label,
                      style: theme.bodyStyle.copyWith(color: theme.foreground),
                    ),
                  ),
              ],
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
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

/// Explorer view container — a real three-view stack (§spec:view-stack):
/// "Open Editors", "Outline", "Timeline". Three views make every pane
/// collapsible (container-derived, no host flag): click a header — or focus
/// it and press Enter/Space — to hide and show its body while the leading
/// chevron flips, redistributing freed height to siblings.
///
/// Header actions (§spec:section-header-actions): hover the "Open Editors"
/// header to reveal its refresh and new-file buttons; click one and the pane
/// stays expanded (the action does not toggle the header). Collapse the pane
/// and the actions vanish entirely.
List<WorkbenchViewDescriptor> _explorerViews(NotificationService service) {
  void notify(String message) {
    service.show(severity: NotificationSeverity.info, message: message);
  }

  return [
    WorkbenchViewDescriptor(
      id: 'open-editors',
      title: 'Open Editors',
      actions: [
        _explorerHeaderAction(
          icon: Symbols.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () => notify('Refreshed Open Editors'),
        ),
        _explorerHeaderAction(
          icon: Symbols.add_rounded,
          tooltip: 'New File',
          onPressed: () => notify('New file'),
        ),
      ],
      bodyBuilder: (_) => const _SidebarBodyPlaceholder(
        text: 'main.dart\nworkbench_content.dart',
      ),
    ),
    WorkbenchViewDescriptor(
      id: 'outline',
      title: 'Outline',
      initiallyExpanded: false,
      bodyBuilder: (_) => const _SidebarBodyPlaceholder(
        text: 'WorkbenchViewPane\nWorkbenchSubsection\nWorkbenchCard',
      ),
    ),
    WorkbenchViewDescriptor(
      id: 'timeline',
      title: 'Timeline',
      actions: [
        _explorerHeaderAction(
          icon: Symbols.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () => notify('Refreshed Timeline'),
        ),
      ],
      bodyBuilder: (_) => const _SidebarBodyPlaceholder(
        text: 'Timeline — recent edits land here.',
      ),
    ),
  ];
}

/// Compact icon button sized to the pane-header row — the host supplies the
/// control (§spec:form-controls-excluded); the shell only places and reveals
/// it.
Widget _explorerHeaderAction({
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
}) {
  return IconButton(
    icon: Icon(icon, size: WorkbenchLayoutConstants.iconMd),
    tooltip: tooltip,
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
  );
}

/// VS Code's three button tiers rendered through the chrome helper —
/// `applyWorkbenchChrome` themes [FilledButton] (primary),
/// [FilledButton.tonal] (secondary), and [TextButton] (text/link),
/// each flat at rest with VS Code's rectangular 4px corners
/// ([WorkbenchLayoutConstants.buttonShape]). Without the helper these
/// would render Material 3's accent/secondary-container colors and the
/// default pill ([StadiumBorder]). This is the self-contained chrome
/// review surface (SPEC §spec:chrome-material-theming): run the example standalone to review the
/// button taxonomy, no host needed.
class _ButtonsReviewSidebar extends StatelessWidget {
  const _ButtonsReviewSidebar();

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'VS Code buttons',
            style: theme.sectionTitle.copyWith(color: theme.foreground),
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
          Text(
            'The three VS Code button tiers, themed by applyWorkbenchChrome: '
            'a primary (accent fill), a secondary (neutral fill), and a '
            'text/link button. All flat at rest with VS Code\'s 4px '
            'rectangle, not Material 3\'s pill — none casts an at-rest shadow.',
            style: theme.bodyText.copyWith(color: theme.descriptionForeground),
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          FilledButton(onPressed: () {}, child: const Text('Primary')),
          const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
          FilledButton.tonal(onPressed: () {}, child: const Text('Secondary')),
          const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
          TextButton(onPressed: () {}, child: const Text('Text / link')),
        ],
      ),
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
            // Value readout — `valueText` is the §spec:editor-derived-surfaces editor-derived
            // numeric tier (tabular monospace at editor size). Earlier
            // drafts reached for `sectionTitle`, which the canon now
            // reserves for sidebar/panel pane headers.
            'Counter: $_count',
            style: theme.valueText.copyWith(color: theme.foreground),
          ),
        ],
      ),
    );
  }
}

/// Bookkeeping for an in-flight notification progress demo. Owns a
/// timer plus subscriptions so the sidebar can clean up if the
/// operator hits Clear All or navigates away mid-run.
class _DemoProgressJob {
  _DemoProgressJob(this.controller);

  final NotificationProgressController controller;
  Timer? _timer;

  /// Tick from 0 to 100 % over ~5 s, then complete with a success
  /// message.
  void runDeterminate({required VoidCallback onDone}) {
    var step = 0;
    const total = 20;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!controller.isActive) {
        timer.cancel();
        onDone();
        return;
      }
      step += 1;
      final value = step / total;
      controller.report(
        progress: value,
        message: 'Saving project file… ${(value * 100).round()} %',
      );
      if (step >= total) {
        timer.cancel();
        controller.complete(successMessage: 'Project file saved.');
        onDone();
      }
    });
  }

  /// Indeterminate spinner for ~4 s, then complete with a success
  /// message.
  void runIndeterminate({required VoidCallback onDone}) {
    _timer = Timer(const Duration(seconds: 4), () {
      if (!controller.isActive) {
        onDone();
        return;
      }
      controller.complete(successMessage: 'Index refreshed.');
      onDone();
    });
  }

  /// Cancellable indeterminate job — waits for the operator to press
  /// Cancel. On cancel, terminates with a persistent error toast so
  /// the failure is visible.
  void runCancellable({required VoidCallback onDone}) {
    controller.cancellation.then((_) {
      if (!controller.isActive) {
        onDone();
        return;
      }
      controller.fail('Upload cancelled.');
      onDone();
    });
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (controller.isActive) {
      controller.complete();
    }
  }
}

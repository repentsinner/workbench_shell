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
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Storage key for the persisted [WorkbenchLayoutState] blob
/// (§spec:layout-state-persistence). The shell owns no storage — the host names
/// the key and owns the bytes (§spec:capability-boundary).
const String _layoutStateKey = 'workbench_shell_example.layout_state';

Future<void> main() async {
  // Await the persistence load before the first build so the layout seeds its
  // arrangement once from the rehydrated value (§spec:layout-state-persistence).
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    WorkbenchExampleApp(
      prefs: prefs,
      initialLayoutState: _loadLayoutState(prefs),
    ),
  );
}

/// Decode the persisted layout state, tolerating a missing or corrupt value by
/// falling back to the empty default (the shell then seeds every store from
/// descriptor defaults).
WorkbenchLayoutState _loadLayoutState(SharedPreferences prefs) {
  final raw = prefs.getString(_layoutStateKey);
  if (raw == null) return const WorkbenchLayoutState();
  try {
    return WorkbenchLayoutState.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  } catch (_) {
    return const WorkbenchLayoutState();
  }
}

class WorkbenchExampleApp extends StatefulWidget {
  const WorkbenchExampleApp({
    super.key,
    this.prefs,
    this.initialLayoutState = const WorkbenchLayoutState(),
  });

  /// Host key–value store for cross-restart persistence. Null in widget tests
  /// (persistence degrades to a no-op).
  final SharedPreferences? prefs;

  /// The rehydrated layout arrangement seeded into the shell on first build.
  final WorkbenchLayoutState initialLayoutState;

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
          home: WorkbenchHome(
            themeController: _themeController,
            prefs: widget.prefs,
            initialLayoutState: widget.initialLayoutState,
          ),
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

/// Host-defined intent to toggle Zen mode. The shell exposes the
/// `zenMode` property (§spec:editing-modes); the host owns the state and
/// the menu affordance.
class ToggleZenModeIntent extends Intent {
  const ToggleZenModeIntent();
}

/// Host-defined intent to toggle centered layout (§spec:editing-modes).
class ToggleCenteredLayoutIntent extends Intent {
  const ToggleCenteredLayoutIntent();
}

/// Host-defined intent to swap the side bar to the opposite edge
/// (§spec:sidebar-position). The shell exposes the `sidebarPosition` property;
/// the host owns the state and the menu affordance.
class ToggleSidebarPositionIntent extends Intent {
  const ToggleSidebarPositionIntent();
}

/// Host-defined intent to toggle the primary side bar
/// (§spec:layout-customization). The shell exposes the `sidebarVisible`
/// property; the host owns the state, the menu affordance, and VS Code's Cmd+B
/// keybinding.
class ToggleSidebarIntent extends Intent {
  const ToggleSidebarIntent();
}

/// Host-defined intent to toggle the secondary side bar
/// (§spec:secondary-sidebar). The shell exposes the `secondarySideBarVisible`
/// property; the host owns the state, the menu affordance, and VS Code's
/// Cmd+Alt+B keybinding.
class ToggleSecondarySideBarIntent extends Intent {
  const ToggleSecondarySideBarIntent();
}

/// Host-defined intent to toggle the status bar (§spec:layout-customization).
/// The shell exposes the `statusBarVisible` property; the host owns the state
/// and the menu affordance. VS Code has no default keybinding for it.
class ToggleStatusBarIntent extends Intent {
  const ToggleStatusBarIntent();
}

/// Host-defined intent to set the bottom panel's alignment
/// (§spec:panel-alignment) to a specific value. The View menu's Align Panel
/// radio submenu dispatches one per choice; the shell exposes the
/// `panelAlignment` property and the host owns the state.
class SetPanelAlignmentIntent extends Intent {
  const SetPanelAlignmentIntent(this.alignment);
  final WorkbenchPanelAlignment alignment;
}


class WorkbenchHome extends StatefulWidget {
  const WorkbenchHome({
    super.key,
    required this.themeController,
    this.prefs,
    this.initialLayoutState = const WorkbenchLayoutState(),
  });

  final WorkbenchThemeController themeController;

  /// Host key–value store; null in tests (persistence no-op).
  final SharedPreferences? prefs;

  /// Rehydrated arrangement seeded into [WorkbenchLayout.initialLayoutState].
  final WorkbenchLayoutState initialLayoutState;

  @override
  State<WorkbenchHome> createState() => _WorkbenchHomeState();
}

class _WorkbenchHomeState extends State<WorkbenchHome> {
  bool _panelVisible = true;
  // Editing modes (§spec:editing-modes): host-owned, driven from the View
  // menu and fed back into the shell's controlled `zenMode` / `centeredLayout`
  // properties — the same host-managed pattern as `_panelVisible`.
  bool _zenMode = false;
  bool _centeredLayout = false;
  // Side-bar position (§spec:sidebar-position): host-owned, driven from the View
  // menu and fed back into the shell's controlled `sidebarPosition` property.
  WorkbenchSidebarPosition _sidebarPosition = WorkbenchSidebarPosition.left;
  // Primary side bar (§spec:layout-customization): host-owned visibility, driven
  // from the View menu (and VS Code's Cmd+B) into the shell's controlled
  // `sidebarVisible` property. The shell also raises the toggle when the active
  // activity icon is tapped, so the host updates this on `onSidebarVisibilityChanged`.
  bool _sidebarVisible = true;
  // Secondary side bar (§spec:secondary-sidebar): host-owned visibility, driven
  // from the View menu (and VS Code's Cmd+Alt+B) into the shell's controlled
  // `secondarySideBarVisible` property. Hidden by default, matching VS Code. The
  // host assigns which container it shows (here, the "Search" container) — the
  // secondary has no activity bar of its own.
  bool _secondarySideBarVisible = false;
  // Status bar (§spec:layout-customization): host-owned visibility, driven from
  // the View menu into the shell's controlled `statusBarVisible` property.
  bool _statusBarVisible = true;
  // Panel alignment (§spec:panel-alignment): host-owned, driven from the View
  // menu into the shell's controlled `panelAlignment` property. Center is the
  // default — the panel spans the editor while both side bars run full height.
  WorkbenchPanelAlignment _panelAlignment = WorkbenchPanelAlignment.center;
  void Function(Object id)? _focusPanelById;
  final NotificationService _notificationService = NotificationService();

  /// Host-persisted sidebar width and panel height (§spec:resize-geometry).
  /// Dogfoods the seed-plus-commit `initialSidebarWidth`/`onSidebarWidthChangeEnd`
  /// and `initialPanelHeight`/`onPanelHeightChangeEnd` hooks the same way
  /// [_explorerSizes] dogfoods view sizing: null seeds the shell default; the
  /// shell owns the live value during a drag and reports the final value once on
  /// release, where a real consumer would persist it across restarts.
  double? _sidebarWidth;
  double? _panelHeight;

  /// Host-persisted secondary side-bar width (§spec:secondary-sidebar /
  /// §spec:resize-geometry). Dogfoods the secondary's seed-plus-commit
  /// `initialSecondarySideBarWidth`/`onSecondarySideBarWidthChangeEnd` hooks
  /// exactly as [_sidebarWidth] does for the primary.
  double? _secondarySideBarWidth;

  /// Notifications demo state, shared by the "Severities" and "Progress"
  /// view panes (§spec:view-stack) so both drive the same service.
  late final _NotificationsDemoController _notificationsDemo =
      _NotificationsDemoController(_notificationService);

  @override
  void dispose() {
    _notificationsDemo.dispose();
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

  void _toggleZenMode() {
    setState(() => _zenMode = !_zenMode);
  }

  void _toggleCenteredLayout() {
    setState(() => _centeredLayout = !_centeredLayout);
  }

  void _toggleSidebarPosition() {
    setState(
      () => _sidebarPosition = _sidebarPosition == WorkbenchSidebarPosition.left
          ? WorkbenchSidebarPosition.right
          : WorkbenchSidebarPosition.left,
    );
  }

  void _togglePrimarySideBar() {
    setState(() => _sidebarVisible = !_sidebarVisible);
  }

  void _toggleSecondarySideBar() {
    setState(() => _secondarySideBarVisible = !_secondarySideBarVisible);
  }

  void _toggleStatusBar() {
    setState(() => _statusBarVisible = !_statusBarVisible);
  }

  void _setPanelAlignment(WorkbenchPanelAlignment alignment) {
    setState(() => _panelAlignment = alignment);
  }

  /// Persist the shell's arrangement snapshot to the host store
  /// (§spec:layout-state-persistence). The shell hands over a JSON-encodable
  /// map; the host owns the codec and the bytes. No-op when no store is wired
  /// (widget tests).
  void _persistLayoutState(WorkbenchLayoutState state) {
    widget.prefs?.setString(_layoutStateKey, jsonEncode(state.toJson()));
  }

  /// Display name for an alignment, shown on the Align Panel radio items.
  static String _panelAlignmentLabel(WorkbenchPanelAlignment alignment) {
    switch (alignment) {
      case WorkbenchPanelAlignment.center:
        return 'Center';
      case WorkbenchPanelAlignment.justify:
        return 'Justify';
      case WorkbenchPanelAlignment.left:
        return 'Left';
      case WorkbenchPanelAlignment.right:
        return 'Right';
    }
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

  /// VS Code's primary side bar toggle: Cmd+B on macOS, Ctrl+B elsewhere
  /// (§spec:layout-customization). Both activators live in the map so the
  /// binding fires regardless of platform.
  static const _primarySideBarShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyB, meta: true): ToggleSidebarIntent(),
    SingleActivator(LogicalKeyboardKey.keyB, control: true):
        ToggleSidebarIntent(),
  };

  /// VS Code's secondary side bar toggle: Cmd+Alt+B on macOS, Ctrl+Alt+B
  /// elsewhere (§spec:secondary-sidebar). Both activators live in the map so the
  /// binding fires regardless of platform.
  static const _secondarySideBarShortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyB, meta: true, alt: true):
        ToggleSecondarySideBarIntent(),
    SingleActivator(LogicalKeyboardKey.keyB, control: true, alt: true):
        ToggleSecondarySideBarIntent(),
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
          shortcuts: {
            ...scope.shortcuts,
            ..._ctrlVariantShortcuts,
            ..._primarySideBarShortcuts,
            ..._secondarySideBarShortcuts,
          },
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
                ToggleZenModeIntent: CallbackAction<ToggleZenModeIntent>(
                  onInvoke: (_) {
                    _toggleZenMode();
                    return null;
                  },
                ),
                ToggleCenteredLayoutIntent:
                    CallbackAction<ToggleCenteredLayoutIntent>(
                      onInvoke: (_) {
                        _toggleCenteredLayout();
                        return null;
                      },
                    ),
                ToggleSidebarPositionIntent:
                    CallbackAction<ToggleSidebarPositionIntent>(
                      onInvoke: (_) {
                        _toggleSidebarPosition();
                        return null;
                      },
                    ),
                ToggleSidebarIntent: CallbackAction<ToggleSidebarIntent>(
                  onInvoke: (_) {
                    _togglePrimarySideBar();
                    return null;
                  },
                ),
                ToggleSecondarySideBarIntent:
                    CallbackAction<ToggleSecondarySideBarIntent>(
                      onInvoke: (_) {
                        _toggleSecondarySideBar();
                        return null;
                      },
                    ),
                ToggleStatusBarIntent: CallbackAction<ToggleStatusBarIntent>(
                  onInvoke: (_) {
                    _toggleStatusBar();
                    return null;
                  },
                ),
                SetPanelAlignmentIntent:
                    CallbackAction<SetPanelAlignmentIntent>(
                      onInvoke: (intent) {
                        _setPanelAlignment(intent.alignment);
                        return null;
                      },
                    ),
              },
              child: WorkbenchMenuBar(
                // VS Code's View menu structure built from the §spec:menu-model
                // tree: an Appearance submenu of checkable visibility toggles
                // that itself nests the Align Panel radio submenu (canon: View ▸
                // Appearance ▸ Align Panel ▸ value), then the shell-derived panel
                // focus commands. Checkable entries carry the host's current
                // state (a real check in-window, a leading "✓ " on macOS) so no
                // entry mutates its label to convey state.
                entries: [
                  WorkbenchMenuSubmenu(
                    label: 'Appearance',
                    children: [
                      WorkbenchMenuCheckbox(
                        intent: const ToggleZenModeIntent(),
                        label: 'Zen Mode',
                        checked: _zenMode,
                      ),
                      WorkbenchMenuCheckbox(
                        intent: const ToggleCenteredLayoutIntent(),
                        label: 'Centered Layout',
                        checked: _centeredLayout,
                      ),
                      const WorkbenchMenuSeparator(),
                      WorkbenchMenuCheckbox(
                        intent: const ToggleSidebarIntent(),
                        label: 'Primary Side Bar',
                        checked: _sidebarVisible,
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyB,
                          meta: true,
                        ),
                      ),
                      WorkbenchMenuCheckbox(
                        intent: const ToggleSecondarySideBarIntent(),
                        label: 'Secondary Side Bar',
                        checked: _secondarySideBarVisible,
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyB,
                          meta: true,
                          alt: true,
                        ),
                      ),
                      WorkbenchMenuCheckbox(
                        intent: const ToggleStatusBarIntent(),
                        label: 'Status Bar',
                        checked: _statusBarVisible,
                      ),
                      WorkbenchMenuCheckbox(
                        intent: const ToggleBottomPanelIntent(),
                        label: 'Panel',
                        checked: _panelVisible,
                        shortcut: const SingleActivator(
                          LogicalKeyboardKey.keyJ,
                          meta: true,
                        ),
                      ),
                      const WorkbenchMenuSeparator(),
                      WorkbenchViewMenuTab(
                        intent: const ToggleSidebarPositionIntent(),
                        label:
                            _sidebarPosition == WorkbenchSidebarPosition.left
                            ? 'Move Primary Side Bar Right'
                            : 'Move Primary Side Bar Left',
                      ),
                      // Align Panel nests inside Appearance (canon), a radio
                      // submenu two levels deep — View ▸ Appearance ▸ Align
                      // Panel ▸ value.
                      WorkbenchMenuSubmenu(
                        label: 'Align Panel',
                        children: [
                          for (final alignment in WorkbenchPanelAlignment.values)
                            WorkbenchMenuRadio(
                              intent: SetPanelAlignmentIntent(alignment),
                              label: _panelAlignmentLabel(alignment),
                              selected: _panelAlignment == alignment,
                            ),
                        ],
                      ),
                    ],
                  ),
                  const WorkbenchMenuSeparator(),
                  ...scope.viewMenuTabs,
                ],
                child: NotificationHost(
                  service: _notificationService,
                  bottomInset: WorkbenchLayoutConstants.statusBarHeight,
                  child: WorkbenchLayout(
                    activityBarItems: _activityBarItems,
                    containerBuilder: _buildContainerSpec,
                    editor: const _EditorPlaceholder(),
                    bottomPanel: scope.tabbedPanel,
                    showBottomPanel: _panelVisible,
                    // Cross-restart persistence (§spec:layout-state-persistence):
                    // seed the rehydrated arrangement and write every change back
                    // to the host store. The shell reconciles the seed against
                    // live descriptors and owns the model; the host owns the bytes.
                    initialLayoutState: widget.initialLayoutState,
                    onLayoutStateChanged: _persistLayoutState,
                    initialSidebarWidth: _sidebarWidth,
                    onSidebarWidthChangeEnd: (w) => _sidebarWidth = w,
                    initialPanelHeight: _panelHeight,
                    onPanelHeightChangeEnd: (h) => _panelHeight = h,
                    // Controlled editing modes (§spec:editing-modes): the host
                    // owns the booleans and the shell renders them, mirroring
                    // the showBottomPanel pattern above.
                    zenMode: _zenMode,
                    onZenModeChanged: (next) =>
                        setState(() => _zenMode = next),
                    centeredLayout: _centeredLayout,
                    onCenteredLayoutChanged: (next) =>
                        setState(() => _centeredLayout = next),
                    // Controlled side-bar position (§spec:sidebar-position): the
                    // host owns the edge and the shell renders it, mirroring the
                    // editing-mode properties above.
                    sidebarPosition: _sidebarPosition,
                    onSidebarPositionChanged: (next) =>
                        setState(() => _sidebarPosition = next),
                    // Controlled panel alignment (§spec:panel-alignment): the
                    // host owns the alignment and the shell re-parents the panel
                    // to match, mirroring the side-bar position property above.
                    panelAlignment: _panelAlignment,
                    onPanelAlignmentChanged: (next) =>
                        setState(() => _panelAlignment = next),
                    // Controlled primary side-bar visibility
                    // (§spec:layout-customization): the host owns the flag; the
                    // shell renders it and also raises onSidebarVisibilityChanged
                    // when the active activity icon is tapped.
                    sidebarVisible: _sidebarVisible,
                    onSidebarVisibilityChanged: (next) =>
                        setState(() => _sidebarVisible = next),
                    // Secondary side bar (§spec:secondary-sidebar): the host
                    // owns its visibility and assigns a dedicated multi-view
                    // container the activity bar never lists. That container has
                    // no activity item to name it, so it titles itself through
                    // WorkbenchViewContainerSpec.title (§spec:view-container-title)
                    // — without which its composite title strip would be blank.
                    // It renders on the editor's opposite edge from the primary
                    // and follows when the primary swaps sides. The width
                    // dogfoods the seed-plus-commit hook like the primary.
                    secondaryViewContainerId: 'secondary',
                    onSecondaryViewContainerChanged: (_) {},
                    secondarySideBarVisible: _secondarySideBarVisible,
                    onSecondarySideBarVisibilityChanged: (next) =>
                        setState(() => _secondarySideBarVisible = next),
                    initialSecondarySideBarWidth: _secondarySideBarWidth,
                    onSecondarySideBarWidthChangeEnd: (w) =>
                        _secondarySideBarWidth = w,
                    statusBar: const WorkbenchStatusBar(
                      leading: [
                        WorkbenchStatusBarItem(
                          icon: Symbols.info_rounded,
                          label: 'workbench_shell example',
                        ),
                      ],
                    ),
                    // Controlled status-bar visibility
                    // (§spec:layout-customization): the host owns the flag and
                    // the shell renders it, mirroring the editing-mode toggles.
                    statusBarVisible: _statusBarVisible,
                    onStatusBarVisibilityChanged: (next) =>
                        setState(() => _statusBarVisible = next),
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
  /// (§spec:view-stack). Every container organizes its content into named
  /// view panes — Explorer, Notifications, and Settings are real multi-pane
  /// stacks; Search and Buttons are single named panes. None dumps raw
  /// content into a merged body: the example dogfoods the view-stack the
  /// shell provides.
  WorkbenchViewContainerSpec _buildContainerSpec(String containerId) {
    switch (containerId) {
      case 'explorer':
        // The Explorer dogfoods header drag-reorder (§spec:view-stack). The
        // shell owns the pane order: the host just lists the views and the
        // shell handles the drag, drop indicator, and reordering — no host
        // order state. (A host that needs to persist order across restarts can
        // pass a controlled `order` plus `onReorder`.)
        final byId = _explorerViews(_notificationService);
        // Canon (VS Code): the EXPLORER container title carries only the `⋯`
        // overflow (the Views toggles). New File / New Folder / Refresh /
        // Collapse Folders are VIEW-title actions on the Folders view
        // (explorerView.ts, MenuId.ViewTitle), not container-title actions.
        return WorkbenchViewContainerSpec(
          views: [
            byId['open-editors']!,
            byId['folders']!,
            byId['outline']!,
            byId['timeline']!,
          ],
          // Pane sizing, order, expansion, and visibility all persist through the
          // aggregate WorkbenchLayoutState seam on WorkbenchLayout below — no
          // per-concern seed here (§spec:layout-state-persistence).
        );
      case 'search':
        return const WorkbenchViewContainerSpec(
          views: [
            WorkbenchViewDescriptor(
              id: 'search-results',
              title: 'Results',
              bodyBuilder: _searchResultsBody,
            ),
          ],
        );
      case 'secondary':
        // The secondary side bar's container (§spec:secondary-sidebar). The
        // activity bar never lists it, so the spec-level title is its only title
        // source — without it the composite title strip renders blank
        // (§spec:view-container-title). Two views make it a real pane stack.
        return const WorkbenchViewContainerSpec(
          title: 'Secondary Side Bar',
          views: [
            WorkbenchViewDescriptor(
              id: 'secondary-outline',
              title: 'Outline',
              bodyBuilder: _secondaryOutlineBody,
            ),
            WorkbenchViewDescriptor(
              id: 'secondary-notes',
              title: 'Notes',
              bodyBuilder: _secondaryNotesBody,
            ),
          ],
        );
      case 'buttons':
        return const WorkbenchViewContainerSpec(
          views: [
            WorkbenchViewDescriptor(
              id: 'button-tiers',
              title: 'Button Tiers',
              bodyBuilder: _buttonTiersBody,
            ),
          ],
        );
      case 'notifications':
        return WorkbenchViewContainerSpec(
          views: [
            WorkbenchViewDescriptor(
              id: 'notification-severities',
              title: 'Severities',
              bodyBuilder: (_) =>
                  _NotificationTriggers(controller: _notificationsDemo),
            ),
            WorkbenchViewDescriptor(
              id: 'notification-progress',
              title: 'Progress',
              bodyBuilder: (_) =>
                  _NotificationProgress(controller: _notificationsDemo),
            ),
          ],
        );
      case 'settings':
        return WorkbenchViewContainerSpec(
          views: [
            WorkbenchViewDescriptor(
              id: 'settings-appearance',
              title: 'Appearance',
              bodyBuilder: (_) =>
                  _AppearanceSettings(themeController: widget.themeController),
            ),
            WorkbenchViewDescriptor(
              id: 'settings-color-theme',
              title: 'Color Theme',
              bodyBuilder: (_) =>
                  _ColorThemeSettings(themeController: widget.themeController),
            ),
          ],
        );
    }
    return const WorkbenchViewContainerSpec(views: []);
  }
}

/// Shared inset for example view-pane bodies — tight under the header per
/// canon (§spec:view-stack makes the body flush; the host owns this padding).
const _sidebarBodyPadding = EdgeInsets.fromLTRB(
  WorkbenchLayoutConstants.spacingLg,
  WorkbenchLayoutConstants.spacingSm,
  WorkbenchLayoutConstants.spacingLg,
  WorkbenchLayoutConstants.spacingLg,
);

/// "Results" pane body for the Search container.
Widget _searchResultsBody(BuildContext context) =>
    const _SidebarBodyPlaceholder(
      text: 'Search sidebar — host-supplied content lands here.',
    );

/// "Button Tiers" pane body for the Buttons container.
Widget _buttonTiersBody(BuildContext context) => const _ButtonsReviewSidebar();

/// "Outline" pane body for the secondary side bar container.
Widget _secondaryOutlineBody(BuildContext context) =>
    const _SidebarBodyPlaceholder(
      text: 'Secondary side bar — titled by WorkbenchViewContainerSpec.title.',
    );

/// "Notes" pane body for the secondary side bar container.
Widget _secondaryNotesBody(BuildContext context) =>
    const _SidebarBodyPlaceholder(
      text: 'A container the activity bar never lists names itself here.',
    );

/// Notifications demo controller — holds the demo state (counter, progress
/// jobs) so the "Severities" and "Progress" view panes both drive the shared
/// [NotificationService] (SPEC §spec:notification-center verify criteria).
/// Owned by [_WorkbenchHomeState] and disposed with it.
class _NotificationsDemoController {
  _NotificationsDemoController(this.service);

  final NotificationService service;
  int _counter = 0;

  /// Outstanding progress demos so cancel/cleanup can find them. Keyed
  /// by the controller's notification id.
  final Map<Object, _DemoProgressJob> _jobs = {};

  void dispose() {
    for (final job in _jobs.values) {
      job.dispose();
    }
    _jobs.clear();
  }

  void _show(NotificationSeverity severity, String message) {
    service.show(severity: severity, message: '$message #${++_counter}');
  }

  void _showBurst(int count, NotificationSeverity severity) {
    for (var i = 0; i < count; i++) {
      _show(severity, severity.name);
    }
  }

  void _showOverflowMix() {
    service.show(
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
    final controller = service.showProgress(
      message: 'Saving project file…',
    );
    final job = _DemoProgressJob(controller);
    _jobs[controller.id] = job;
    job.runDeterminate(onDone: () => _jobs.remove(controller.id));
  }

  /// Indeterminate progress — runs until the demo timer elapses or the
  /// host's `dispose` cleans it up. Demonstrates the spinner variant.
  void _showIndeterminateProgress() {
    final controller = service.showProgress(
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
    final controller = service.showProgress(
      message: 'Long-running upload…',
      cancellable: true,
    );
    final job = _DemoProgressJob(controller);
    _jobs[controller.id] = job;
    job.runCancellable(onDone: () => _jobs.remove(controller.id));
  }

  void _showWithAction() {
    var dismissedId = Object();
    dismissedId = service.show(
      severity: NotificationSeverity.info,
      message: 'Tap Undo to dismiss in the same frame',
      actions: [
        NotificationAction(
          label: 'Undo',
          onInvoke: () {
            // Demonstrate a follow-up notification — the action card
            // is dismissed by the host immediately, so a new card
            // here is the canonical pattern for "keep state visible".
            service.show(
              severity: NotificationSeverity.success,
              message: 'Undone (action ran on #${dismissedId.hashCode})',
            );
          },
        ),
      ],
    );
  }

}

/// "Severities" view pane body — triggers a card of each severity, the
/// burst/overflow mixes, and an inline-action card via the demo controller.
class _NotificationTriggers extends StatelessWidget {
  const _NotificationTriggers({required this.controller});

  final _NotificationsDemoController controller;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Padding(
      padding: _sidebarBodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cards anchor bottom-right. Info and success self-dismiss '
            'after 6 s; warning and error persist until dismissed. '
            'Hover or backgrounding the window pauses the timer.',
            style: theme.bodyText.copyWith(color: theme.descriptionForeground),
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(
            label: 'Info',
            onTap: () =>
                controller._show(NotificationSeverity.info, 'Info notice'),
          ),
          _DemoButton(
            label: 'Success',
            onTap: () =>
                controller._show(NotificationSeverity.success, 'Saved'),
          ),
          _DemoButton(
            label: 'Warning',
            onTap: () =>
                controller._show(NotificationSeverity.warning, 'Heads up'),
          ),
          _DemoButton(
            label: 'Error',
            onTap: () => controller._show(NotificationSeverity.error, 'Failed'),
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(
            label: 'Burst: 3 info (stack)',
            onTap: () => controller._showBurst(3, NotificationSeverity.info),
          ),
          _DemoButton(
            label: 'Burst: 7 info (overflow)',
            onTap: () => controller._showBurst(7, NotificationSeverity.info),
          ),
          _DemoButton(
            label: 'Mix: warning + 5 info',
            onTap: controller._showOverflowMix,
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(
            label: 'With action button',
            onTap: controller._showWithAction,
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingLg),
          _DemoButton(label: 'Clear all', onTap: controller.service.clear),
        ],
      ),
    );
  }
}

/// "Progress" view pane body — long-running progress cards (determinate,
/// indeterminate, cancellable) via the demo controller.
class _NotificationProgress extends StatelessWidget {
  const _NotificationProgress({required this.controller});

  final _NotificationsDemoController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _sidebarBodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DemoButton(
            label: 'Progress: determinate (5 s → success)',
            onTap: controller._showDeterminateProgress,
          ),
          _DemoButton(
            label: 'Progress: indeterminate (4 s → success)',
            onTap: controller._showIndeterminateProgress,
          ),
          _DemoButton(
            label: 'Progress: cancellable (cancel → error)',
            onTap: controller._showCancellableProgress,
          ),
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

/// "Appearance" view pane body — the "Auto detect color scheme" toggle,
/// driven by [WorkbenchThemeController] (mirrors VS Code's settings layout).
class _AppearanceSettings extends StatelessWidget {
  const _AppearanceSettings({required this.themeController});

  final WorkbenchThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final isSystem = themeController.themeMode == ThemeMode.system;
        return Padding(
          padding: _sidebarBodyPadding,
          child: _AutoDetectToggle(
            isOn: isSystem,
            onChanged: (next) {
              if (next) {
                themeController.themeMode = ThemeMode.system;
              } else {
                // Pin to whichever brightness is currently displayed so
                // flipping auto-detect off doesn't visibly swap the theme.
                themeController.themeMode =
                    themeController.brightness == Brightness.light
                    ? ThemeMode.light
                    : ThemeMode.dark;
              }
            },
          ),
        );
      },
    );
  }
}

/// "Color Theme" view pane body — the active-theme dropdown plus the
/// preferred dark/light slots, driven by [WorkbenchThemeController]. When
/// auto-detect is on, the "Color theme" field is disabled and the active
/// theme is paired to system brightness via the two preferred slots.
class _ColorThemeSettings extends StatelessWidget {
  const _ColorThemeSettings({required this.themeController});

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
        return Padding(
          padding: _sidebarBodyPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
    // Left-aligned monospace body that wraps to the editor's width
    // (theme.editorStyle resolves the per-platform editor monospace). This
    // makes Centered Layout (§spec:editing-modes) self-evident: with centering
    // off the lines sprawl across a wide window; with it on the editor narrows
    // to the golden-ratio column and centers, and the same text reflows to a
    // comfortable reading width with margins either side — the line-length
    // comfort the feature exists for. Scrolls vertically so the body fills the
    // editor height on any window.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingXl),
      child: Text(
        _editorLoremText,
        style: theme.editorStyle.copyWith(height: 1.6),
      ),
    );
  }
}

/// Filler editor body (§spec:editing-modes demo). Lorem Ipsum, several
/// paragraphs so the column wraps and scrolls on a typical window.
const String _editorLoremText =
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
    'tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim '
    'veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea '
    'commodo consequat. Duis aute irure dolor in reprehenderit in voluptate '
    'velit esse cillum dolore eu fugiat nulla pariatur.\n\n'
    'Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia '
    'deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste '
    'natus error sit voluptatem accusantium doloremque laudantium, totam rem '
    'aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto '
    'beatae vitae dicta sunt explicabo.\n\n'
    'Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut '
    'fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem '
    'sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor '
    'sit amet, consectetur, adipisci velit, sed quia non numquam eius modi '
    'tempora incidunt ut labore et dolore magnam aliquam quaerat voluptatem.\n\n'
    'Quis autem vel eum iure reprehenderit qui in ea voluptate velit esse quam '
    'nihil molestiae consequatur, vel illum qui dolorem eum fugiat quo '
    'voluptas nulla pariatur. At vero eos et accusamus et iusto odio dignissimos '
    'ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti.';

class _SidebarBodyPlaceholder extends StatelessWidget {
  const _SidebarBodyPlaceholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    // Canon body density: VS Code tree rows sit near-flush under the header
    // with a modest left indent — not a generous all-around inset. The shell
    // makes the body flush (§spec:view-stack); the host content owns this
    // padding, so the example keeps it tight.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WorkbenchLayoutConstants.spacingLg,
        WorkbenchLayoutConstants.spacingXs,
        WorkbenchLayoutConstants.spacingLg,
        WorkbenchLayoutConstants.spacingMd,
      ),
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
/// Explorer view descriptors keyed by id. The host lists them in
/// [_WorkbenchHomeState._buildContainerSpec]; the shell owns their render order
/// and permutes it on header drag-reorder (§spec:view-stack).
Map<String, WorkbenchViewDescriptor> _explorerViews(
  NotificationService service,
) {
  void notify(String message) {
    service.show(severity: NotificationSeverity.info, message: message);
  }

  return {
    // Open Editors lists the open tabs. Canon hides it by default (the Folders
    // tree is the Explorer's primary pane); the user re-shows it from the `⋯`
    // Views overflow.
    'open-editors': WorkbenchViewDescriptor(
      id: 'open-editors',
      title: 'Open Editors',
      visible: false,
      actions: [
        _explorerHeaderAction(
          icon: Symbols.refresh_rounded,
          tooltip: 'Refresh',
          onPressed: () => notify('Refreshed Open Editors'),
        ),
      ],
      bodyBuilder: (_) => const _SidebarBodyPlaceholder(
        text: 'main.dart\nworkbench_content.dart',
      ),
    ),
    // The Folders view is the project tree (canon's `workbench.explorer.fileView`)
    // and the Explorer's primary pane. Its header shows the workspace folder name
    // while the Views menu labels it "Folders" (menuLabel), and it is
    // non-hideable (canHide: false) — matching VS Code. It owns New File / New
    // Folder / Refresh / Collapse Folders as view-title actions.
    'folders': WorkbenchViewDescriptor(
      id: 'folders',
      title: 'workbench_shell',
      menuLabel: 'Folders',
      canHide: false,
      actions: [
        _explorerHeaderAction(
          icon: Symbols.note_add_rounded,
          tooltip: 'New File',
          onPressed: () => notify('New file'),
        ),
        _explorerHeaderAction(
          icon: Symbols.create_new_folder_rounded,
          tooltip: 'New Folder',
          onPressed: () => notify('New folder'),
        ),
        _explorerHeaderAction(
          icon: Symbols.refresh_rounded,
          tooltip: 'Refresh Explorer',
          onPressed: () => notify('Refreshed Explorer'),
        ),
        _explorerHeaderAction(
          icon: Symbols.collapse_all,
          tooltip: 'Collapse Folders in Explorer',
          onPressed: () => notify('Collapsed Explorer folders'),
        ),
      ],
      bodyBuilder: (_) => const _SidebarBodyPlaceholder(
        text: 'lib/\nexample/\ntest/\nstyles/',
      ),
    ),
    'outline': WorkbenchViewDescriptor(
      id: 'outline',
      title: 'Outline',
      initiallyExpanded: false,
      bodyBuilder: (_) => const _SidebarBodyPlaceholder(
        text: 'WorkbenchViewPane\nWorkbenchCard',
      ),
    ),
    'timeline': WorkbenchViewDescriptor(
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
  };
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
    return Padding(
      padding: _sidebarBodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

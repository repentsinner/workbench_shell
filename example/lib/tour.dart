import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:workbench_shell/workbench_shell.dart';

import 'main.dart';

/// Pause on each view so a viewer can read it.
const Duration _dwell = Duration(milliseconds: 1500);

/// Shorter pause after a step whose result is a small change.
const Duration _beat = Duration(milliseconds: 900);

/// Pause on each color theme, long enough to take in the whole workbench.
const Duration _themeDwell = Duration(milliseconds: 2000);

/// Time a finger rests on the screen during a tap.
const Duration _tapHold = Duration(milliseconds: 80);

/// Pointer id for synthesized events, clear of ids real devices use.
const int _tourPointer = 9000;

/// The color themes the tour shows, in order. The cycle ends on the theme
/// it starts from, so a recording of one cycle loops cleanly.
const List<({String filename, Brightness brightness})> _tourThemes = [
  (filename: 'light_modern.json', brightness: Brightness.light),
  (filename: 'monokai.json', brightness: Brightness.dark),
  (filename: 'solarized_light.json', brightness: Brightness.light),
  (filename: '2026_dark.json', brightness: Brightness.dark),
  (filename: _startTheme, brightness: Brightness.dark),
];

/// The color theme each cycle starts on.
const String _startTheme = 'dark_modern.json';

/// Loops through the workbench's highlights: each view container, the editor
/// tabs, the bottom panel tabs, notifications, layout changes, and color
/// themes.
///
/// The tour taps on-screen controls with synthesized touch events, so each
/// one reaches the shell's real gesture handling. It changes the layout by
/// invoking the same intents the View menu dispatches. It picks color themes
/// on [themeController] while the Settings sidebar shows the theme dropdowns.
class Tour extends StatefulWidget {
  const Tour({super.key, required this.themeController, required this.child});

  /// Supplies the color themes the tour switches between.
  final WorkbenchThemeController themeController;

  final Widget child;

  @override
  State<Tour> createState() => _TourState();
}

class _TourState extends State<Tour> {
  Timer? _timer;

  /// Timestamp of the last synthesized event. Each event advances it, so the
  /// gesture system sees a down and its up as separate moments.
  Duration _eventTime = Duration.zero;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loop());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loop() async {
    while (!_disposed) {
      await _reset();
      debugPrint('tour cycle start ${DateTime.now().millisecondsSinceEpoch}');
      await _sleep(_dwell);

      // View containers: each activity-bar icon swaps the sidebar.
      await _tapIcon(Symbols.search_rounded);
      await _sleep(_dwell);
      await _tapIcon(Symbols.smart_button_rounded);
      await _sleep(_dwell);

      // Editor tabs: the shell keeps each tab's content across switches.
      await _tapText('release-notes.md');
      await _sleep(_dwell);
      await _tapText('lorem-ipsum.txt');
      await _sleep(_beat);

      // Bottom panel tabs.
      await _tapText('Output');
      await _sleep(_dwell);
      await _tapText('Terminal');
      await _sleep(_dwell);
      await _tapText('Problems');
      await _sleep(_beat);

      // Notifications: collapsing the Progress view pane gives the
      // Severities pane its room. A warning persists and counts in the
      // status bar's Problems item, an info card stacks above it, and the
      // stack's Clear All dismisses both.
      await _tapIcon(Symbols.notifications_rounded);
      await _sleep(_beat);
      await _tapText('Progress');
      await _sleep(_beat);
      await _tapText('Warning');
      await _sleep(_beat);
      await _tapText('Info');
      await _sleep(_dwell);
      await _tapText('Clear All');
      await _sleep(_beat);
      await _tapText('Progress');
      await _sleep(_beat);

      // Layout: the secondary side bar opens on the far edge and follows
      // when the primary swaps sides.
      await _invoke(const ToggleSecondarySideBarIntent());
      await _sleep(_dwell);
      await _invoke(const ToggleSidebarPositionIntent());
      await _sleep(_dwell);
      await _invoke(const ToggleSidebarPositionIntent());
      await _sleep(_beat);
      await _invoke(const ToggleSecondarySideBarIntent());
      await _sleep(_beat);

      // Surface treatment: base VS Code's flush parts, then Modern UI's
      // cards again.
      await _invoke(const ToggleModernUIIntent());
      await _sleep(_dwell);
      await _invoke(const ToggleModernUIIntent());
      await _sleep(_beat);

      // Color themes, with the Settings sidebar showing the active one.
      await _tapIcon(Symbols.settings_rounded);
      await _sleep(_beat);
      for (final theme in _tourThemes) {
        await _showTheme(theme.filename, theme.brightness);
        await _sleep(_themeDwell);
      }
    }
  }

  /// Returns the workbench to the state each cycle starts from: the start
  /// theme picked explicitly, and the Explorer sidebar open.
  Future<void> _reset() async {
    await _showTheme(_startTheme, Brightness.dark);
    await _tapIcon(Symbols.folder_rounded);
  }

  /// Picks [filename] the way the Color theme dropdown does, with auto-detect
  /// off so the pick holds whatever the OS appearance is.
  Future<void> _showTheme(String filename, Brightness brightness) async {
    if (_disposed) return;
    final themes = widget.themeController;
    await themes.selectTheme(filename);
    if (_disposed) return;
    // `selectTheme` stored the pick in its brightness slot, so fixing the
    // mode to that brightness resolves to the pick.
    themes.themeMode = brightness == Brightness.light
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  /// Invokes [intent] from the [WorkbenchLayout], which sits below the
  /// host's `Actions` the way the View menu does.
  Future<void> _invoke(Intent intent) async {
    if (_disposed) return;
    final layout = _findElement((widget) => widget is WorkbenchLayout);
    if (layout != null) Actions.maybeInvoke(layout, intent);
  }

  /// Returns the first element under the tour whose widget satisfies
  /// [matches].
  Element? _findElement(bool Function(Widget widget) matches) {
    Element? found;
    void visit(Element element) {
      if (found != null) return;
      if (matches(element.widget)) {
        found = element;
        return;
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  Future<void> _tapIcon(IconData icon) =>
      _tapWhere((widget) => widget is Icon && widget.icon == icon);

  Future<void> _tapText(String text) =>
      _tapWhere((widget) => widget is Text && widget.data == text);

  /// Taps the center of the first on-screen widget that satisfies [matches].
  /// A widget counts as on screen when a hit test at its center reaches it,
  /// which skips copies hidden offstage or under another surface.
  Future<void> _tapWhere(bool Function(Widget widget) matches) async {
    if (_disposed) return;
    final position = _findOnScreen(matches);
    if (position == null) return;

    final gestures = GestureBinding.instance;
    gestures.handlePointerEvent(
      PointerDownEvent(
        pointer: _tourPointer,
        timeStamp: _eventTime += _tapHold,
        position: position,
      ),
    );
    await _sleep(_tapHold);
    if (_disposed) return;
    gestures.handlePointerEvent(
      PointerUpEvent(
        pointer: _tourPointer,
        timeStamp: _eventTime += _tapHold,
        position: position,
      ),
    );
  }

  Offset? _findOnScreen(bool Function(Widget widget) matches) {
    final view = View.of(context);
    Offset? found;
    void visit(Element element) {
      if (found != null) return;
      if (matches(element.widget)) {
        final box = element.renderObject;
        if (box is RenderBox && box.attached && box.hasSize) {
          final center = box.localToGlobal(box.size.center(Offset.zero));
          final result = HitTestResult();
          WidgetsBinding.instance.hitTestInView(result, center, view.viewId);
          if (result.path.any((entry) => entry.target == box)) {
            found = center;
            return;
          }
        }
      }
      element.visitChildElements(visit);
    }

    context.visitChildElements(visit);
    return found;
  }

  /// Waits [duration] on a timer that dispose cancels, which abandons the
  /// loop instead of leaving it running against a dead widget.
  Future<void> _sleep(Duration duration) {
    final done = Completer<void>();
    _timer = Timer(duration, done.complete);
    return done.future;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

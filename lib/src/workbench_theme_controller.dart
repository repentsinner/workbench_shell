import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';

import 'theming/vscode_color_map.dart';
import 'workbench_theme.dart';

/// An entry in a [WorkbenchThemeController]'s theme list.
///
/// Carries a user-facing [label], the bundled asset [filename] that
/// backs the theme, and the [brightness] of that theme. `filename`
/// is the stable identifier used for persistence and selection;
/// `brightness` is the pairing key the controller uses in
/// [ThemeMode.system] mode (§7.5).
@immutable
class WorkbenchThemeEntry {
  final String label;
  final String filename;
  final Brightness brightness;

  const WorkbenchThemeEntry({
    required this.label,
    required this.filename,
    required this.brightness,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbenchThemeEntry &&
          label == other.label &&
          filename == other.filename &&
          brightness == other.brightness;

  @override
  int get hashCode => Object.hash(label, filename, brightness);
}

/// Owns active workbench theme state and exposes a theme-list / pick API.
///
/// The controller loads VS Code color theme JSON from the bundled
/// assets shipped with `workbench_shell`, builds a [WorkbenchTheme]
/// via [WorkbenchTheme.fromVscodeColorMap], and publishes it through
/// [ChangeNotifier]. Host apps mount the controller near the widget
/// tree root and read [theme] to install the extension on
/// [ThemeData].
///
/// The host app is responsible for persistence — the controller
/// accepts initial values for [themeMode], [preferredLight], and
/// [preferredDark], emits changes through `notifyListeners`, but does
/// not talk to any preferences store.
///
/// In [ThemeMode.system] the controller subscribes to
/// [PlatformDispatcher.onPlatformBrightnessChanged] and keeps the
/// active theme paired with the OS appearance via [preferredLight] /
/// [preferredDark]. In [ThemeMode.light] / [ThemeMode.dark] the
/// platform signal is ignored and the active theme is the preferred
/// slot of the named brightness. See SPEC §7.5.
class WorkbenchThemeController extends ChangeNotifier {
  /// Default bundled themes shipped with `workbench_shell`.
  static const List<WorkbenchThemeEntry> defaultAvailableThemes = [
    WorkbenchThemeEntry(
      label: 'Dark 2026',
      filename: '2026_dark.json',
      brightness: Brightness.dark,
    ),
    WorkbenchThemeEntry(
      label: 'Light 2026',
      filename: '2026_light.json',
      brightness: Brightness.light,
    ),
    WorkbenchThemeEntry(
      label: 'Dark Modern',
      filename: 'dark_modern.json',
      brightness: Brightness.dark,
    ),
    WorkbenchThemeEntry(
      label: 'Light Modern',
      filename: 'light_modern.json',
      brightness: Brightness.light,
    ),
    WorkbenchThemeEntry(
      label: 'Dark+ (Visual Studio)',
      filename: 'dark_plus.json',
      brightness: Brightness.dark,
    ),
    WorkbenchThemeEntry(
      label: 'Light+ (Visual Studio)',
      filename: 'light_plus.json',
      brightness: Brightness.light,
    ),
    WorkbenchThemeEntry(
      label: 'Monokai',
      filename: 'monokai.json',
      brightness: Brightness.dark,
    ),
    WorkbenchThemeEntry(
      label: 'Solarized Dark',
      filename: 'solarized_dark.json',
      brightness: Brightness.dark,
    ),
    WorkbenchThemeEntry(
      label: 'Solarized Light',
      filename: 'solarized_light.json',
      brightness: Brightness.light,
    ),
  ];

  /// Shared brightness subscriptions, keyed by dispatcher, so multiple
  /// controllers can observe one [PlatformDispatcher] and unsubscribe in
  /// any order. See [_BrightnessHub].
  static final Map<PlatformDispatcher, _BrightnessHub> _brightnessHubs = {};

  final VscodeColorThemeLoader _loader;
  final List<WorkbenchThemeEntry> _availableThemes;
  final Map<String, WorkbenchTheme> _cache = {};
  final String? _chromeFontFamily;
  final String? _editorFontFamily;
  final double? _editorFontSize;
  final PlatformDispatcher _platformDispatcher;

  WorkbenchTheme _theme;
  String _selectedFilename;
  ThemeMode _themeMode;
  String _preferredLight;
  String _preferredDark;
  Future<void> _pendingResolution = Future.value();
  bool _disposed = false;

  WorkbenchThemeController._({
    required WorkbenchTheme initialTheme,
    required String initialFilename,
    required List<WorkbenchThemeEntry> availableThemes,
    required VscodeColorThemeLoader loader,
    required String? chromeFontFamily,
    required String? editorFontFamily,
    required double? editorFontSize,
    required ThemeMode themeMode,
    required String preferredLight,
    required String preferredDark,
    required PlatformDispatcher platformDispatcher,
  }) : _theme = initialTheme,
       _selectedFilename = initialFilename,
       _availableThemes = List.unmodifiable(availableThemes),
       _loader = loader,
       _chromeFontFamily = chromeFontFamily,
       _editorFontFamily = editorFontFamily,
       _editorFontSize = editorFontSize,
       _themeMode = themeMode,
       _preferredLight = preferredLight,
       _preferredDark = preferredDark,
       _platformDispatcher = platformDispatcher {
    _installPlatformBrightnessListener();
    _pendingResolution = _resolveActiveTheme();
  }
  // Intentionally not caching [initialTheme] under [initialFilename].
  // The initial theme is a synchronous placeholder (usually built from
  // an empty VscodeColorMap) for the first frame — not the real bundled
  // theme. Caching it here poisons [selectTheme] forever:
  // `selectTheme(initialFilename)` would hit the already-selected
  // short-circuit (or the cache-hit branch after a detour through
  // another theme) and never actually load the real asset.

  /// Create a controller seeded with a synchronous fallback theme.
  ///
  /// The host app typically passes a theme derived from an empty
  /// [VscodeColorMap] so the first frame has usable chrome. After
  /// mount, the controller resolves the real bundle for the active
  /// brightness slot asynchronously; await [pendingResolution] in
  /// tests if you need the resolved theme before asserting.
  ///
  /// [themeMode] selects how the active theme is chosen:
  /// - [ThemeMode.system]: paired with [PlatformDispatcher.platformBrightness]
  ///   via [preferredLight] / [preferredDark].
  /// - [ThemeMode.light] / [ThemeMode.dark]: pinned to the named slot
  ///   regardless of OS brightness.
  factory WorkbenchThemeController({
    required WorkbenchTheme initialTheme,
    String initialFilename = 'dark_modern.json',
    List<WorkbenchThemeEntry> availableThemes = defaultAvailableThemes,
    VscodeColorThemeLoader loader = const VscodeColorThemeLoader(),
    String? chromeFontFamily,
    String? editorFontFamily,
    double? editorFontSize,
    ThemeMode themeMode = ThemeMode.system,
    String preferredLight = 'light_modern.json',
    String preferredDark = 'dark_modern.json',
    PlatformDispatcher? platformDispatcher,
  }) {
    return WorkbenchThemeController._(
      initialTheme: initialTheme,
      initialFilename: initialFilename,
      availableThemes: availableThemes,
      loader: loader,
      chromeFontFamily: chromeFontFamily,
      editorFontFamily: editorFontFamily,
      editorFontSize: editorFontSize,
      themeMode: themeMode,
      preferredLight: preferredLight,
      preferredDark: preferredDark,
      platformDispatcher:
          platformDispatcher ?? WidgetsBinding.instance.platformDispatcher,
    );
  }

  /// Active [WorkbenchTheme]. Install on `ThemeData.extensions`.
  WorkbenchTheme get theme => _theme;

  /// Filename of the active theme (e.g. `dark_modern.json`).
  String get selectedFilename => _selectedFilename;

  /// Themes the user can pick from.
  List<WorkbenchThemeEntry> get availableThemes => _availableThemes;

  /// Current theme mode. [ThemeMode.system] tracks the OS brightness;
  /// [ThemeMode.light] / [ThemeMode.dark] pin the active theme to the
  /// matching preferred slot.
  ThemeMode get themeMode => _themeMode;

  /// Filename of the preferred light theme. Active in [ThemeMode.light]
  /// and in [ThemeMode.system] when the OS is in light mode.
  String get preferredLight => _preferredLight;

  /// Filename of the preferred dark theme. Active in [ThemeMode.dark]
  /// and in [ThemeMode.system] when the OS is in dark mode.
  String get preferredDark => _preferredDark;

  /// Effective brightness of the active theme.
  ///
  /// Reads the entry's declared [WorkbenchThemeEntry.brightness] when
  /// the active filename matches a known entry. Hosts wire this to
  /// platform-native window-chrome APIs (§7.5).
  Brightness get brightness => _brightnessFor(_selectedFilename);

  /// A future that completes when any in-flight theme resolution
  /// finishes. Tests await this after triggering a mode/preferred
  /// change to observe the resolved state.
  Future<void> get pendingResolution => _pendingResolution;

  /// Resolve the active theme from the current [themeMode] /
  /// [preferredLight] / [preferredDark] / OS brightness combination.
  ///
  /// Loads the underlying asset if necessary. Hosts and tests rarely
  /// call this directly — the controller calls it on construction and
  /// when state mutates — but exposing it lets tests await the first
  /// resolution synchronously after construction.
  Future<void> resolveActiveTheme() {
    _pendingResolution = _resolveActiveTheme();
    return _pendingResolution;
  }

  set themeMode(ThemeMode value) {
    if (_disposed || _themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    _pendingResolution = _resolveActiveTheme();
  }

  set preferredLight(String filename) {
    if (_disposed || _preferredLight == filename) return;
    _preferredLight = filename;
    notifyListeners();
    if (_activeBrightness() == Brightness.light) {
      _pendingResolution = _resolveActiveTheme();
    }
  }

  set preferredDark(String filename) {
    if (_disposed || _preferredDark == filename) return;
    _preferredDark = filename;
    notifyListeners();
    if (_activeBrightness() == Brightness.dark) {
      _pendingResolution = _resolveActiveTheme();
    }
  }

  /// Load and activate [filename].
  ///
  /// Updates the matching [preferredLight] / [preferredDark] slot
  /// based on the picked theme's brightness. Picking a theme of the
  /// brightness opposite the current OS in [ThemeMode.system] flips
  /// `themeMode` to [ThemeMode.light] / [ThemeMode.dark] to match
  /// (§7.5 observable behaviour).
  ///
  /// No-op if the theme is already active. Results are cached so
  /// re-selecting a theme is synchronous on subsequent calls. If the
  /// asset fails to load, the current theme is retained.
  Future<void> selectTheme(String filename) async {
    if (_disposed) return;

    final pickedBrightness = _brightnessFor(filename);

    // Update preferred slot for the picked brightness so the next
    // OS-appearance flip lands on the user's choice.
    if (pickedBrightness == Brightness.light) {
      _preferredLight = filename;
    } else {
      _preferredDark = filename;
    }

    // In system mode, picking a theme of the opposite brightness
    // flips the mode to match — the user has expressed intent for a
    // specific brightness right now, overriding the OS signal.
    if (_themeMode == ThemeMode.system) {
      final osBrightness = _platformDispatcher.platformBrightness;
      if (pickedBrightness != osBrightness) {
        _themeMode = pickedBrightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark;
      }
    }

    await _loadAndActivate(filename);
  }

  Future<void> _resolveActiveTheme() async {
    if (_disposed) return;
    final target = _resolveTargetFilename();
    await _loadAndActivate(target);
  }

  String _resolveTargetFilename() {
    switch (_themeMode) {
      case ThemeMode.light:
        return _preferredLight;
      case ThemeMode.dark:
        return _preferredDark;
      case ThemeMode.system:
        return _platformDispatcher.platformBrightness == Brightness.dark
            ? _preferredDark
            : _preferredLight;
    }
  }

  Brightness _activeBrightness() {
    switch (_themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return _platformDispatcher.platformBrightness;
    }
  }

  Brightness _brightnessFor(String filename) {
    for (final entry in _availableThemes) {
      if (entry.filename == filename) return entry.brightness;
    }
    // Unknown filename — treat as dark by default. Hosts that pass
    // bespoke filenames should declare an entry with the right
    // brightness; the conservative fallback is dark since most
    // bundled / community themes lean dark.
    return Brightness.dark;
  }

  Future<void> _loadAndActivate(String filename) async {
    if (_disposed) return;

    final cached = _cache[filename];
    if (cached != null) {
      if (_selectedFilename == filename && identical(_theme, cached)) {
        return;
      }
      _selectedFilename = filename;
      _theme = cached;
      notifyListeners();
      return;
    }

    final map = await _loader.loadAsset(filename);
    if (_disposed) return;
    final resolved = WorkbenchTheme.fromVscodeColorMap(
      map,
      chromeFontFamily: _chromeFontFamily,
      editorFontFamily: _editorFontFamily,
      editorFontSize: _editorFontSize,
    );
    _cache[filename] = resolved;
    _selectedFilename = filename;
    _theme = resolved;
    notifyListeners();
  }

  void _installPlatformBrightnessListener() {
    final hub = _brightnessHubs.putIfAbsent(
      _platformDispatcher,
      () => _BrightnessHub(_platformDispatcher),
    );
    hub.add(_handlePlatformBrightnessChanged);
  }

  void _removePlatformBrightnessListener() {
    final hub = _brightnessHubs[_platformDispatcher];
    if (hub == null) return;
    hub.remove(_handlePlatformBrightnessChanged);
    if (hub.isEmpty) {
      hub.restore();
      _brightnessHubs.remove(_platformDispatcher);
    }
  }

  void _handlePlatformBrightnessChanged() {
    if (_disposed) return;
    if (_themeMode != ThemeMode.system) return;
    _pendingResolution = _resolveActiveTheme();
  }

  @override
  void dispose() {
    _disposed = true;
    _removePlatformBrightnessListener();
    super.dispose();
  }
}

/// Fans one [PlatformDispatcher.onPlatformBrightnessChanged] slot out to
/// any number of [WorkbenchThemeController]s sharing that dispatcher.
///
/// The dispatcher stores a single handler. Chaining controllers through
/// it directly cannot be unwound for out-of-order disposal: a controller
/// restoring its captured "previous" handler resurrects an already-
/// disposed controller's callback. The hub keeps an order-independent
/// subscriber list and restores the original handler only once the last
/// subscriber leaves.
class _BrightnessHub {
  _BrightnessHub(this._dispatcher)
    : _previous = _dispatcher.onPlatformBrightnessChanged {
    _dispatcher.onPlatformBrightnessChanged = _dispatch;
  }

  final PlatformDispatcher _dispatcher;
  final VoidCallback? _previous;
  final List<VoidCallback> _handlers = [];

  bool get isEmpty => _handlers.isEmpty;

  void add(VoidCallback handler) => _handlers.add(handler);

  void remove(VoidCallback handler) => _handlers.remove(handler);

  void restore() => _dispatcher.onPlatformBrightnessChanged = _previous;

  void _dispatch() {
    _previous?.call();
    // Copy first: a handler may dispose its controller mid-dispatch,
    // mutating _handlers.
    for (final handler in List.of(_handlers)) {
      handler();
    }
  }
}

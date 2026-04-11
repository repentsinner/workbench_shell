import 'package:flutter/foundation.dart';

import 'theming/vscode_color_map.dart';
import 'workbench_theme.dart';

/// An entry in a [WorkbenchThemeController]'s theme list.
///
/// Carries a user-facing [label] and the bundled asset [filename]
/// that backs the theme. `filename` is the stable identifier used
/// for persistence and selection.
@immutable
class WorkbenchThemeEntry {
  final String label;
  final String filename;

  const WorkbenchThemeEntry({required this.label, required this.filename});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkbenchThemeEntry &&
          label == other.label &&
          filename == other.filename;

  @override
  int get hashCode => Object.hash(label, filename);
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
/// accepts a `selectedFilename` and emits changes, but does not
/// talk to any preferences store.
class WorkbenchThemeController extends ChangeNotifier {
  /// Default bundled themes shipped with `workbench_shell`.
  static const List<WorkbenchThemeEntry> defaultAvailableThemes = [
    WorkbenchThemeEntry(label: 'Dark Modern', filename: 'dark_modern.json'),
    WorkbenchThemeEntry(label: 'Light Modern', filename: 'light_modern.json'),
    WorkbenchThemeEntry(label: 'Nord', filename: 'nord.json'),
    WorkbenchThemeEntry(label: 'One Dark Pro', filename: 'one_dark_pro.json'),
  ];

  final VscodeColorThemeLoader _loader;
  final List<WorkbenchThemeEntry> _availableThemes;
  final Map<String, WorkbenchTheme> _cache = {};
  final String _fontFamily;

  WorkbenchTheme _theme;
  String _selectedFilename;
  bool _disposed = false;

  WorkbenchThemeController._({
    required WorkbenchTheme initialTheme,
    required String initialFilename,
    required List<WorkbenchThemeEntry> availableThemes,
    required VscodeColorThemeLoader loader,
    required String fontFamily,
  }) : _theme = initialTheme,
       _selectedFilename = initialFilename,
       _availableThemes = List.unmodifiable(availableThemes),
       _loader = loader,
       _fontFamily = fontFamily;
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
  /// mount, call [selectTheme] with the persisted filename to load
  /// the real bundle asynchronously.
  factory WorkbenchThemeController({
    required WorkbenchTheme initialTheme,
    String initialFilename = 'dark_modern.json',
    List<WorkbenchThemeEntry> availableThemes = defaultAvailableThemes,
    VscodeColorThemeLoader loader = const VscodeColorThemeLoader(),
    String fontFamily = 'Inconsolata',
  }) {
    return WorkbenchThemeController._(
      initialTheme: initialTheme,
      initialFilename: initialFilename,
      availableThemes: availableThemes,
      loader: loader,
      fontFamily: fontFamily,
    );
  }

  /// Active [WorkbenchTheme]. Install on `ThemeData.extensions`.
  WorkbenchTheme get theme => _theme;

  /// Filename of the active theme (e.g. `dark_modern.json`).
  String get selectedFilename => _selectedFilename;

  /// Themes the user can pick from.
  List<WorkbenchThemeEntry> get availableThemes => _availableThemes;

  /// Load and activate [filename].
  ///
  /// No-op if the theme is already active. Results are cached so
  /// re-selecting a theme is synchronous on subsequent calls. If
  /// the asset fails to load, the current theme is retained.
  Future<void> selectTheme(String filename) async {
    if (_disposed) return;
    if (_selectedFilename == filename && _cache.containsKey(filename)) {
      return;
    }

    final cached = _cache[filename];
    if (cached != null) {
      _selectedFilename = filename;
      _theme = cached;
      notifyListeners();
      return;
    }

    try {
      final map = await _loader.loadAsset(filename);
      if (_disposed) return;
      final resolved = WorkbenchTheme.fromVscodeColorMap(
        map,
        fontFamily: _fontFamily,
      );
      _cache[filename] = resolved;
      _selectedFilename = filename;
      _theme = resolved;
      notifyListeners();
    } on Object {
      // Retain current theme on load failure. Host apps should log
      // via their own logging surface if they want to surface this.
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

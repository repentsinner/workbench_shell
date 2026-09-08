import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'layout_constants.dart';
import 'workbench_theme.dart';

/// Publishes whether the workbench renders VS Code's Modern UI surface
/// treatment (§spec:modern-ui-surfaces) to every part below the shell.
///
/// The treatment reaches surfaces the layout does not build: a host supplies
/// its own status bar, and a host's view panes are inflated from
/// `containerBuilder` callbacks. Each is inflated *inside* the shell's element
/// tree, so an inherited widget reaches them the same way
/// `Theme.of(context).extension<WorkbenchTheme>()` already does, without the
/// layout threading a boolean through every intermediate widget.
///
/// A part built outside a `WorkbenchLayout` — a standalone
/// [WorkbenchViewPane], say — reads the treatment on, which is what upstream's
/// experimentation service serves (§spec:modern-ui-surfaces).
///
/// Internal: the host-facing control is `WorkbenchLayout.modernUI`, which
/// mirrors upstream's `workbench.experimental.modernUI` setting. This widget
/// is the transport, not API.
@internal
class WorkbenchSurfaceTreatment extends InheritedWidget {
  /// Whether the parts below render as Modern UI cards.
  final bool modernUI;

  const WorkbenchSurfaceTreatment({
    super.key,
    required this.modernUI,
    required super.child,
  });

  /// Whether the treatment is in force at [context].
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkbenchSurfaceTreatment>()
          ?.modernUI ??
      true;

  /// The view-pane header band in force at [context]. The treatment raises the
  /// base `splitview` `HEADER_SIZE` to the spacing ramp's 28px step, and both
  /// the pane that renders the band and the stack that apportions height
  /// around it read it from here, so the two cannot disagree.
  static double viewPaneHeaderHeight(BuildContext context) => of(context)
      ? WorkbenchLayoutConstants.viewPaneHeaderHeight
      : WorkbenchLayoutConstants.baseViewPaneHeaderHeight;

  /// The casing a chrome title renders in at [context]. The treatment's
  /// `fontRamp.css` swaps `text-transform: uppercase` for `capitalize`, and
  /// upstream's own strings are already cased — so `capitalize` is a no-op and
  /// the shell renders [title] verbatim. Base VS Code's `paneview.css` and
  /// `part.css` uppercase, and so does this (§spec:chrome-typography-canon).
  ///
  /// Casing and the type tier travel together and both depend on the
  /// treatment, so they resolve at the widget from one read of this inherited
  /// widget. [WorkbenchTheme] is a `ThemeExtension` resolved without a
  /// `BuildContext`, so it registers both tiers as tokens and cannot make the
  /// choice itself.
  static String titleCasing(BuildContext context, String title) =>
      of(context) ? title : title.toUpperCase();

  /// The view-pane header type tier in force at [context]
  /// (§spec:chrome-typography-canon).
  static TextStyle paneHeaderStyle(BuildContext context, WorkbenchTheme theme) =>
      of(context) ? theme.sectionTitle : theme.baseSectionTitle;

  /// The part-title type tier in force at [context] — the side bar heading and
  /// the panel tab label (§spec:chrome-typography-canon).
  static TextStyle partTitleStyle(BuildContext context, WorkbenchTheme theme) =>
      of(context)
      ? theme.sidebarOrPanelHeading
      : theme.baseSidebarOrPanelHeading;

  @override
  bool updateShouldNotify(WorkbenchSurfaceTreatment oldWidget) =>
      oldWidget.modernUI != modernUI;
}

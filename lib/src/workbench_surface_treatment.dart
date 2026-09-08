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

  /// The band the side bar heading occupies against an already-resolved
  /// treatment. `padding.css` tightens `.part > .title` from base `part.css`'s
  /// 35px to 32px (§spec:modern-ui-surfaces).
  static double partTitleHeightFor(bool modernUI) => modernUI
      ? WorkbenchLayoutConstants.modernPartTitleHeight
      : WorkbenchLayoutConstants.sidebarHeadingHeight;

  /// The band the panel's tab strip occupies. The same `.part > .title` rule
  /// governs both surfaces, but each names its own base constant
  /// (§spec:layout-constants-canon).
  static double panelTabStripHeightFor(bool modernUI) => modernUI
      ? WorkbenchLayoutConstants.modernPartTitleHeight
      : WorkbenchLayoutConstants.panelTabStripHeight;

  /// The margin holding the vertical activity bar's item column off the top of
  /// its card, and its trailing zone off the bottom (§spec:modern-ui-surfaces).
  /// The treatment owns both: base VS Code runs the items flush from edge to
  /// edge, so the base bar takes neither.
  static const EdgeInsets activityBarItemColumnMargin = EdgeInsets.only(
    top: WorkbenchLayoutConstants.activityBarZoneMargin,
  );
  static const EdgeInsets activityBarBottomZoneMargin = EdgeInsets.only(
    bottom: WorkbenchLayoutConstants.activityBarZoneMargin,
  );

  /// The inset `.part > .title` pads its row by at [context]. `padding.css`
  /// takes it from base `part.css`'s 8px to one spacing step
  /// (§spec:modern-ui-surfaces).
  static EdgeInsets partTitleInset(BuildContext context) =>
      partTitleInsetFor(of(context));

  /// [partTitleInset] against an already-resolved treatment, for a widget the
  /// layout hands the answer to rather than one that reads it from the tree.
  static EdgeInsets partTitleInsetFor(bool modernUI) =>
      modernUI ? _modernPartTitleInset : _basePartTitleInset;

  static const _modernPartTitleInset = EdgeInsets.symmetric(
    horizontal: WorkbenchLayoutConstants.spacingSize40,
  );
  static const _basePartTitleInset = EdgeInsets.symmetric(
    horizontal: WorkbenchLayoutConstants.spacingSize80,
  );

  /// The further inset `.title-label` pads the label by inside that row, so the
  /// title reads deeper in than the trailing action does. `padding.css` takes
  /// it from 12px to two spacing steps (§spec:modern-ui-surfaces).
  static EdgeInsets partTitleLabelInsetFor(bool modernUI) =>
      modernUI ? _modernLabelInset : _baseLabelInset;

  static const _modernLabelInset = EdgeInsets.only(
    left: WorkbenchLayoutConstants.spacingSize80,
  );
  static const _baseLabelInset = EdgeInsets.only(
    left: WorkbenchLayoutConstants.spacingSize120,
  );

  /// The panel's composite title inset. `padding.css` gives it its own
  /// asymmetric pair — `.part.basepanel .composite.title` — rather than the
  /// generic part inset the side bar heading takes; base VS Code falls through
  /// to `part.css`'s 8px on both edges (§spec:modern-ui-surfaces).
  static EdgeInsets panelTitleInsetFor(bool modernUI) =>
      modernUI ? _modernPanelTitleInset : _basePartTitleInset;

  static const _modernPanelTitleInset = EdgeInsets.only(
    left: WorkbenchLayoutConstants.spacingSize20,
    right: WorkbenchLayoutConstants.spacingSize40,
  );

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
      titleCasingFor(of(context), title);

  /// [titleCasing] against an already-resolved treatment.
  static String titleCasingFor(bool modernUI, String title) =>
      modernUI ? title : title.toUpperCase();

  /// The view-pane header type tier in force at [context]
  /// (§spec:chrome-typography-canon).
  static TextStyle paneHeaderStyle(BuildContext context, WorkbenchTheme theme) =>
      paneHeaderStyleFor(of(context), theme);

  /// [paneHeaderStyle] against an already-resolved treatment.
  static TextStyle paneHeaderStyleFor(bool modernUI, WorkbenchTheme theme) =>
      modernUI ? theme.sectionTitle : theme.baseSectionTitle;

  /// The part-title type tier in force at [context] — the side bar heading and
  /// the panel tab label (§spec:chrome-typography-canon).
  static TextStyle partTitleStyle(BuildContext context, WorkbenchTheme theme) =>
      partTitleStyleFor(of(context), theme);

  /// [partTitleStyle] against an already-resolved treatment.
  static TextStyle partTitleStyleFor(bool modernUI, WorkbenchTheme theme) =>
      modernUI
      ? theme.sidebarOrPanelHeading
      : theme.baseSidebarOrPanelHeading;

  @override
  bool updateShouldNotify(WorkbenchSurfaceTreatment oldWidget) =>
      oldWidget.modernUI != modernUI;
}

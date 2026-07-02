import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:meta/meta.dart';

import 'layout_constants.dart';
import 'workbench_theme.dart';

/// Structural primitives for sidebars and bottom panels.
///
/// `workbench_shell` deliberately scopes this surface to structural
/// grouping (sections, cards, toggle cards, empty states).
/// Form controls — text fields, dropdowns, toggles, action buttons —
/// live in the host application as application helpers. See SPEC
/// §spec:form-controls-excluded for rationale and the re-promotion gate.

/// Resolve a content-primitive border side from the theme's nullable
/// [WorkbenchTheme.borderColor]. When the theme suppresses the border,
/// fall through to [BorderSide.none] so the content primitive draws
/// without a visible edge. Callers that need to skip the wrapping
/// decoration entirely should branch on `theme.borderColor == null`.
BorderSide _contentBorderSide(WorkbenchTheme theme) => theme.borderColor == null
    ? BorderSide.none
    : BorderSide(color: theme.borderColor!);

/// Top-level grouping inside a sidebar or panel. Renders [title]
/// uppercased — the shell owns the transform so consumers cannot
/// diverge (§spec:capability-boundary canon enforcement, §spec:chrome-typography-canon pane-header semantics) — in
/// [WorkbenchTheme.sectionTitle] with an optional info tooltip icon.
///
/// Disclosure (§spec:section-disclosure) is container-derived, not a host
/// choice: the default public constructor renders a non-collapsible pane whose
/// body is always shown. Whether a pane can collapse is decided by its
/// [WorkbenchViewContainer] from view count (§spec:view-stack) and set through
/// the library-internal [WorkbenchViewPane.inContainer] seam — a host cannot
/// mark an individual pane collapsible (§spec:capability-boundary). When
/// collapsible, the shell owns the chevron, the gesture, and the state.
///
/// Expansion state has two control modes mirroring §spec:workbench-layout:
///
/// - *Uncontrolled*: omit [expanded]; the pane holds its own state, seeded
///   by [initiallyExpanded] (the `ExpansionTile` pattern).
/// - *Controlled*: pass [expanded] and [onExpandedChanged]; the host drives
///   the value and the pane reflects it, reporting each requested toggle.
///
/// Header actions (§spec:section-header-actions): pass [actions] to place
/// host-supplied widgets in the header's rightmost zone (order twisty →
/// title → [infoTooltip] → actions). The shell only *places and reveals*
/// them — they are not a typed action control (§spec:form-controls-excluded
/// keeps that in the host). Actions are hidden until the header is hovered or
/// focused and only while the pane is expanded; collapsing the pane hides them
/// entirely. Set [actionsAlwaysVisible] to pin them on regardless of
/// hover/focus, still only while expanded (VS Code's
/// `ViewPaneShowActions.Always`). Activating an action runs the action and
/// does not toggle the pane (§spec:section-disclosure). The shell places
/// actions raw and the header row grows to the tallest action — it owns
/// placement and visibility, not control sizing.
class WorkbenchViewPane extends StatefulWidget {
  final String title;
  final Widget child;
  final String? infoTooltip;

  /// Host-supplied header widgets, rendered right-aligned and revealed on
  /// hover/focus while expanded. Empty by default — the header then renders
  /// exactly as title + optional [infoTooltip].
  final List<Widget> actions;

  /// Pin [actions] on regardless of hover or focus, while expanded.
  final bool actionsAlwaysVisible;

  /// Whether the header shows a leading twistie and toggles the body.
  /// Container-derived (§spec:view-stack), not a host param: the public
  /// constructor fixes it false; [WorkbenchViewPane.inContainer] sets it.
  final bool collapsible;

  /// Whether the header paints its 1px top rule. The rule separates
  /// *adjacent* panes, so the first pane in a container omits it — VS Code
  /// draws no divider above the first pane (§spec:view-stack). Container-set:
  /// [WorkbenchViewContainer] passes false for the first view. The background
  /// band is unaffected.
  final bool showTopRule;

  /// Whether the body is bounded to an apportioned height and scrolls
  /// internally (§spec:view-stack). The splitview container forces each
  /// expanded pane to a fixed height (header + apportioned body) and sets this
  /// so the body fills the remaining space and scrolls when its content
  /// overflows — the per-pane scroll boundary, not the whole stack. The public
  /// standalone constructor leaves it false: a standalone pane grows to its
  /// content with no internal scroll.
  final bool boundedBody;

  /// Wraps the header surface, letting the container make the header a drag
  /// handle for pane reorder (§spec:view-stack). Library-internal: only
  /// [WorkbenchViewContainer] supplies it, via [WorkbenchViewPane.inContainer].
  /// The public standalone pane leaves it null and the header renders raw.
  final Widget Function(Widget header)? headerWrapper;

  /// The header's single focus stop (§spec:view-pane-focus). Library-internal:
  /// [WorkbenchViewContainer] owns one node per pane and injects it here so the
  /// container can move focus between header stops for Up/Down traversal
  /// (§spec:view-stack) — header focus stays off the pane bodies. Null (the
  /// standalone case) leaves the pane to own and dispose its own node, so the
  /// public pane is unchanged.
  final FocusNode? headerFocusNode;

  /// Initial expansion for uncontrolled (no [expanded]) collapsible panes.
  final bool initiallyExpanded;

  /// Controlled expansion. When non-null the host drives the state and the
  /// pane reflects this value rather than holding its own.
  final bool? expanded;

  /// Fired when header activation requests a new expanded state. In
  /// uncontrolled mode the pane has already applied the change; in
  /// controlled mode the host must push the new [expanded] value to apply it.
  final ValueChanged<bool>? onExpandedChanged;

  /// Standalone primitive: renders a non-collapsible pane (body always
  /// shown). Collapsibility is container-derived (§spec:view-stack), so the
  /// public API exposes no `collapsible` flag.
  const WorkbenchViewPane({
    super.key,
    required this.title,
    required this.child,
    this.infoTooltip,
    this.actions = const [],
    this.actionsAlwaysVisible = false,
    this.initiallyExpanded = true,
    this.expanded,
    this.onExpandedChanged,
  }) : collapsible = false,
       showTopRule = true,
       boundedBody = false,
       headerWrapper = null,
       headerFocusNode = null;

  /// Library-internal seam (§spec:view-stack). [WorkbenchViewContainer] uses
  /// this to pass the collapsibility it derives from view count. `@internal`
  /// keeps it off the public API — hosts use the default constructor and let
  /// the container decide. Exposes the full expansion contract (controlled and
  /// uncontrolled) so it faithfully mirrors the pane the container drives.
  @internal
  const WorkbenchViewPane.inContainer({
    super.key,
    required this.title,
    required this.child,
    required this.collapsible,
    this.showTopRule = true,
    this.boundedBody = false,
    this.headerWrapper,
    this.headerFocusNode,
    this.infoTooltip,
    this.actions = const [],
    this.actionsAlwaysVisible = false,
    this.initiallyExpanded = true,
    this.expanded,
    this.onExpandedChanged,
  });

  @override
  State<WorkbenchViewPane> createState() => _WorkbenchViewPaneState();
}

/// Keys the focus-ring [DecoratedBox] that wraps every view-pane header
/// (§spec:view-pane-focus). The ring reserves a constant 1px border — painted
/// [WorkbenchTheme.focusBorder] while focused, transparent at rest — so
/// gaining or losing focus never reflows the header.
@visibleForTesting
const Key viewPaneHeaderFocusRingKey = ValueKey('view-pane-header-focus-ring');

class _WorkbenchViewPaneState extends State<WorkbenchViewPane> {
  late bool _expanded = widget.initiallyExpanded;

  // The single focus stop for the header (§spec:view-pane-focus). Every header
  // — collapsible or not — is focusable by pointer click and keyboard
  // traversal; this node drives the focus ring and the per-pane key bindings.
  // The container injects a node it owns ([WorkbenchViewPane.headerFocusNode]) so
  // it can move focus between header stops for Up/Down traversal (§spec:view-stack);
  // the standalone pane owns its own. [_ownsFocusNode] guards disposal so the
  // pane disposes only the node it created.
  late final bool _ownsFocusNode = widget.headerFocusNode == null;
  late final FocusNode _headerFocusNode =
      widget.headerFocusNode ??
      FocusNode(debugLabel: 'WorkbenchViewPane header');

  // Reveal state for header actions (§spec:section-header-actions). Hover and
  // focus are tracked independently; either reveals the actions while the
  // pane is expanded.
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    // Dispose only the node this pane created; an injected node is owned and
    // disposed by the container (§spec:view-pane-focus).
    if (_ownsFocusNode) _headerFocusNode.dispose();
    super.dispose();
  }

  /// The expansion the pane renders: the host's value when controlled,
  /// otherwise the internal state.
  bool get _isExpanded => widget.expanded ?? _expanded;

  /// Actions show only while expanded, and then on hover, on focus, or when
  /// pinned always-visible. Collapsing hides them entirely — VS Code gates
  /// reveal and hide-on-collapse with one compound rule.
  bool get _actionsVisible =>
      widget.actions.isNotEmpty &&
      _isExpanded &&
      (widget.actionsAlwaysVisible || _hovered || _focused);

  /// Toggle the pane. A toggle always flips the value, so it routes through
  /// [_setExpanded] (whose no-op-on-equal guard never trips for a flip).
  void _handleToggle() => _setExpanded(!_isExpanded);

  /// Drive the pane to an explicit expanded state (§spec:view-pane-focus). It
  /// applies in uncontrolled mode and fires [WorkbenchViewPane.onExpandedChanged]
  /// — but only when the value actually changes, so Left on an already-collapsed
  /// pane (or Right on an already-expanded one) is a no-op rather than a
  /// redundant callback. Uncontrolled panes apply the change themselves;
  /// controlled panes wait for the host to push the new value.
  void _setExpanded(bool next) {
    if (next == _isExpanded) return;
    if (widget.expanded == null) {
      setState(() => _expanded = next);
    }
    widget.onExpandedChanged?.call(next);
  }

  /// A pointer click focuses the header; on a collapsible header it also
  /// toggles the pane (§spec:view-pane-focus). The InkWell paints its splash;
  /// this wires the focus + toggle behind it.
  void _handleHeaderTap() {
    _headerFocusNode.requestFocus();
    if (widget.collapsible) _handleToggle();
  }

  /// Per-pane key bindings on a focused header (§spec:view-pane-focus): on a
  /// collapsible header Enter/Space toggle, Left collapses, Right expands. The
  /// same keys are no-ops on a non-collapsible header (no disclosure state).
  /// Up/Down are left unhandled so they bubble to the container's header
  /// traversal (§spec:view-stack).
  KeyEventResult _handleHeaderKey(FocusNode node, KeyEvent event) {
    if (!widget.collapsible) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _handleToggle();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _setExpanded(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _setExpanded(true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Wrap [header] in the section-header band + rule.
  ///
  /// A collapsible pane stacks in a [WorkbenchViewContainer], where its header
  /// is the canonical [WorkbenchLayoutConstants.viewPaneHeaderHeight] band
  /// (§spec:view-stack) — fixed even when the theme suppresses both tokens, so
  /// a collapsed pane's height is deterministic and matches the stack's
  /// measured natural height. A non-collapsible standalone pane keeps the
  /// prior behavior: with both tokens null the header renders unwrapped at its
  /// intrinsic row height; otherwise the fixed-height [Container] paints the
  /// band (background token, null → no fill) and a 1px top rule (border token,
  /// null → no rule), the rule absorbed within the canonical height.
  Widget _withHeaderChrome(WorkbenchTheme theme, Widget header) {
    final band = theme.sideBarSectionHeaderBackground;
    final rule = theme.sideBarSectionHeaderBorder;
    if (band == null && rule == null && !widget.collapsible) return header;
    return Container(
      height: WorkbenchLayoutConstants.viewPaneHeaderHeight,
      decoration: BoxDecoration(
        color: band,
        border: (rule == null || !widget.showTopRule)
            ? null
            : Border(top: BorderSide(color: rule)),
      ),
      child: header,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    // Header order follows VS Code's pane header: twisty → title → metadata
    // (infoTooltip) → actions (rightmost). Metadata hugs the title;
    // operations hug the right edge (§spec:section-header-actions).
    final header = Row(
      children: [
        // The twisty space is always reserved so titles align whether or not
        // the pane is collapsible — VS Code always renders the twisty
        // container (viewPane.ts renderHeader). A non-collapsible pane shows
        // no chevron but keeps the indent; the title never re-justifies.
        if (widget.collapsible)
          Icon(
            _isExpanded
                ? Symbols.expand_more_rounded
                : Symbols.chevron_right_rounded,
            size: WorkbenchLayoutConstants.iconMd,
            color: theme.descriptionForeground,
          )
        else
          const SizedBox(width: WorkbenchLayoutConstants.iconMd),
        const SizedBox(width: WorkbenchLayoutConstants.spacingXs),
        Expanded(
          child: Text(widget.title.toUpperCase(), style: theme.sectionTitle),
        ),
        if (widget.infoTooltip != null) ...[
          const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
          Tooltip(
            message: widget.infoTooltip!,
            child: Icon(
              Symbols.info_rounded,
              size: WorkbenchLayoutConstants.iconMd,
              color: theme.descriptionForeground,
            ),
          ),
        ],
        // Actions render raw in the rightmost zone, only when visible. The
        // shell applies no height clamp — the header row grows to the tallest
        // action (§spec:section-header-actions). Action gestures handle their
        // own taps, so activating one does not bubble to the header toggle
        // (§spec:section-disclosure).
        if (_actionsVisible) ...[
          const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
          ...widget.actions,
        ],
      ],
    );

    // Click-to-focus surface (§spec:view-pane-focus). The InkWell paints the
    // pointer splash and routes the tap to [_handleHeaderTap], which focuses
    // the header and — on a collapsible pane — toggles it. The InkWell does not
    // own focus (canRequestFocus: false); the outer [Focus] node is the single
    // focus stop, so the header is one tab stop, not two. Action taps inside
    // the header handle their own gestures and do not bubble here.
    Widget headerSurface = InkWell(
      onTap: _handleHeaderTap,
      canRequestFocus: false,
      child: header,
    );

    // A collapsible header carries the expanded/collapsed a11y state — a
    // mouse-only disclosure control is not canon-complete
    // (§spec:section-disclosure). A non-collapsible header is still focusable
    // and operable by keyboard (the Focus node below) but has no such state.
    if (widget.collapsible) {
      headerSurface = Semantics(
        button: true,
        expanded: _isExpanded,
        child: headerSurface,
      );
    }

    // The focus ring (§spec:view-pane-focus): a constant 1px border that paints
    // [WorkbenchTheme.focusBorder] while focused and is transparent at rest.
    // Reserving the border either way keeps the header from reflowing as focus
    // moves — VS Code paints a 1px focus outline on `.pane-header`.
    headerSurface = DecoratedBox(
      key: viewPaneHeaderFocusRingKey,
      decoration: BoxDecoration(
        border: Border.all(
          color: _focused ? theme.focusBorder : Colors.transparent,
        ),
      ),
      child: headerSurface,
    );

    // Every header is a single focus stop (§spec:view-pane-focus): focusable by
    // click and traversal, painting the ring and driving the per-pane keys. The
    // node also reports descendant focus (a focused action), so focusing the
    // header — by click or Tab — reveals its actions (§spec:section-header-actions).
    headerSurface = MouseRegion(
      onEnter: (_) {
        if (!_hovered) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      // A tap on any surface that is not this header clears the ring
      // (§spec:view-pane-focus): Flutter retains focus until another control
      // claims it, so — matching the web blurring the active control on an
      // outside click — the header drops focus explicitly rather than lingering
      // on a header the user has left.
      child: TapRegion(
        onTapOutside: (_) {
          if (_headerFocusNode.hasFocus) _headerFocusNode.unfocus();
        },
        child: Focus(
          focusNode: _headerFocusNode,
          onFocusChange: (focused) {
            if (focused != _focused) setState(() => _focused = focused);
          },
          onKeyEvent: _handleHeaderKey,
          child: headerSurface,
        ),
      ),
    );

    // Section-header chrome (§spec:view-stack); see _withHeaderChrome.
    headerSurface = _withHeaderChrome(theme, headerSurface);

    // The container may make the chromed header a drag handle for pane reorder
    // (§spec:view-stack). VS Code's `draggable` attribute sits on the whole
    // `.pane-header`, so wrap after the band/rule chrome.
    if (widget.headerWrapper != null) {
      headerSurface = widget.headerWrapper!(headerSurface);
    }

    final showBody = !widget.collapsible || _isExpanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Bounded panes are forced to a fixed height by the splitview container;
      // a min-size column would leave the body unconstrained, so it stretches
      // to fill (the body scroller then bounds itself). A standalone pane keeps
      // min sizing so it grows to its content.
      mainAxisSize: (widget.boundedBody && showBody)
          ? MainAxisSize.max
          : MainAxisSize.min,
      children: [
        headerSurface,
        // Body sits flush under the header — VS Code's `.pane-body` has no top
        // inset; the host body owns any padding (§spec:view-stack).
        if (showBody)
          // In the splitview the body is bounded and scrolls internally
          // (§spec:view-stack): the container apportions a fixed height, the
          // body fills the leftover and scrolls when its content overflows —
          // the per-pane scroll boundary. A standalone pane renders the body
          // raw and grows to its content.
          if (widget.boundedBody)
            Expanded(
              child: SingleChildScrollView(child: widget.child),
            )
          else
            widget.child,
      ],
    );
  }
}

/// Bordered container for an inline list item or grouped fields.
/// No implicit heading.
class WorkbenchCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WorkbenchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(WorkbenchLayoutConstants.spacingMd),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(_contentBorderSide(theme)),
        borderRadius: WorkbenchLayoutConstants.containerRadius,
      ),
      child: child,
    );
  }
}

/// Bordered card whose header row contains a leading toggle and a
/// settings-style label title. When [enabled] is false, [child] is dimmed
/// and input is suppressed, but layout does not reflow. The toggle
/// itself remains interactive so callers can re-enable.
class WorkbenchToggleCard extends StatelessWidget {
  final String title;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WorkbenchToggleCard({
    super.key,
    required this.title,
    required this.enabled,
    required this.onChanged,
    required this.child,
    this.padding = const EdgeInsets.all(WorkbenchLayoutConstants.spacingMd),
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(_contentBorderSide(theme)),
        borderRadius: WorkbenchLayoutConstants.containerRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: WorkbenchLayoutConstants.switchWidth,
                height: WorkbenchLayoutConstants.switchHeight,
                child: FittedBox(
                  child: Switch(
                    value: enabled,
                    onChanged: onChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: WorkbenchLayoutConstants.spacingSm),
              Expanded(child: Text(title, style: theme.labelText)),
            ],
          ),
          const SizedBox(height: WorkbenchLayoutConstants.spacingSm),
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(opacity: enabled ? 1.0 : 0.4, child: child),
          ),
        ],
      ),
    );
  }
}

/// Centered icon + title + subtitle + optional action.
class WorkbenchEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const WorkbenchEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.workbenchTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(WorkbenchLayoutConstants.spacingLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: WorkbenchLayoutConstants.iconXxl,
              color: theme.descriptionForeground,
            ),
            const SizedBox(height: WorkbenchLayoutConstants.spacingMd),
            Text(title, style: theme.sectionTitle, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: WorkbenchLayoutConstants.spacingXs),
              Text(
                subtitle!,
                style: theme.helperStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: WorkbenchLayoutConstants.spacingMd),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

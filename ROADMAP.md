# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## WorkbenchViewPane Disclosure §road:viewpane-disclosure

Give `WorkbenchViewPane` opt-in collapse/expand per
§spec:section-disclosure.

### Add opt-in collapse to WorkbenchViewPane §road:add-viewpane-collapse

Add `collapsible` / `initiallyExpanded` and controlled
`expanded` / `onExpandedChanged` to `WorkbenchViewPane` in
`lib/src/workbench_content.dart`, rendering a leading twistie chevron,
toggling body visibility on header pointer/keyboard activation, and
exposing `Semantics(expanded:)`. §spec:section-disclosure.

**Verify:** In the example app a collapsible view pane shows a leading
chevron; clicking its header — or Enter/Space when focused — hides and
shows the body and flips the chevron. A widget test toggles the header
and asserts body visibility changes, the chevron orientation reflects
state, and the header reports an expanded/collapsed Semantics flag;
non-collapsible panes render unchanged.

## WorkbenchViewPane Header Actions §road:viewpane-actions

Give `WorkbenchViewPane` a hover/focus-revealed, collapse-aware header
action zone per §spec:section-header-actions. Depends on
§road:viewpane-disclosure.

### Add hover-revealed header actions to WorkbenchViewPane §road:add-viewpane-actions

Add an ordered `actions: List<Widget>` to `WorkbenchViewPane` in
`lib/src/workbench_content.dart`, rendered in the rightmost header zone
(order twisty → title → `infoTooltip` → actions), hidden until header
hover or focus and only while expanded, hidden entirely when collapsed,
with an always-visible opt-in, and not toggling the pane on action
activation. §spec:section-header-actions. Depends on
§road:add-viewpane-collapse.

**Verify:** In the example app a view pane's actions are invisible until
the header is hovered, appear on hover while expanded, and vanish when
the pane collapses. A widget test drives a pointer hover over the header
and asserts the action becomes visible, collapses the pane and asserts
the action hides, taps an action and asserts the pane does not toggle,
and confirms an always-visible pane shows its actions without hover.

# workbench_shell Specification

A Flutter package that renders VS Code-style workbench chrome — the
activity bar, sidebar, editor area, bottom panel, status bar, menu
bar, and a small vocabulary of structural primitives that sidebars
and bottom panels compose to build their bodies. The package
depends only on Flutter and a handful of general-purpose
pub.dev libraries, so any Flutter desktop or mobile app can adopt
the chrome without inheriting a host application's domain model.

The governance here is package-local — it describes the workbench
shell's design intent as the standalone published artifact, not any
consuming application.

---

## Problem Statement §spec:problem-statement

*Status: complete*

Desktop Flutter applications repeatedly re-implement VS Code-style
IDE chrome (activity bar + sidebar + editor + bottom panel + status
bar). Each re-implementation drifts: section headers render at
different sizes across sidebars in the same app, tab strips
reinvent their close affordance, status bar items invent their own
badge geometry. The chrome looks IDE-adjacent rather than IDE-
canonical, and the visual grammar fragments as features land.

`workbench_shell` addresses this by owning the chrome widgets and
the structural primitives that compose section bodies. Hosts
supply content and domain data; the shell supplies layout,
typography, spacing, and theming.

---

## Scope §spec:scope

*Status: complete*

**In scope**

- Workbench layout: activity bar, sidebar stack, editor area,
  bottom panel, status bar.
- Stacked sidebar view containers (§spec:view-stack): the activity bar
  selects a view container that stacks independently collapsible view
  panes (`WorkbenchViewPane`) from typed view descriptors as a
  fixed-height splitview — panes apportion the height and scroll
  internally — with separators.
- Tabbed bottom panel (`WorkbenchTabbedPanel`,
  `WorkbenchPanelTab`) with host-supplied tab descriptors, stable
  ids, and a View-menu / keyboard-shortcut focus contract.
- Status bar container plus typed item variants
  (`WorkbenchStatusBarItem`, `WorkbenchStatusBarAction`,
  `WorkbenchStatusBarProblemsItem`).
- Platform-conditional menu bar (`WorkbenchMenuBar`): native
  `PlatformMenuBar` on macOS, in-window Material `MenuBar` strip
  on Windows and Linux.
- Keyboard bindings (`WorkbenchShortcuts`) aligned with VS Code
  defaults.
- Structural primitives: `WorkbenchViewPane`, `WorkbenchCard`,
  `WorkbenchToggleCard`, `WorkbenchEmptyState`.
- Theming: `WorkbenchTheme` (chrome tokens),
  `WorkbenchThemeController` (theme switching, VS Code JSON
  loader, `TokenTheme` for syntax highlighting), `TokenTheme`,
  `WorkbenchLayoutConstants` (fixed geometry).
- Notification Center (§spec:notification-center): `NotificationService`,
  `NotificationHost` overlay, and `NotificationProgressController`
  for long-running tasks.

**Out of scope**

- Form controls (text fields, dropdowns, toggles, action
  buttons). See §spec:form-controls-excluded for the re-promotion gate.
- Host-specific domain types, BLoCs, or state management.
- Editor widgets (text editing, syntax-highlighted viewers).
  Consumers supply their own editor content inside
  `WorkbenchLayout`'s editor slot.
- Hierarchical tree rows (`TreeItem` — a folder's disclosure triangle
  inside a view body). VS Code renders these through a separate tree
  component; view bodies are host content (§spec:view-stack). The
  shell's collapsible primitive is the view pane, not a tree row.

---

## Shell Capability Boundary §spec:capability-boundary

*Status: complete*

Chrome that is generic to a VS Code-style workbench belongs in
`workbench_shell`; chrome that encodes a specific product's
domain belongs outside.

**Boundary test**: could an arbitrary application use the shell
without knowing any particular host exists? Section navigation,
status-bar chrome, the View menu, and tabbed bottom-panel
composition satisfy this test.

**Dependency footprint**: `lib/` imports only Flutter, `equatable`,
`material_color_utilities`, `material_symbols_icons`, and `meta`
(Dart's `@internal` annotation, already a Flutter transitive dep — used
to keep the container-only `WorkbenchViewPane.inContainer` seam off the
public API, §spec:view-stack). No file under `lib/` imports a host- or
domain-specific package; consuming applications can enforce an
equivalent import boundary with a lint gate of their own.

**No BLoCs, no domain types, no state beyond what a tabbed
panel's `TabController` requires**. Pure widgets, theme
extensions, and value types.

**Canon enforcement, not canon description**. When the spec
calls a treatment "canonical" or "VS Code-style" — text-only
tab labels, uppercase tab and section heading text, fixed
status bar height, the panel-toggle living in the View menu
rather than the status bar — the API surface enforces it at
the type level or in the shell's rendering layer. The shell
does not accept a permissive `Widget` field and document that
consumers shouldn't put icons in it; does not accept a `String`
field and document that consumers should `.toUpperCase()` first;
does not expose a "panel visibility action" slot in the status
bar that consumers are asked not to use. The renderable belongs
to the shell. Consumers that need richer expression than the
canon allows get a typed structured primitive (e.g., a
`PanelTabBadge(count)` field for the count badge case) rather
than a widget escape hatch. This invariant prevents
cross-consumer drift — the failure mode that `workbench_shell`
exists to remove (§spec:problem-statement).

The precedent is in the codebase: `WorkbenchViewPane` titles render
uppercase regardless of how the consumer cases the input string,
matching VS Code's pane header (§spec:chrome-typography-canon); `WorkbenchTabbedPanel` does
the same for tab labels and renders the inline count badge from
a typed `PanelTabBadge` payload, painting the pill in VS Code's
generic badge accent (`badge.background`). Every new chrome
surface follows the same model.
§spec:view-stack applies the rule to the sidebar body itself: the host
supplies typed view descriptors, not a free-form sidebar `Widget`,
removing the last whole-surface escape hatch in the chrome. It also
moves view collapsibility from a host flag to a container-derived
decision, so the shell — not the host — enforces which panes can
collapse.

---

## Structural Primitives §spec:structural-primitives

*Status: complete*

Structural primitives encode the workbench's visual hierarchy as
types. A sidebar that uses `WorkbenchViewPane` around a
`WorkbenchCard` gets consistent heading sizes, card borders, and
section padding by construction. Every sidebar and panel reads the
same `WorkbenchTheme` tokens through the same widgets, so styling
drift (one sidebar's card title rendering 12pt, another's 14pt
because each file reaches into tokens directly) cannot happen.

**Why primitives, not style mixins**: VS Code's webview and
tree-view APIs make the same choice — the hierarchy is a type,
not a convention. A mixin approach would let a host skip the
primitive, reach into the theme, and invent inconsistent
typography at one call site — which is the failure mode the
primitives exist to prevent.

**Primitive vocabulary**:

| Widget | Purpose |
|---|---|
| `WorkbenchViewPane` | Top-level view pane in a sidebar or panel body. Title renders uppercase per §spec:chrome-typography-canon (VS Code pane-header canon), padded for pane framing |
| `WorkbenchCard` | Bordered container; the atom of sidebar content |
| `WorkbenchToggleCard` | Card with a leading toggle and expand/collapse |
| `WorkbenchEmptyState` | Canonical empty-state with icon, title, optional action |

**Observable behavior**: every sidebar and bottom panel renders
with consistent section framing — section titles at the same
size and weight, cards and toggle cards at the same border radius
and border color. Layout tokens come from `WorkbenchLayoutConstants`; colors
and typography come from `WorkbenchTheme`.

**The top-level primitive is `WorkbenchViewPane`** (the canonical "view
pane" noun; renamed from the shell-invented `WorkbenchSection` per
§spec:scope). §spec:view-stack builds the stacked view-container model
around it. The other primitives — `WorkbenchCard`,
`WorkbenchToggleCard`, `WorkbenchEmptyState` — are content
stylings inside a view-pane body and keep their names.
Hierarchical tree rows (a folder's disclosure triangle) are a distinct
VS Code concept (`TreeItem`) the shell does not own; view bodies are
host content (§spec:scope).

---

## View Container and View Stack §spec:view-stack

*Status: complete*

The sidebar stacks several collapsible **views** in one **view
container**, the VS Code model. The activity bar selects a view
container; the container renders an ordered stack of **view panes**
(`WorkbenchViewPane`), each with its own header and body, each
collapsing independently while its header stays visible. The shell owns
the stack — the host supplies typed view descriptors, not a
sidebar-body widget. (VS Code reference: a view container is a
`ViewPaneContainer`, a `PaneView` over a `SplitView` of `ViewPane`s.
This section documents the shell's deviations, not VS Code's internals.)

**Problem**: the sidebar renders one host-built body at a time. The
activity bar switches between bodies, and the host composes each body as
a free-form widget tree (today a `Column` of `WorkbenchViewPane`s inside
the host's own scroll view). VS Code instead stacks several views in one
container — Explorer shows Open Editors, the file tree, Outline, and
Timeline as four independently collapsible panes that apportion the
sidebar's height and scroll internally. The shell cannot express this:
it has no stack, no per-view collapse, no inter-view separators, no
height apportionment or per-pane scroll. Every host that wants the VS
Code sidebar reinvents the stack and drifts from the canon
(§spec:problem-statement).

**The shell owns the stack; the host supplies typed view descriptors**:
the sidebar body is no longer a host `Widget`. For each view container
the host supplies an ordered list of view descriptors — stable id,
title, optional metadata, optional actions
(§spec:section-header-actions), optional initial/controlled expansion
state (§spec:section-disclosure), and a body builder — and the shell
renders the stack. The descriptor carries no `collapsible` flag:
whether a view can collapse is derived by the container from the number
of views (below), not chosen per view. A free-form sidebar body is
exactly the permissive `Widget`
field §spec:capability-boundary rejects, scaled to the whole sidebar;
replacing it with typed descriptors is the same move the bottom panel
already makes with `WorkbenchPanelTab` descriptors (§spec:tabbed-panel).
The host still owns each view's *body* content (§spec:scope) — the shell
owns the stacking, the headers, and the chrome between bodies.

**Terminology adopts VS Code's public vocabulary**:

- *View container* — the sidebar host for one activity-bar entry; holds
  one or more views; selected by the activity bar. (VS Code's
  `viewsContainers` contribution.)
- *View* — one collapsible pane in a container, rendered as a
  `WorkbenchViewPane`. (VS Code's `views` contribution; runtime
  `ViewPane`.)
- The pane primitive previously named `WorkbenchSection` is renamed
  `WorkbenchViewPane`. "Section" was a shell invention with no VS Code
  referent and collided with the activity-bar selection the layout API
  called a "section"; "view pane" is the canonical noun and removes the
  ambiguity.
- *Tree item* — a hierarchical row inside a view body (a folder in the
  file tree) with its own disclosure triangle. A distinct concept the
  shell does **not** own: VS Code renders it through a separate tree
  component (`TreeRenderer`, `TreeItemCollapsibleState`), and view
  bodies are host content. A view pane *hosts* content; a tree item *is*
  content. The shell's collapsible primitive is the view pane, never a
  tree row.

**Stack behavior**:

- Panes stack flush at the canonical view-pane header height
  (§spec:layout-constants) with no vertical gap between them. Every
  header stays visible; a collapsed pane shows only its header.
  Collapsing a pane frees its body height to the remaining expanded
  panes, which absorb the space; a collapsed pane occupies only its
  header height. A pane's body sits flush under its header — VS Code's
  `.pane-body` has no top inset; the host body owns any padding.
- Adjacent panes are separated by chrome on the header, not whitespace:
  each header paints a section-header background band, and a 1px top
  rule separates *adjacent* panes. The **first** pane in a container
  omits the rule — VS Code draws no divider above the first pane (and
  none between the container's own header and the first pane). Both
  come from `WorkbenchTheme` tokens mapped from VS Code's
  `sideBarSectionHeader.background` and `sideBarSectionHeader.border`,
  each nullable so a theme that omits the token suppresses that paint
  (§spec:theming, following the existing nullable-border pattern). These
  are **not** high-contrast-only: the bundled default themes set both to
  opaque or near-opaque values, so the band and the rule render in
  normal light and dark themes — they are the visible separation between
  VS Code's stacked panes, not whitespace.
- The container is a **fixed-height splitview**, not a scrolling column:
  it apportions the sidebar's height among the expanded panes (below),
  and each expanded pane's body is given a bounded height and **scrolls
  internally** when its content overflows that allotment. The stack
  scrolls as one region only as an *overflow fallback* — when the panes
  cannot all fit even at their minimum body heights
  (§spec:layout-constants). Normally the scroll boundary is each pane,
  not the container.

**Layout is a fixed-height splitview** (VS Code's sidebar is a vertical
`SplitView` of panes): the container divides its available height among
the **expanded** panes rather than letting each pane grow to its
content. Each pane has a minimum body height (§spec:layout-constants);
the remaining height is distributed **proportionally** across the
expanded panes (a freshly opened container divides it evenly). A
collapsed pane occupies only its header height and contributes nothing
to the body apportionment, so collapsing a pane hands its freed height
to the expanded siblings in proportion, and expanding one takes height
back from them. A pane whose content exceeds its allotment scrolls
inside its own body; the whole stack scrolls together only when the
expanded panes cannot fit at their minimum body heights — the overflow
fallback.

**Why a splitview, not a scrolling column**: a scrolling column (each
pane sized to its content, the whole stack scrolling) is simpler but
diverges visibly — a tall pane pushes its siblings off screen and the
entire sidebar scrolls as one, instead of each pane holding its place
and scrolling internally. It also cannot express sash-resize, which *is*
re-apportionment of a fixed height: a sash drag trades height between two
adjacent panes through the same mechanism that distributes it. The
splitview is the only model that yields both the per-pane scroll
behavior and the sash sizing layer.

**Collapsibility is derived from view count, not a host flag**: the
container decides whether each pane can collapse, matching VS Code
(`ViewPaneContainer.updateViewHeaders`):

- *Multiple views* — every pane is collapsible and shows its header.
- *Single view* — the lone pane is non-collapsible. By default its
  header stays visible but cannot collapse; a container option can
  instead merge it with the container (header hidden, body fills the
  sidebar).

The host passes no per-view `collapsible` flag. Collapsibility is canon
the container enforces — a host cannot mark one pane of a stack
non-collapsible and produce an incoherent stack
(§spec:capability-boundary). The pane's *expansion state*
(expanded/collapsed, controlled or uncontrolled) remains the pane's per
§spec:section-disclosure; only the *collapsible* decision moves to the
container.

**Sash resize re-apportions between two neighbors**: a draggable sash sits
on the boundary an expanded pane shares with its nearest expanded neighbor
above. Its cursor mirrors VS Code's horizontal sash — bidirectional while
the sash can move both ways, and a single-direction arrow once a neighbor
hits its minimum body height (down at the top limit, up at the bottom).
Dragging tracks the pointer's *absolute* position from where the drag
began, not an accumulated delta, so overshooting a clamp parks the sash at
the limit and it re-tracks the cursor without offset once the pointer
returns. The drag transfers body height from one pane to the other, clamped
so neither body falls below the minimum body height. The result persists: the
container records the two panes' user-set sizes as **proportional weights**
and holds them across rebuilds, collapse, and expand, so the manual
proportions override the even default until the user resizes again. The
weights are never absolute pixels — the container always rescales the
expanded panes' weights to fill the available body pool, re-clamped to each
pane's minimum body height, so the stack fills its height at any window size.
A collapse removes one pane from the expanded set: its freed body is absorbed
by the remaining expanded panes **in proportion to their weights** (survivors
keep their relative sizes), and the collapsed pane retains its weight so an
expand restores its prior size and shrinks the others proportionally. A
collapsed pane has no body boundary, so it carries no sash and is never a
sash neighbor.

**Why proportional weights, not absolute heights**: an earlier model stored
each resized pane's body as a fixed pixel target and split only the *unsized*
remainder among the rest. When every remaining expanded pane was sized, a
collapse freed body that no pane claimed — the stack laid out shorter than the
sidebar and left dead space at the bottom, contradicting the splitview
invariant that the expanded panes always fill the height. Modeling sizes as
weights that always rescale to the available pool removes the two-class (sized
vs. unsized) split: every expanded pane shares one proportional distribution,
so freed space is always absorbed and the stack has no internal dead space.

**Why preserve proportions across collapse, not reset to even**: resetting the
survivors to an even split on every collapse is simpler but discards the
user's sizing the moment they collapse a neighbor — a resize is forgotten on
the next collapse/expand cycle. VS Code preserves each pane's size across
collapse (a `Pane` reports its remembered `expandedSize` on re-expand and the
`SplitView` keeps sibling proportions), so a user who sizes the stack and
toggles a pane finds their layout intact. Preserving proportions is the canon
and the better UX; it costs only remembering the collapsed pane's weight.

**Sash sizing is host-persistable via seed-plus-commit** (§spec:resize-geometry):
the body heights are shell-owned, seeded once from the container's `initialSizes`
and committed on drag-end through `onSizesChangeEnd` (the full final map). There
is no controlled `sizes` property and no per-frame callback — unlike `order` and
a descriptor's `expanded`, drag geometry follows the seed-plus-commit shape, not
the controlled/uncontrolled pattern. Restored sizing re-clamps to the current
available height and each pane's minimum body height — it expresses proportional
intent, not an absolute-pixel contract, since the body pool differs between
sessions and window sizes.

**Header drag reorders panes**: the user drags a pane header onto another
pane to reorder the stack, mirroring VS Code's `PaneView` header
drag-and-drop. The header is the drag handle; while a drag is over a target
pane, a translucent drop overlay covers the target's top or bottom half — the
slot the dragged pane would occupy — following VS Code's `ViewPaneDropOverlay`
UP/DOWN split. The overlay color is the theme's `sideBar.dropBackground`
(VS Code defaults it to `editorGroup.dropBackground`; a translucent fill the
pane shows through). On drop the **shell owns the order** — it permutes the
rendered stack directly, consistent with the shell owning the stack while the
host supplies view *content*, not arrangement (§spec:capability-boundary), and
with VS Code's `PaneView.movePane`. Order is **uncontrolled by default**,
seeded from the descriptor-list order — mirroring a pane's uncontrolled
`expanded` (§spec:section-disclosure). A container may instead supply a
controlled `order` (descriptor ids in render order) plus an optional
`onReorder` notification: a drag then fires `onReorder` without self-permuting
and the host updates `order`, the same controlled/uncontrolled split the
descriptors' expansion already follows. `onReorder` is a notification (e.g. to
persist order across restarts), never required for reorder to function. Reorder
needs two distinct slots, so it engages only with two or more panes.

**Container selection mirrors today's section navigation**: the activity
bar selects the active view container, controlled or uncontrolled — the
same split §spec:workbench-layout defines, with the "section" navigation
renamed to view-container navigation as part of adopting the vocabulary.
Reselecting the active container toggles sidebar visibility, unchanged.

**Observable behavior**:

- A view container renders an ordered stack of view panes from typed
  view descriptors; the host supplies no sidebar-body widget and no
  per-view collapsible flag.
- Panes stack flush at the view-pane header height with no inter-pane
  gap, and each body sits flush under its header; adjacent panes are
  separated by a header background band and a 1px top rule (each
  nullable per theme, rendered in the bundled default themes). The
  first pane in a container omits the top rule.
- Whether a pane is collapsible is derived from the container's view
  count: multiple views → all collapsible; a single view → non-collapsible,
  or merged (header hidden, body fills) by container option.
- Every view-pane header is visible (except the merged single-view
  case); a collapsed pane occupies only its header height and its freed
  space flows to the expanded panes.
- The container apportions its height among the expanded panes
  (proportionally; a collapsed pane takes only its header height); an
  expanded pane scrolls inside its own body when its content exceeds its
  allotment. The whole stack scrolls together only as an overflow
  fallback — when the expanded panes cannot fit at their minimum body
  heights.
- The laid-out stack exactly fills the container's available height
  regardless of collapse state or prior sizing: collapsing a pane or dragging
  a sash never leaves dead space at the bottom — the expanded panes absorb the
  freed height in proportion to their weights. Dead space appears only in the
  overflow fallback's inverse sense (the panes overflow, never underflow).
- Dragging the sash on the boundary between two adjacent expanded panes
  transfers body height between them, clamped at each pane's minimum body
  height; the new proportions hold across rebuilds, collapse, and expand —
  collapsing a pane preserves the survivors' relative sizes and a re-expand
  restores the collapsed pane's prior size. A collapsed pane carries no sash.
  Sizing is shell-owned, seeded from `initialSizes` and committed on drag-end
  via `onSizesChangeEnd` (§spec:resize-geometry).
- Dragging a pane header onto another pane reorders the stack: a translucent
  drop overlay marks the target's upper or lower half during the drag, and on
  drop the shell permutes the stack itself. Order is shell-owned and
  uncontrolled by default (seeded from the descriptor-list order); a container
  may instead supply a controlled `order` plus an optional `onReorder`
  notification. Reorder engages only with two or more panes and needs no
  callback to function.
- The activity bar selects the active view container (controlled or
  uncontrolled); reselecting the active container toggles sidebar
  visibility.

---

## View Pane Maximum Body Size §spec:view-pane-max-body

*Status: complete*

**Problem**: an expanded pane always fills its apportioned share of the body
pool (§spec:view-stack). When a pane's natural content is shorter than that
share — a fixed control panel, a few buttons — the pane stretches and the
content floats above whitespace inside the body. The shell offers no way for a
host to cap a pane to its content height; every pane is effectively unbounded.
VS Code solves this with a per-view `maximumBodySize`; the shell has only the
uniform minimum body height (§spec:layout-constants) and no maximum.

**A view descriptor carries an optional `maximumBodySize` (pixels), default
unbounded.** It is the per-pane cap mirroring VS Code's `maximumBodySize`
(`paneview.ts`, default `Number.POSITIVE_INFINITY`). An unset value is
unbounded, so the existing fill-and-distribute behavior is unchanged for every
pane that does not opt in. The minimum body height stays a uniform constant
(§spec:layout-constants), not per-descriptor: the floor is the same for every
pane, while a meaningful maximum is content-specific (a hug-to-content panel
versus a tree that should fill), so only the maximum moves to the descriptor.

**The clamp is VS Code canon: maximum wins over minimum when they invert.**
Each expanded pane's apportioned body is clamped to `[minBody, maxBody]` using
VS Code's argument order — `min(max(value, minBody), maxBody)` — so when
`maxBody < minBody` the outer `min(…, maxBody)` dominates and the pane renders
*below* the minimum body height. No guard coerces the maximum up to the
minimum. This matches microsoft/vscode's `clamp` utility (`numbers.ts`) and
every splitview call site, which pass `maximumSize` as the outer bound; a view
that sets `maximumBodySize = 60` against the 120 floor renders a 60px body, not
120. Mirroring the argument order exactly is the parity contract — the
alternative (`max(min(value, maxBody), minBody)`, floor wins) would make a
sub-floor maximum a no-op and defeat hug-to-content, the whole point of the
field.

**A finite maximum caps sash growth, not the floor.** A sash drag can grow a
pane no larger than its `maximumBodySize` (mirroring VS Code's `resizeView`
clamp to `min(maximumSize, available)`); the sash's lower limit remains the
minimum body height. A pane with no maximum is unchanged.

**Trailing dead space is the deliberate consequence, matching canon.** When the
expanded panes' maxima sum to less than the body pool, the slack has no pane to
flow into and pools as a gap below the last pane. This is the explicit
exception to §spec:view-stack's invariant that the expanded panes always fill
the height: that invariant holds while panes are unbounded (the default), and a
host opts into the gap by capping panes. VS Code behaves identically —
`distributeEmptySpace` cannot place a delta once every view is at its maximum.

**Observable behavior**:

- A view descriptor may set `maximumBodySize`; unset means unbounded and the
  pane fills its apportioned share as before.
- An expanded pane never renders a body taller than its `maximumBodySize`. When
  the maximum is below the minimum body height, the maximum wins and the pane
  renders below the floor (VS Code clamp parity).
- A sash drag cannot grow a pane past its `maximumBodySize`; the lower clamp
  stays the minimum body height.
- When the expanded panes' maxima cannot consume the body pool, the unfilled
  slack appears as a gap below the last pane rather than stretching any capped
  pane.

---

## View Container State Retention §spec:view-container-state

*Status: complete*

**Problem**: switching the active view container from the activity bar and
returning resets the previous container's pane state — pane order, which panes
are collapsed, and sash-adjusted body sizes all revert to defaults. The
sidebar mounts only the active container (§spec:workbench-layout), so a single
container instance is reconciled to whichever container is active; the prior
container's shell-owned state (§spec:view-stack) is discarded on switch and
rebuilt at defaults on return. Surfaced by shell-owned reorder.

**The shell retains each opened view container across activity-bar switches.**
Once a container has been shown, the shell keeps it alive while another
container is active and restores it intact on return — its pane order
(§spec:view-stack), per-pane expansion (§spec:section-disclosure), and
sash-adjusted body sizes all survive the switch. This mirrors VS Code, whose
composite part shows a viewlet then *hides and retains* it on switch rather
than rebuilding it (the instance is cached, the DOM merely detached), while
the per-container view model holds order/collapsed/size for the session. The
retained state is the shell's own (the host supplies view *content*, not
arrangement — §spec:capability-boundary), so retaining it is the shell's
responsibility, not the host's.

**Retention is lazy: a container is built only once first opened.** A view
container whose activity-bar entry the user never selects is never
constructed, and its host body builders never run. This matches VS Code's lazy
composite creation and avoids paying construction cost — including host body
work such as data fetches — for containers that are never viewed. The
alternative, eagerly mounting every container up front, is rejected: it would
run every container's body work on first layout regardless of use. Retention
therefore covers opened containers only.

**Cross-restart persistence remains the host's responsibility.** The shell
retains state only for the life of the layout; it does not persist pane layout
across application restarts. VS Code persists order/collapsed/size to its
storage service; the equivalent here is the host, consistent with the shell
owning no storage (§spec:capability-boundary). The shell exposes a hook for each
persistable concern, so a host can persist and rehydrate all to VS Code parity.
Order and expansion follow the controlled/uncontrolled pattern: a container's
`order` with `onReorder` (§spec:view-stack) and a descriptor's `expanded` with
`onExpandedChanged` (§spec:section-disclosure), each shell-owned and uncontrolled
by default, with the controlled value handing that concern to the host. Resize
geometry instead follows seed-plus-commit (§spec:resize-geometry): a container's
`initialSizes` with `onSizesChangeEnd`, and the layout's `initialSidebarWidth` /
`initialPanelHeight` with `onSidebarWidthChangeEnd` / `onPanelHeightChangeEnd`
(the outer resize seams) — shell-owned, seeded once, committed on drag-end.
§spec:layout-state-persistence bundles these per-concern seams into a single
serializable value, so a host persists one blob and lets the shell reconcile it
against changed descriptors rather than wiring and reconciling each seam.

**Retention also scopes pane state to its container by construction**,
removing a latent defect of the single shared instance: two containers that
declare the same view id would otherwise collide on expansion and size state.

**Observable behavior**:

- Reordering a pane, collapsing or expanding a pane, or sash-resizing a pane,
  then switching to another container and back, leaves that change intact.
- A view container whose activity-bar entry has never been selected is not
  built, and its view body builders do not run, until the first selection.
- Returning to a previously-opened container restores its panes in the order,
  expansion, and sizes they held when it was last active, for the life of the
  layout.
- Two containers that reuse the same view id keep independent pane state.

---

## View Container Layout State Persistence §spec:layout-state-persistence

*Status: complete*

**Problem**: §spec:view-container-state retains pane order, expansion,
visibility, and sizes for the life of the layout but not across
application restarts, and delegates cross-restart persistence to the
host through four per-concern seams (a container's `order` / `onReorder`
and `initialSizes` / `onSizesChangeEnd`, a descriptor's `expanded` /
`onExpandedChanged` and `visible` / `onVisibleChanged`). A host that
wants a user's sidebar arrangement to survive a restart otherwise derives
the shape of four container-keyed maps itself, reconciles a saved
arrangement against a descriptor set that may have changed since it was
written, and translates a drag reported in visible-pane indices back into
the full order that still includes hidden panes. These are shell-internal
mechanics — the shell already knows the map shapes and owns the reconcile
and reorder rules — yet every host reimplements them and drifts
(§req:success-criteria — a host shall not reimplement shell mechanics;
§req:priorities — shell ownership of applying persisted state is a
*shall*).

**The shell exposes its view-container arrangement as a single
serializable value.** A `WorkbenchLayoutState` bundles the four
controlled-seam concerns as container-keyed maps — pane sizes, pane
order, pane expansion, and view visibility — that a host reads once,
hands to its own storage, and hands back at startup, deriving no map
shapes and writing no reconcile or reorder logic of its own. The maps
mirror the shell's existing seam vocabulary exactly (§spec:view-stack
order and expansion, §spec:view-container-title visibility,
§spec:resize-geometry sizing), so the state is a snapshot of what those
seams already control, not a second model to keep in sync. The aggregate
seeds the shell-owned (uncontrolled) path only: a per-concern controlled
seam still wins for the concern it controls, so the two do not
double-apply.

**Serialization is the host's mechanism; the shape is the shell's
contract.** The state converts to and from a JSON-encodable primitive
map — not bytes, and never a storage key or a write to disk
(§spec:capability-boundary). A set-typed concern serializes as a list and
dedupes on read, so the encoded form is JSON primitives throughout.
Exposing a shell-owned conversion keeps the serialized *shape* the
shell's to evolve: a concern the shell adds later travels through the
conversion instead of being dropped by a host that hand-listed the old
fields — the brittleness the descriptor and spec `copyWith` seams remove.
Deserialization is tolerant — absent concerns default, unrecognized
concerns are ignored — so a value written by an older or newer shell
rehydrates without the host guarding versions.

**Reconciliation is distinct from deserialization and owns the
invariants.** Turning a map into a `WorkbenchLayoutState` is a structural
round-trip; resolving that state against the container's *current* view
descriptors is a separate operation, because it needs the live
descriptors, which do not exist at deserialize time. Reconciliation drops
arrangement for ids the host no longer declares, admits newly declared
views at their descriptor defaults, clamps persisted sizes to the current
geometry, and splices a visible-index reorder back into the full order
that includes hidden panes. The shell owns these rules because they
mirror shell internals — the visible-versus-hidden order model of
§spec:view-container-title and the size geometry of §spec:resize-geometry
— a host cannot reimplement without duplicating mechanics it does not own.

**Division of labor**: the shell owns the state model and its invariants
— the shape, the conversion contract, and reconciliation. The host owns
everything outside the shell's boundary: where the bytes live, what the
storage keys are named, when to seed (a host awaits its persistence load
before the layout's first build), and how the state merges alongside
unrelated host preferences. This is the boundary §spec:capability-boundary
draws for every concern — the shell is chrome and arrangement, the host
is storage and domain.

**Observable behavior**:

- A host that persists a `WorkbenchLayoutState` and rehydrates it on
  next launch restores the user's pane order, expansion, visibility, and
  sizes as they were, across an application restart.
- When the host's declared view set changes between persisting and
  rehydrating, the layout drops arrangement for views that no longer
  exist, shows newly declared views at their descriptor defaults, and
  clamps out-of-range sizes — rendering without error rather than
  stranding or mis-placing panes.
- A value written by a different shell version rehydrates: absent
  concerns take defaults, unrecognized concerns are ignored.
- The shell writes no bytes and names no storage key; removing the
  host's persistence layer leaves the shell's session-lifetime retention
  (§spec:view-container-state) unchanged.

**Rejected alternatives**:

- *Raw public maps only, no conversion.* The four maps are already
  primitive, so a host could serialize them by hand — but that
  reintroduces the silent field-drop the shell removes elsewhere: a new
  state concern would never reach persisted output. The shell owns the
  conversion so the shape evolves in one place.
- *The shell owns storage.* A storage layer in the shell violates
  §spec:capability-boundary and forces a persistence mechanism on every
  consumer. The shell hands over a serializable value; the host writes
  it.
- *Reconcile inside deserialization.* Impossible: reconciliation needs
  the live descriptors, absent when a map is turned into state.
  Deserialization and reconciliation are necessarily separate steps.

**Tradeoff accepted**: tolerant deserialization cannot distinguish a
concern that was absent from one explicitly at its default. For a
seed-and-restore model this is immaterial — both yield the default — and
it is the price of forward-compatibility across shell versions.

---

## View Container Title and Views Overflow §spec:view-container-title

*Status: complete*

The sidebar heading above the pane stack carries a right-aligned **overflow
(`⋯`) menu** whose first group is the shell-built **Views toggles** — one
checkable item per view in the container, checked when the view is visible.
Each item reads the view's `menuLabel` when set, falling back to its pane-header
`title` — mirroring VS Code's `IViewDescriptor.name` (the Views-menu label) being
distinct from a runtime-overridden pane title, as the file explorer shows the
workspace folder name in its header but "Folders" in the menu. Toggling an item
shows or hides that view's pane in the stack. The toggles
render **inline** in the `⋯` popup when they are its only group, and collapse
into a nested **`Views ▸` submenu** only when host overflow entries share the
popup — matching VS Code, which dissolves the submenu when it is the title's
sole secondary action (`panecomposite.ts` `getSecondaryActions`, the
`length === 1` branch). This is VS Code's composite title area: the bar above
the panes that names the active container and exposes container-level actions,
the canonical surface for choosing which of a container's views are shown. (VS
Code reference: the composite title renders `MenuId.ViewContainerTitle`; a
`Views` submenu at `order: 1` lists per-view visibility toggles driven by
`ViewContainerModel.setVisible`, gated by each descriptor's
`canToggleVisibility`. This section documents the shell's deviations, not VS
Code's internals.)

**The container title comes from the spec, falling back to the activity item.**
`WorkbenchViewContainerSpec` carries an optional `title`; the composite title
resolves to `spec.title` when set, otherwise the container's activity-bar item
label. The activity-item label stays the default for a primary container, so no
existing host changes. A container the activity bar never lists — the secondary
side bar's, assigned directly through `secondaryViewContainerId`
(§spec:secondary-sidebar) — has no activity item to name it, so without a
spec-level title its composite title renders blank. The spec-level `title` gives
every container a title source independent of the activity bar, mirroring VS
Code, where a view container carries its own title. A single-view container
merged under `mergeSingleView` hides the title strip regardless, so `title`
governs the multi-view and the unmerged single-view cases (reported in #93).

**Problem**: the sidebar heading (§spec:workbench-layout) renders only the
active container's uppercase label — a bare title row with an empty right
zone. A user cannot hide a view they don't want and re-show it later; the
stack is fixed to the descriptors the host declared. VS Code makes view
membership a user choice through the title overflow, so every host that wants
that affordance reinvents it and drifts from the canon
(§spec:problem-statement).

**Visibility is a third per-view shell-owned state, distinct from expansion
and order.** A view pane already has shell-owned *order* (§spec:view-stack)
and *expansion* (§spec:section-disclosure). Visibility — whether the pane is
in the stack at all — is separate: a collapsed pane keeps its header and
frees its body height to siblings, while a hidden pane leaves the stack
entirely. VS Code keeps the two distinct in its view model (visible vs.
collapsed); conflating them would lose the "not in the stack" state.
`WorkbenchViewDescriptor` gains `visible` (default true) and a `canHide`
flag (default true, VS Code's `canToggleVisibility`); a non-hideable view
shows no Views-submenu checkbox (or a disabled one) and cannot be hidden.

**Visibility follows the same controlled/uncontrolled retention seam as
order and expansion** (§spec:view-container-state): uncontrolled by default,
or controlled via `visible` + `onVisibleChanged` (presence of the callback
gates the mode) so a host can persist and rehydrate it to VS Code parity.
Visibility joins `order`/`onReorder` and `expanded`/`onExpandedChanged` as a
per-container persistable concern, not a new persistence mechanism.

**Where the shell holds it — the canon architecture.** Unlike order and
expansion (held in each `WorkbenchViewContainer`'s State), the uncontrolled
visibility store lives *above* the retained containers, in `WorkbenchLayout`
keyed by container id — the port of VS Code's `ViewContainerModel`
(`isVisible`/`setVisible`, persisted per container id, independent of the
active composite). This is what makes a hidden/shown view survive activity-bar
switches. The title row is the matching port of VS Code's single
`CompositePart` title area: **one** shared title chrome re-rendered for the
active container (not per-container title DOM), reading and writing the same
store — so toggling a checkbox updates both the active container's stack and
the open popup's live check state.

**Hidden panes keep their order slot; visible-view count drives
collapsibility.** Hiding a view removes its pane from the stack but retains
its position in `order`, so re-showing restores it where it was. The
container derives collapsibility from the count of *visible* views, not total
views (§spec:view-stack): hiding all but one visible view makes that lone
pane non-collapsible (or merged under `mergeSingleView`), exactly as a
single-view container behaves. There is **no** rule forcing one view to stay
visible — matching canon, hiding every view yields an empty container; the
title row and its overflow persist so the user can re-show a view
(§spec:structural-primitives `WorkbenchEmptyState` covers the empty body).

**The Views submenu is shell-built; host extras reuse existing patterns.**
Unlike the View *menu bar*, whose entry tree the host supplies
(§spec:menu-model), the Views submenu is generated by the shell — the shell
owns the stack and is the only party that knows the views, so it owns the
canonical toggles rather than asking each host to rebuild them and drift. A
host may still contribute container-title affordances through the patterns
already specced: inline title actions as a `List<Widget>` mirroring
§spec:section-header-actions, and additional overflow entries as
`List<WorkbenchMenuEntry>` mirroring §spec:menu-model, rendered above or
below the shell's Views group. The deliverable's core is the Views submenu;
host extras are the optional, canon-aligned extension.

**The overflow menu is an in-window popup, so checkmarks always render.** The
`⋯` button opens a Material popup (Flutter `MenuAnchor` /`SubmenuButton` /
`CheckboxMenuButton`) — the same in-window rendering §spec:menu-model already
defines. Because this surface is never the macOS system menu bar, the
`PlatformMenuItem` checkmark limitation (§spec:menu-model's "✓ "
degradation) does not apply: the Views checkboxes draw native check state on
every platform. The `⋯` glyph comes from `material_symbols_icons`
(`more_horiz`), the icon-source precedent §spec:section-disclosure sets for
shell chrome.

**Why this is chrome, not a form control**: the overflow button, the popup,
and the Views toggles are shell-owned canonical chrome — the shell renders
and drives them, like the disclosure twisty (§spec:section-disclosure), and
reuses the menu surface it already owns (§spec:menu-model). No control
Flutter ships is duplicated, so §spec:form-controls-excluded is not engaged.

**The overflow button is persistent, not hover-gated.** Pane-header actions
hide until the header is hovered or focused (§spec:section-header-actions)
because they hang off a per-pane header; the container title is persistent
chrome that always carries at least the Views submenu, so its `⋯` button is
always visible — matching VS Code's always-shown composite title toolbar.

**Rejected alternatives**:

- *Host-supplied overflow tree only, no shell-built Views submenu.* Rejected:
  the shell owns view membership; pushing the canonical toggles to the host
  re-invites the per-host drift the shell exists to remove
  (§spec:problem-statement) and duplicates knowledge the shell already holds.
- *Model visibility as collapse.* Rejected: collapse keeps the header and
  frees body height (§spec:section-disclosure); hidden removes the pane.
  Conflating them loses the hidden state and breaks the visible-view-count
  collapsibility derivation.
- *Right-click context menu only, no `⋯` button.* VS Code offers both; the
  button is the discoverable affordance. Opening the same menu on title
  right-click (VS Code `MenuId.ViewContainerTitleContext`) is consistent but
  secondary — the `⋯` button is the deliverable.

**Observable behavior**:

- The composite title reads `WorkbenchViewContainerSpec.title` when the spec
  sets it, otherwise the active container's activity-bar item label — so a
  secondary side bar container, which has no activity item, still shows a title
  when the host sets `title` and no longer renders a blank strip.
- The container title row shows a right-aligned `⋯` button whenever the
  container has at least one hideable view (or host-supplied overflow
  entries); activating it opens a popup whose Views submenu lists every view
  with a checkbox reflecting its visibility.
- Toggling a Views item shows or hides that view's pane; a hidden pane leaves
  the stack and its freed height redistributes to the visible panes
  (§spec:view-stack), and re-showing it restores its position in `order`.
- A view with `canHide` false shows no enabled toggle and cannot be hidden.
- Hiding views until one remains makes that pane non-collapsible or merged
  per the single-view rule (§spec:view-stack); hiding all yields an empty
  container body with the title and overflow still present.
- Hiding or showing a view, then switching containers and back, leaves the
  change intact (§spec:view-container-state); a host supplying `visible` +
  `onVisibleChanged` owns the state for cross-restart persistence.

---

## View Pane Header Actions §spec:section-header-actions

*Status: complete*

A `WorkbenchViewPane` renders host-supplied `actions` (a `List<Widget>`)
in its header's rightmost zone — hidden until the header is hovered or
focused, shown only while the pane is expanded. This is the VS Code
pane-header convention: refresh, add, and collapse sit beside the title,
appear on hover, and vanish when the pane collapses.

**Problem**: the pane header carried only the title and an optional
`infoTooltip` icon. A host's sole content insertion point was the body,
which renders beneath the header, so a pane action landed on its own row
instead of inline with the title — and a host could not reproduce VS
Code's hover-revealed, collapse-aware toolbar at all. Pane headers across
consuming apps then drift from the IDE-canonical layout the shell exists
to guarantee (§spec:problem-statement).

**Why this is chrome, not a form control**: the slot *places and reveals*
host-supplied widgets within a shell-owned header row; it does not
reimplement a control Flutter ships. The shell owns header layout the
same way `WorkbenchTabbedPanel` owns its close button (§spec:tabbed-panel).
The host supplies the action widgets and themes them against
`WorkbenchTheme`, so §spec:form-controls-excluded is not engaged — no
control is duplicated.

**Visibility is one contractual rule, not two**: actions appear when the
header is hovered or focused **and** the pane is expanded; collapsing the
pane hides them entirely. VS Code gates both with a single compound rule
(`.pane-header.expanded:hover .actions`), so hover-reveal and
hide-on-collapse are inseparable. A per-pane *always-visible* mode
(`actionsAlwaysVisible`) pins the actions on regardless of hover/focus,
still only while expanded (VS Code's `ViewPaneShowActions.Always`).
Reveal gates the same way on a non-collapsible pane — there is no
collapsed state to hide on, so hover/focus alone governs.

**Header layout order**: twisty (when collapsible, §spec:section-disclosure)
→ title → `infoTooltip` icon (the shell's analog of VS Code's dimmed
`.description` metadata) → actions (rightmost). Metadata hugs the title;
operations hug the right edge; each action's vertical center matches the
title's.

**The shell places actions raw, without a size constraint**: the header
row grows to the tallest action. Clamping action height to the
pane-header canon (§spec:layout-constants) would impose geometry on
host-owned controls — the shell owns *placement and visibility*, not
control *sizing* (§spec:form-controls-excluded). A host wanting VS Code
action density supplies compact widgets; a stock `IconButton` yields a
taller row.

**Why `List<Widget>`, not a typed action descriptor**: a typed descriptor
would require the shell to define an action-button control, which
§spec:form-controls-excluded keeps in the host. `List<Widget>` lets the
host pass any themed control while the shell owns placement and
visibility.

**Observable behavior**:

- Actions are hidden until the header is hovered or focused, and only
  while the pane is expanded; collapsing hides them entirely. An empty
  `actions` list renders the header exactly as before.
- An `actionsAlwaysVisible` pane shows its actions without hover or
  focus, while expanded.
- Actions render in the rightmost zone, after the title and optional
  `infoTooltip`, in the order supplied.
- Activating an action runs it and does not toggle the pane
  (§spec:section-disclosure).

---

## View Pane Disclosure §spec:section-disclosure

*Status: complete*

A `WorkbenchViewPane` collapses to its header, hiding its body, and
expands again — the VS Code pane affordance that lets a user manage a
stacked container's vertical space (§spec:view-stack). The shell owns the
twistie chevron, the toggle gesture, and the expanded/collapsed state.

**Collapsibility is container-derived, not a host flag**: the pane takes
no public `collapsible` parameter. Its `WorkbenchViewContainer` derives
collapsibility from view count (§spec:view-stack) — multiple views
collapsible, a single view non-collapsible or merged — and sets it
through the library-internal `WorkbenchViewPane.inContainer` seam, so
which panes can collapse is canon the shell enforces, not a host choice
(§spec:capability-boundary). The default public constructor renders a
non-collapsible pane (body always shown). Disclosure pays off in the
stack: collapsing one of several stacked panes redistributes its height
to its expanded siblings (§spec:view-stack).

**Why disclosure is shell-owned, not a widget slot**: the chevron glyph,
its orientation, the toggle gesture, and the expanded/collapsed state are
canonical chrome. Per §spec:capability-boundary the shell owns the
renderable and behavior as typed parameters rather than a `Widget` escape
hatch. This is the inverse of `actions`: actions are host-owned content
the shell only places and reveals (§spec:section-header-actions);
disclosure is shell-owned chrome the shell renders and drives. There is
one pane type, not a separate collapsible primitive — VS Code's view pane
is itself the collapsible unit; a second type would duplicate the header
layout.

**Controlled and uncontrolled, mirroring §spec:workbench-layout**: an
uncontrolled pane seeds `initiallyExpanded` and holds the state itself
(the `ExpansionTile` pattern); a controlled pane reflects the host's
`expanded` value and reports each requested toggle via
`onExpandedChanged`. The internal state is the UI-state category
§spec:capability-boundary permits (the `TabController` precedent), not a
domain type. Backing uncontrolled mode makes the pane stateful — the only
way to offer the convenience without forcing every host to manage a bool.

**Header gesture and its interaction with actions**: on a collapsible
pane the header is the toggle target; activating the title or metadata
region toggles the pane. The `actions` zone is carved out — activating an
action runs it and does not toggle the pane, matching VS Code, whose
header toolbar stops the toggle from firing.

**Canonical rendering**: the chevron leads the collapsible header (twisty
→ title → metadata → actions), drawn from `material_symbols_icons` with
orientation reflecting state. The twisty's space is reserved even when a
pane is non-collapsible — VS Code always renders the twisty container, so
a non-collapsible pane shows no chevron but keeps the indent and its title
aligns with the collapsible panes' titles rather than re-justifying into
the chevron's place. The header exposes Flutter `Semantics(expanded: …)`;
its focus ring and keyboard operation are §spec:view-pane-focus.
Body-transition animation is an implementation choice; the contract is body
visibility, not motion.

**Observable behavior**:

- Collapsibility is set by the container (§spec:view-stack); a
  non-collapsible pane renders its body unconditionally with no chevron.
- A collapsible header shows a leading twistie whose orientation reflects
  expanded vs collapsed and stays visible in both states.
- Pointer activation of the header toggles the pane; collapse hides the
  body and frees its height to expanded siblings (§spec:view-stack).
  Keyboard operation and the focus affordance are §spec:view-pane-focus.
- Activating a widget in the `actions` zone runs it without toggling.
- Uncontrolled panes hold their own expansion seeded by the host's
  initial value; controlled panes follow the host value and report every
  toggle.
- A collapsible header exposes an expanded/collapsed accessibility state;
  §spec:view-pane-focus makes it focusable and keyboard-operable.

---

## View Pane Header Focus and Keyboard Navigation §spec:view-pane-focus

*Status: complete*

A view-pane header is focusable, paints a focus ring while focused, and
drives the pane's disclosure (§spec:section-disclosure) and the stack's
header focus traversal from the keyboard — VS Code's `PaneView`/`Pane`
keyboard model. The shell owns the focus affordance and the key bindings.

**Problem**: the header renders a disclosure twistie and toggles on a
pointer tap, but the keyboard path is hollow. The collapsible header is a
bare focus stop reachable only by Tab, paints no focus ring, and a click
leaves no visible focus; a non-collapsible header is not focusable at all
unless it carries actions. Nothing collapses or expands a focused pane from
the arrow keys, and nothing moves focus between the stacked headers. A
keyboard or screen-reader user cannot operate the sidebar the way VS Code's
is operated — §spec:section-disclosure asserts the header is
"keyboard-operable," but no focus affordance makes that reachable.

**The header is a focusable control with a visible focus ring**: every
view-pane header — collapsible or not — is a single focus stop that takes
focus from a pointer click as well as from keyboard traversal, and paints a
focus ring while focused. Clicking a collapsible header both focuses it and
toggles the pane; clicking a non-collapsible header focuses it. The ring is
the `WorkbenchTheme.focusBorder` accent (VS Code's `focusBorder`), reusing
the token the rest of the chrome already uses rather than minting a new one.
A non-collapsible header is still focusable — so traversal can land on it
and its actions reveal on focus (§spec:section-header-actions) — even though
it has no disclosure state to toggle.

**Why click focuses, matching VS Code**: VS Code's pane header is
`tabindex="0"`, `role="button"`, and a focus tracker paints the focused
outline; a click focuses it. Without click-to-focus the keyboard model is
undiscoverable for pointer users — they would have to Tab in from elsewhere
to find it. Focusing on click makes the arrow-key vocabulary reachable:
click a header, then drive the stack from the keyboard.

**Focus clears on a tap outside the header**: a pointer tap on any surface
that is not the header — a pane body, another header, the editor, the
activity bar — removes the header's focus ring, matching how the web blurs
the active control when a non-focusable surface is clicked. Flutter instead
retains focus until another control claims it, so the shell drops it
explicitly; without this the ring lingers on a header the user has visibly
left.

**Per-pane keys act on the focused pane** — §spec:section-disclosure owns
the expand/collapse meaning; this section owns the bindings, which mirror VS
Code's `Pane` keydown handler (Enter/Space toggle, Left collapse, Right
expand). They are no-ops on a non-collapsible header, which has no disclosure
state.

**Up/Down move focus between headers** — a container concern over the stack
(§spec:view-stack), matching VS Code's `PaneView.focusNext`/`focusPrevious`.
Traversal is over the headers only and does not descend into pane bodies,
which are host content with their own focus order (§spec:scope). Focus clamps
at the ends — no wrap — and engages only with two or more panes.

**Why a dedicated section, not folded into disclosure**: disclosure
(§spec:section-disclosure) owns one pane's expand/collapse meaning and
state; this capability is the focus model and keyboard vocabulary that spans
the whole stack — click-to-focus, a focus ring, per-pane keys, and
inter-header navigation that is a container concern, not a pane one. Keeping
it as one section makes "operate the view stack by keyboard" a single
coherent slice with its own rationale, rather than scattering the focus ring
and per-pane keys into disclosure while Up/Down lands in the view-stack
section.

**Observable behavior**:

- Every view-pane header is a single focus stop that paints a focus ring
  (the `focusBorder` accent) while focused; a pointer click focuses the
  header, and on a collapsible header also toggles the pane.
- A pointer tap outside a focused header — a pane body, another header, or
  any surface beyond the stack — clears its focus ring; focus does not linger
  where the user is no longer interacting.
- On a focused collapsible header: Enter/Space toggle, Left collapses, and
  Right expands the pane; the same keys are no-ops on a focused
  non-collapsible header.
- Down moves focus to the next pane header in the container and Up to the
  previous; header traversal clamps at the ends, engages only with two or
  more panes, and does not descend into pane bodies.
- The header is reachable and fully operable by keyboard alone, carrying the
  expanded/collapsed accessibility state from §spec:section-disclosure — a
  mouse-only disclosure control is not canon-complete.

## Chrome Widgets §spec:chrome-widgets

*Status: complete*

### WorkbenchLayout §spec:workbench-layout

`WorkbenchLayout` composes activity bar + sidebar + editor +
bottom panel + status bar. Each activity-bar selection is a view
container: the host supplies a `WorkbenchViewContainerSpec` (typed view
descriptors, §spec:view-stack) per container through `containerBuilder`,
not a sidebar-body widget. The shell renders the spec through a
`WorkbenchViewContainer`. View-container navigation is controlled or
uncontrolled: the host may drive it with `activeViewContainerId` +
`onViewContainerChanged` (for example, a bottom-panel action that
switches sidebars), or omit both and let the shell track the active
container internally, seeded by `initialViewContainerId`. Reselecting the
active container toggles sidebar visibility.

**Resize seams share one canonical sash.** The sidebar-width, the
bottom-panel-height, and the view-stack pane boundaries
(§spec:view-stack) all resize through one internal sash primitive, so
every seam behaves identically: the drag tracks the pointer's *absolute*
position from where it began (overshooting a clamp parks the sash at the
limit and it re-tracks without offset); the cursor is bidirectional while
the sash can move both ways and a single-direction arrow at each limit
(matching VS Code's `ew-resize`/`ns-resize` and `minimum`/`maximum`
cursors); and the sash paints a two-level highlight — a centered band of
the canonical hover size in `WorkbenchTheme.sashHoverBorder` (VS Code's
`sash.hoverBorder`), a subtler tint on hover and the full color while
dragging. The sash owns its hit-target thickness and band size
(§spec:layout-constants — VS Code's `--vscode-sash-size` /
`--vscode-sash-hover-size`), so no call site picks an arbitrary width and
all three seams render identically. At rest the sash paints nothing: it
overlays the boundary (rather than occupying a strip of layout), so each
seam's visible line is the neighbor's own border (`sideBar.border`,
`panel.border`), and the highlight band appears only on hover/drag —
matching VS Code, whose `.monaco-sash` is transparent until
`:hover`/`.active`.

**Double-click resets a seam to its default.** Double-clicking any sash
restores the seam it controls — VS Code wires this on the base `Sash`
(`onDidReset`), so it is universal across the workbench, not a per-seam
extra. The shell mirrors it via `WorkbenchSash.onReset`. The *gesture* is
uniform; the *reset action* is a property of the seam, matching VS Code's
divergent per-consumer semantics:

- **Sidebar width, panel height** reset to their default size
  (`WorkbenchLayoutConstants.sidebarDefaultWidth` / `panelDefaultHeight`).
  VS Code resets a part sash to the part's *preferred* size (`Grid.onDidSashReset`
  → `preferredWidth`/`preferredHeight`); the shell has no content-derived
  preferred size, so the fixed default is the faithful stand-in.
- **View-pane sashes** (§spec:view-stack) reset to an *even* distribution of
  body height between the two adjacent expanded panes, matching VS Code's
  `ViewPaneContainer` sash-reset (split the combined space equally).
- **Centered-layout margins** (§spec:editing-modes) reset to the golden-ratio
  default.

All four seams honor the gesture: the centered-layout margins, the sidebar
width, the panel height, and the view-pane sashes. A sidebar/panel reset
commits the default through the same `…ChangeEnd` seam a drag uses, so the host
persists it; a view-pane reset commits the evened sizing map through
`onSizesChangeEnd`. The reset is detected from raw pointer-down timing rather
than a double-tap recognizer, so it never joins the drag's gesture arena —
dragging stays live from the first frame, and a stationary click (not a resize)
commits nothing.

**Sidebar width and panel height are host-persistable via seed-plus-commit**,
like the view-stack pane sizes (§spec:resize-geometry). Each is shell-owned:
`initialSidebarWidth` / `initialPanelHeight` seed it once at startup (falling
back to `sidebarDefaultWidth` / `panelDefaultHeight`, §spec:layout-constants),
and `onSidebarWidthChangeEnd` / `onPanelHeightChangeEnd` fire once on drag-end
with the final clamped value. There is no controlled width or height property
and no per-frame callback, so a host persists one write per drag with no
debounce of its own.

### WorkbenchTabbedPanel and WorkbenchPanelTab §spec:tabbed-panel

`WorkbenchTabbedPanel` and `WorkbenchPanelTab` own the bottom
panel's `TabController`, scrollable tab strip, close button,
header spacing, and panel background. Hosts pass an ordered list
of tab descriptors (stable id, natural-case `String` label,
optional `PanelTabBadge`, content builder), an `initialTabId`, an
`onTogglePanel` callback for the close button, and optional
`onActiveTabChanged` / `onRegisterFocusTab` hooks so the View menu
and keyboard shortcuts can drive tab focus through the same
controller. `WorkbenchTheme` carries the tab strip tokens
(`panelBackground`, `tabBarLabelColor`, `tabBarUnselectedLabelColor`,
`tabBarIndicatorColor`, `tabBarDividerColor`), so hosts no longer
patch `Theme.of(context).copyWith(tabBarTheme: …)` around the
primitive.

**Canonical tab strip rendering**. Per §spec:capability-boundary enforcement, the tab
strip is text-only and labels render uppercase. The shell applies
both invariants in its rendering — consumers pass `String` labels
in natural case (`'Output'`, `'Debug Console'`) and the shell
renders `'OUTPUT'`, `'DEBUG CONSOLE'`. Consumers needing the VS
Code "Problems (3)" pattern supply a typed `PanelTabBadge` (count
only) which the shell renders inline next to the uppercased label,
painting the pill in VS Code's generic badge accent
(`badge.background` / `badge.foreground`) — a separate slot from
the panel-active underline. The badge does not vary by severity:
a multi-severity collection (e.g. a task list mixing error /
warning / info) has no obvious "summary severity" to project
(highest? most populous?), so the count stands on its own.

### Status Bar §spec:status-bar

`WorkbenchStatusBar`, `WorkbenchStatusBarItem`,
`WorkbenchStatusBarAction`, and `WorkbenchStatusBarProblemsItem`
own the status-bar container, height, padding, and leading/
trailing alignment. Applications populate items with domain data.

`WorkbenchStatusBarProblemsItem` is the VS Code "Problems"
indicator: three counts (error, warning, info) rendered with
role-coloured icons and a single tap target that the host binds
to open whatever bottom-panel tab holds the underlying
diagnostics. Counts, colours, spacing, and typography all come
from `WorkbenchTheme` — the host supplies only the three integers
and the tap callback.

**Why a distinct primitive rather than three
`WorkbenchStatusBarItem`s**: a composite Row of three items would
work, but every host would duplicate the count-to-visibility
logic (hide zero counts, style the dominant severity, share one
tap target). Packaging the composite in the shell makes the
right behaviour free and matches VS Code's own implementation,
where the Problems indicator is a single registered status-bar
item.

**Why not a panel-visibility toggle in the status bar**: panel
toggles belong to the View menu, not the status bar, which
separates "current state readout" from "navigation affordance."

### WorkbenchMenuBar §spec:menu-bar

`WorkbenchMenuBar` owns a top-level View menu and the standard
app/Window menus that frame it. The View menu renders the
host-supplied `entries` tree of `WorkbenchMenuEntry` descriptors
(§spec:menu-model) — commands, submenus, separators, and
checkable/radio items. Each command-bearing entry carries an
arbitrary `Intent` the host defines; the menu item dispatches
that intent via `Actions.maybeInvoke`. The shell publishes one
default intent, `ToggleBottomPanelIntent` (§spec:action-dispatch),
bound to Cmd/Ctrl+J by `WorkbenchShortcuts`; a host that wants a
menu affordance for it adds a Panel entry to the tree.
`WorkbenchMenuBar` itself takes no callback props.

**Platform menu rendering**:

- **macOS**: installs Flutter's `PlatformMenuBar`, which binds to
  `NSMenu` and renders View in the system menu bar at the top of
  the screen. Standard app, Window, and Help submenus are
  populated from `PlatformProvidedMenuItem` defaults so Quit,
  Hide, Services, Minimize, Zoom, and Toggle Full Screen behave
  natively. Accelerators appear in the system menu bar and are
  indexed by Help search.
- **Windows and Linux**: renders a Material `MenuBar` strip
  anchored to the top of the workbench, above the activity bar.
  The standard OS title bar with min/max/close controls remains
  intact above the strip. Keyboard bindings still fire through
  `WorkbenchShortcuts`, independent of menu surface.

**Why no native menu surface on Windows or Linux**: Flutter's
`PlatformMenuBar` is macOS-only. No first-party plugin exposes
Win32 `SetMenu` or GTK `MenuBar` from Dart. Win32 `SetMenu`
produces the legacy MFC-style gray menu bar that no modern
desktop application uses — Office, browsers, and IDEs all moved
away from it — so exposing Flutter's Material `MenuBar` through
it would still look out of place. GTK `MenuBar` is similarly out
of fashion on modern GNOME, which prefers a hamburger button in
the `HeaderBar`, but Flutter Linux's `HeaderBar` integration is
owned by the embedder and exposes no menu-button slot for Dart
code. Embedder work to host a Dart-defined menu in the GTK
`HeaderBar` exceeds the value of doing so.

**Why the menu lives below the OS title bar**: the shell does not
take over the window frame, so the View menu needs a home that is
predictable and platform-appropriate without one. The in-window
`MenuBar` strip below the standard OS title bar achieves this; VS
Code supports the same layout via `window.titleBarStyle:
"native"`. The custom-title-bar alternative
(`window.titleBarStyle: "custom"`), which would merge the menu and
window controls into one shell-drawn strip, is a deferred shape
documented in §spec:custom-window-chrome — not a flat exclusion.

**Tradeoffs accepted**: the in-window menu strip on Windows and
Linux costs one row of vertical space below the OS title bar
that VS Code's custom-titlebar mode would reclaim. This is
acceptable given the complexity savings and the absence of any
first-party Flutter API that would let us recover the space
without taking over the window frame. If a future Flutter
release exposes native menu surfaces on Windows or Linux,
`WorkbenchMenuBar` can switch render paths without changes to
the descriptor model — the `WorkbenchMenuEntry` tree
(§spec:menu-model) is platform-agnostic.

**Menu bar theming**: the Windows/Linux strip resolves its
background, foreground, hover, and border colours from
`WorkbenchTheme` (`menuBarBackground`, `menuBarForeground`,
`menuBarHoverBackground`, `menuBarBorder`) rather than the
ambient `Theme.of(context)` defaults, so the strip reads as
workbench chrome rather than a generic Material surface. Custom
window-frame takeover (merging the menu bar into a shell-drawn
title bar) is deferred, not flatly excluded; its shape and
promotion gate live in §spec:custom-window-chrome.

### WorkbenchShortcuts §spec:shortcuts

`WorkbenchShortcuts` installs the one keyboard binding every
workbench ships: Cmd+J and Ctrl+J both dispatch
`ToggleBottomPanelIntent` through Flutter's `Shortcuts`/`Actions`
pair (§spec:action-dispatch). Both activators are registered so the same intent
fires regardless of the platform the user is on; the macOS system
menu bar renders the Cmd glyph separately via
`WorkbenchMenuBar`'s `PlatformMenuItem` shortcut hint.

`WorkbenchShortcuts` takes no callback props. Host-specific
shortcuts — a tab-focus vocabulary, a command palette, etc. —
pass through `extraShortcuts`, which the host defines with its
own intent types, or install via a surrounding `Shortcuts`
widget. The shell deliberately does not ship any tab-focus
bindings: which tabs exist is a host concern, so the host owns
both the intents and their activators.

### Action Dispatch §spec:action-dispatch

*Status: complete*

Menu entries (§spec:menu-bar) and keyboard shortcuts (§spec:shortcuts) dispatch
through Flutter's `Actions`/`Intent` machinery. The shell
publishes exactly one public intent: `ToggleBottomPanelIntent`.
Every other command is host-defined — each command-bearing
`WorkbenchMenuEntry` (§spec:menu-model) carries an arbitrary
`Intent`, and hosts install their own `Shortcuts` bindings for
host-specific activators. Hosts register `Action<Intent>`
handlers at the widget that owns the target state.

**Why Intents rather than callbacks**. Callbacks couple the
surface widget (menu or shortcut receiver) to the target owner
through every intermediate widget. Each new command doubles the
prop surface. Intents invert that: the surface announces *what
the user asked for* and whichever ancestor owns the target
responds. The pattern matches Cocoa's target/action responder
chain — the same mental model VS Code users carry from the OS
menu bar.

**Why the shell publishes only one intent**. Shipping a
pre-baked vocabulary (`FocusMdiIntent`, `FocusTasksIntent`, …)
would bake host-specific command names into a reusable package.
Hosts with different panel layouts would either import intents
they don't use or define their own anyway. `WorkbenchViewMenuTab`
taking an arbitrary `Intent` lets each host express its own
vocabulary with compile-time type safety; the shell stays
agnostic. `ToggleBottomPanelIntent` is the one exception — the
bottom-panel toggle is universal enough to warrant a named
intent so the Cmd+J binding can be installed in the shell.

**Why public intent types**. `Actions` keys on `Type`; the
host's `Action<Intent>` declaration names the intent at compile
time. Private intents cannot satisfy this — any intent a menu
item or shortcut dispatches shall be declared publicly either by
the shell or by the host.

**Enable state**. Menu items render with a null `onPressed` (the
Material disabled-chrome trigger, or a null `onSelected` on the
native macOS `PlatformMenuItem`) when the host's registered
action reports `isEnabled(intent) == false`. Each item
subscribes to its action via `Action.addActionListener` and
re-renders locally when the action calls `notifyActionListeners`.
Hosts that do not override `isEnabled` default to always-enabled.
Keyboard shortcuts stay always-fireable — disabled state is a
menu chrome concern, not a shortcut concern.

**Rejected alternative — command registry with string ids**. A
`WorkbenchCommandRegistry` keyed by string ids
(`'workbench.togglePanel'`) would decouple menu and shortcut
from target and layer cleanly under a future command palette.
The string-keyed indirection loses compile-time checking on
payload shapes and pushes command registration into a separate
lifecycle step. `Actions`/`Intent` is Flutter's built-in
primitive for this exact use case; a registry can layer on top
if a palette workstream lands.

**Rejected alternative — `InheritedWidget` for target state**.
An `InheritedWidget` that exposes the panel controller to
descendants would let menu widgets call controller methods
directly. That flattens control flow and couples every menu
item to the controller type; `Actions` keeps dispatch
unidirectional and lets tests pump a tree with a single
synthetic `Action` registration.

**Rejected alternative — shell-defined per-tab focus intents**.
An earlier draft had the shell publish `FocusMdiIntent`,
`FocusTasksIntent`, etc. and default-shortcut bindings for each.
Dropped: the shell cannot know what tabs a host runs, so any
fixed vocabulary is either useless to other hosts or forces them
to adopt another host's layout. Each host defines its own intents
(for example `FocusBottomPanelTabIntent(MyTabId tab)`) and installs
its own `Shortcuts` map around the shell.

**Scope**. Covers the View menu + Cmd/Ctrl+J. Notification-center
dispatch (§spec:notification-center) is out of scope — that section defines its own
intents. Host-defined shortcuts continue to pass through
`extraShortcuts` or a surrounding `Shortcuts` widget.

### Bottom Panel Lifecycle §spec:panel-lifecycle

*Status: complete*

`WorkbenchPanel` is the single declaration for one bottom-panel
tab; `WorkbenchPanelHost` consumes an ordered list of them and
derives the View menu (§spec:menu-bar), keyboard-shortcut map, tab strip
(§spec:tabbed-panel), and per-panel `PanelLifecycle` instances. Consumers
declare panels once; the shell keeps the four surfaces consistent
by construction.

**Why a descriptor class rather than a subclass base**. Two
shapes were considered:

1. `abstract class WorkbenchPanel` with subclasses per panel,
   lifecycle as virtual methods (`onFocused()` / `onBlurred()`).
2. Immutable `WorkbenchPanel` data class, lifecycle via a
   listenable the content subscribes to.

The subclass shape reads naturally in OO terms but forces every
panel into its own class even when the content is a single
widget, and puts per-panel state in the descriptor (which the
shell needs to treat as shallow/immutable for rebuilds to be
cheap). Lifecycle as virtual methods couples the panel object
to the shell's tree lifecycle, which is awkward to test and
harder to compose with widgets that prefer push-based
observability. The descriptor-plus-listenable shape matches
Flutter conventions — `Theme`, `MediaQuery`, `Focus`, and
`FocusNode` all expose state through listenables or inherited
widgets rather than lifecycle methods on descriptors.

**Why opaque `Object` id rather than generic `WorkbenchPanel<T>`**.
A generic id type propagates the type parameter to
`WorkbenchPanelHost<T>`, to every menu descriptor, and to every
`Action<FocusPanelTabIntent<T>>` the host registers. The
compile-time safety is real but the boilerplate cost is large
and the runtime risk low — the only operation on a panel id is
equality, and enum values compare by identity. Consumers who
want type-safe access at callsites cast once in their action
handler (`intent.tabId as BottomPanelTabIds`) and switch
exhaustively from there.

**Why `label` is `String`, not `Widget`**. VS Code's bottom panel
tab strip is canonically text-only — uppercase label, optional
inline numeric badge ("Problems (3)" pattern), no icons stacked
above text. A `Widget`-typed label leaves the canon to consumer
discipline and admits non-canonical surfaces by accident or
convenience. Pinning `label` to `String` and rendering the tab
internally removes the escape hatch at the type level. Count
badges go through a typed `PanelTabBadge` (count only); the
shell paints the pill in VS Code's generic badge accent
(`badge.background`), matching VS Code's treatment.
Badges that don't fit the count-only shape belong in the panel
content, not the tab strip.

**Why no imperative `WorkbenchPanelController`**. A controller
exposing `focusTab(id)` / `hide()` / `show()` would give host
code an imperative surface alongside the intent dispatch.
Intents are already the declarative surface
(`Actions.invoke(context, FocusPanelTabIntent(id))` does the
same thing), and adding a second surface doubles the API without
unique capability. The host exposes a one-shot
`onRegisterFocus(focusById)` callback so consumers can route
their own intents into the active-tab notifier from
`Action<Intent>` handlers. A full controller layers on
additively if a future use case requires drive-through outside
the `BuildContext` scope.

**Coexistence with §spec:tabbed-panel**. `WorkbenchTabbedPanel` and
`WorkbenchPanelTab` remain as the low-level tab-strip primitive.
`WorkbenchPanelHost` composes them internally. Consumers that
need a tab strip outside the shell's menu-integrated model
continue to use §spec:tabbed-panel directly. The §spec:tabbed-panel descriptor itself is
now `String`-labelled with the same `PanelTabBadge` field — the
canon-enforcement applies regardless of which entry point the
host uses.

**Observable behavior**. The active panel id persists across
`ToggleBottomPanelIntent` cycles (hide the panel, show it again,
the previously focused tab returns). `PanelLifecycle.isFocused`
publishes true exactly when the panel is visible AND its tab is
the active tab. Panels with `focusIntent: null` appear in the
tab strip but not the View menu — the shell does not synthesize
a default focus intent.

**Scope**. Bottom panel only. Sidebars (§spec:workbench-layout) compose
differently — single builder per activity-bar section, not a
tabbed stack — and do not need a parallel lifecycle abstraction.
Notification-center surfaces (§spec:notification-center) live outside the bottom-panel
model and do not participate in this contract.

---

## View Menu Item Model §spec:menu-model

*Status: complete*

The View menu (§spec:menu-bar) accepts a tree of `WorkbenchMenuEntry`
descriptors, not a flat list, so a host expresses VS Code's menu
structure — nested submenus and a checked/radio item marking the active
choice in a group — instead of mutating an entry's label to convey state.

**Model.** A `WorkbenchMenuEntry` is one of:

- `WorkbenchViewMenuTab` — a *command* leaf (label plus intent).
- `WorkbenchMenuCheckbox` — a *checkable* command carrying a `checked`
  bool.
- `WorkbenchMenuRadio` — a *radio* command carrying a `selected` bool;
  radio entries listed together in one submenu read as a
  mutually-exclusive set.
- `WorkbenchMenuSubmenu` — a *submenu* (label plus child entries).
- `WorkbenchMenuSeparator` — a divider between adjacent groups.

The `checked` / `selected` value is the host's, reported by the entry
and owned through the same controlled/uncontrolled seam as every other
property (§spec:layout-customization): the entry carries the current
state and the host updates it via the intent's `Action`. The descriptor
tree stays platform-agnostic.

**Why separate checkbox and radio types rather than one checkable with a
radio-group discriminator.** Each maps to a distinct Material widget
(`CheckboxMenuButton` vs `RadioMenuButton`), and the discriminated types
let the in-window path render the semantically correct control without
the host or shell special-casing a group flag. A radio item carries only
its own `selected` bool — no shared group value — because the host
already owns the mutual exclusion (one entry reports `selected` true).

**Checkmark rendering — the platform split.** True checkmarks render only
on the in-window Material path (`CheckboxMenuButton` / `RadioMenuButton`
/ `SubmenuButton`). Flutter's `PlatformMenuBar` (`PlatformMenuItem`)
exposes no checked field, so the macOS system menu bar cannot draw the
native checkmark gutter; a checked entry degrades to a leading "✓ " glyph
in the label — visible and non-mutating. Submenus need no degradation:
`PlatformMenu` nests natively everywhere.

**Why not abandon the native macOS menu for full fidelity.** A fully
canon menu — native checkmark gutter and submenus — is reachable only by
dropping `PlatformMenuBar` for an in-window Material menu on macOS too,
forfeiting the system menu bar at the top of the screen. The system menu
bar is the stronger macOS-native signal; trading it for a checkmark is
rejected. The "✓ " degradation is the accepted compromise until Flutter
exposes checked state on `PlatformMenuItem`, at which point the macOS
path adopts it with no model change.

---

## Form Controls Are Excluded §spec:form-controls-excluded

*Status: complete*

`workbench_shell` does **not** own form controls — text fields,
dropdowns, toggles, action buttons. Consuming applications keep
those in their own UI packages, themed against `WorkbenchTheme`
so theme switching still works but not exposed as reusable
primitives.

**The seam is stock-widget duplication, not widget ownership.** The
exclusion holds because every control VS Code uses has had a stock
Flutter equivalent the chrome themes in place
(§spec:chrome-material-theming); owning a `workbench_shell` widget
would only duplicate Flutter. The boundary is "do not reimplement a
control Flutter already ships," not "never own a control." A VS Code
control with **no** stock Flutter widget is the exception — theming
cannot reach it because there is nothing to theme — so it is a
legitimate shell-ownership candidate rather than an excluded
duplicate. `SplitButton` (VS Code's Commit and Run/Debug controls) is
the first such case; Flutter ships no split button. The set of VS Code
controls lacking a Flutter equivalent is expected to stay small — VS
Code's control vocabulary is conventional. Such a control still passes
the re-promotion gate below: until promoted it lives in the consuming
app, composed from the chrome-themed button family and reading
`WorkbenchTheme` tokens so theme switching still applies.

**Why form controls are not primitives yet**:

- *Single-consumer in practice.* Each form-control variant in
  the host this package was extracted from had one to three call
  sites. "Reusable primitive" is aspirational framing for what is
  currently a locally-extracted helper.
- *Not actually VS Code-coded.* VS Code's form controls have
  specific visual grammar: inset borders, hover fade timing,
  focus ring geometry, font sizing tied to `editor.fontSize`,
  plus context-menu and settings-editor variants. Ad-hoc
  "themed" helpers draw whatever colors happen to be in
  `WorkbenchTheme` today. They are "themed," not "VS Code-
  themed." Publishing them as "workbench primitives" promises a
  visual-language commitment the package has not made.
- *Premature-abstraction tax.* Primitives live in a
  publish-targeted package and therefore carry an API stability
  obligation unparented helpers do not. Paying that tax for
  helpers with one consumer each loses on both sides of the
  ledger.

**Re-promotion gate**: a form control earns a place in
`workbench_shell` when either (a) it has at least one
demonstrated reuse consumer outside the package that motivated
it, or (b) the package commits to a VS Code-aligned component
set with explicit visual specifications, at which point the
primitives are designed against that spec rather than extracted
from ad-hoc usage.

**Observable behavior**: form controls within sections may
differ in styling across consuming apps until the re-promotion
gate is met. That variance is explicitly tolerated over the
cost of a publish-grade primitive surface that does not yet
warrant one.

---

## Workbench Layout Customization §spec:layout-customization

*Status: complete*

§spec:workbench-layout composes a fixed arrangement: activity bar and
primary side bar on the left, bottom panel under the editor, status bar
below. VS Code's "Customize Layout" exposes these as user choices — which
side the primary side bar takes, a second side bar on the opposite edge,
how the bottom panel aligns across the width, and distraction-free /
centered editing. A workbench that hardcodes one arrangement asks every
host to either accept that arrangement or fork the layout. This section
makes the arrangement a set of host-driven choices.

**Scope boundary — what the shell owns.** The shell owns chrome that
lives *below* the OS window frame (§spec:custom-window-chrome). Full
Screen toggles the OS window and therefore belongs to the host, which
owns the window; the shell does not expose it. The shell owns primary side-bar
visibility, status-bar visibility, side-bar position, the secondary side
bar, panel alignment, Zen mode, and centered layout — all expressible
within the region the shell already renders. This is why "Full Screen" from VS Code's panel is absent here:
it is not the shell's to give.

**One mechanism: controlled/uncontrolled, mirroring §spec:workbench-layout.**
Every choice below is a host-configurable property following the pattern
the active view container already uses: an `initial…` seed for
uncontrolled mode, or a controlled value plus an `on…Changed` callback
through which the host owns and persists the state. The shell holds no
persistence of its own. A host that wires the callbacks to its settings
store gets layout that survives restarts; a host that ignores them gets
session-local defaults. No new persistence subsystem is introduced —
the gap is closed by extending an established pattern, not inventing one.
This is the deliberate rejection of a data-driven layout-graph / "Part
registry" abstraction: with a handful of degrees of freedom, the choices
are enums consumed by conditional composition, not a layout engine. The
abstraction is reconsidered only if a later choice cannot be expressed by
the nesting rule §spec:panel-alignment defines.

### Primary Side Bar Visibility §spec:sidebar-visibility

The primary side bar shows or hides as a host-driven property, the same
controlled/uncontrolled seam as the choices above (`initialSidebarVisible`,
or `sidebarVisible` plus `onSidebarVisibilityChanged`). Hidden, the bar
yields its space to the editor; the activity bar stays so the user can
bring it back.

**Why a host property, not only the activity-bar tap.** The shell already
toggles the bar when the active activity-bar icon is tapped, but that
affordance is unreachable from a host menu item or keybinding (VS Code's
Cmd+B). So the shell raises `onSidebarVisibilityChanged` on its own tap
too — unlike the other layout toggles, which the host alone drives — and
a controlled host shall honor it to keep the activity-bar affordance
working. This is the one seam where the shell both originates and reports
a toggle.

### Status Bar Visibility §spec:status-bar-visibility

The status bar shows or hides as a host-driven property on the same
controlled/uncontrolled seam (`initialStatusBarVisible`, or
`statusBarVisible` plus `onStatusBarVisibilityChanged`). Hidden, it yields
its strip to the workbench above. The shell raises no toggle of its own —
the host drives it from a menu item (VS Code's "Status Bar" toggle, which
has no default keybinding). Zen mode hides the status bar wholesale
alongside all other chrome, independent of this property.

### Side Bar Position §spec:sidebar-position

The primary side bar (with its activity bar) sits on the left or the
right of the editor, host-selectable. The resize sash and the side
border follow the bar to whichever edge it occupies, so the
§spec:workbench-layout sash invariants hold unchanged on either side.
Moving the bar relocates its subtree to the opposite edge rather than
rebuilding it: the width, pane order, expansion, and sash sizes retained
per §spec:view-container-state survive the move, so the host need not
persist and restore them across a position change.

**Why an enum, not a boolean.** The position is named (`left` / `right`)
rather than `isOnRight` because the secondary side bar (§spec:secondary-sidebar)
derives its own edge from the primary's, and "the side opposite `left`"
reads where "the side opposite `false`" does not. The two bars never
share an edge; the secondary is always opposite the primary, matching VS
Code.

### Secondary Side Bar §spec:secondary-sidebar

A second side bar occupies the editor's opposite edge from the primary
(§spec:sidebar-position), independently visible and independently
resizable through the same canonical sash. It hosts view containers
through the same `containerBuilder`/`WorkbenchViewContainer` path the
primary uses, with its own controlled/uncontrolled active-container id,
visibility, and width. It has no activity bar of its own. Swapping the
primary's edge moves the secondary to the now-free opposite edge,
relocating its subtree rather than rebuilding it, so its retained pane
State and width survive the move (§spec:view-container-state, the
relocation rationale §spec:sidebar-position records).

**Why the host assigns containers, not drag-and-drop.** VS Code populates
its secondary side bar by dragging views between bars. View relocation by
drag is a separate capability with its own interaction surface; it is
explicitly out of scope here. In its place, the host decides which
containers a bar shows. The activity bar drives the primary side bar
only. This keeps the secondary bar a thin reuse of existing container
machinery rather than a new view-management system, and leaves
drag-to-relocate as a future, separable addition.

Because the secondary bar has no activity bar to name its container, the
host titles a secondary container through `WorkbenchViewContainerSpec.title`
(§spec:view-container-title); an untitled multi-view secondary container
renders a blank composite title.

### Panel Alignment §spec:panel-alignment

When the bottom panel is at the bottom, its horizontal extent is
host-selectable through the controlled/uncontrolled seam above
(`initialPanelAlignment`, or `panelAlignment` plus
`onPanelAlignmentChanged`): `center` spans the editor only (both side
bars run full height past it — the §spec:workbench-layout default),
`justify` spans the full width (neither side bar runs past it), `left`
abuts the left edge's side bar (which runs full height) and spans the
rest, and `right` mirrors `left`.

**Why re-parenting, not a layout solver.** Each alignment reduces to one
question per screen edge: does that edge's bar group run full height
(outside the panel's horizontal band) or stop at the panel's top (inside
it)? Center = both outside; justify = both inside; left/right = one of
each. The four values are therefore two booleans realized by *where the
panel sits in the widget tree*, not a constraint solver or a multi-child
layout delegate. This is the boundary case the §spec:layout-customization
"no layout engine" decision is tested against, and it holds: the four
alignments express cleanly as the per-edge nesting choice — bars marked
inside sit in the row above the panel so it spans beneath them, outside
bars are siblings of the panel's band column running full height — so no
layout-graph abstraction is warranted. Re-parenting preserves element
identity through the same GlobalKeys §spec:sidebar-position relies on, so
a host's retained pane and panel State survives an alignment change.

### Zen and Centered Layout §spec:editing-modes

`WorkbenchLayout` exposes two distraction-reducing modes as controlled/
uncontrolled properties (`zenMode`/`onZenModeChanged`/`initialZenMode`,
`centeredLayout`/`onCenteredLayoutChanged`/`initialCenteredLayout`),
following the §spec:layout-customization mechanism. Zen hides all chrome —
activity bar, both side bars, panel, status bar — leaving the editor.
Centered narrows the editor between two equal margins and centers it; chrome
remains. The margins default to the golden-ratio split
(`WorkbenchLayoutConstants.centeredLayoutMarginRatio` = `0.1909` per side, VS
Code `centeredViewLayout.ts` `defaultState`, editor ≈61.8%) and scale with the
window, so the effect is visible at any width rather than only past a fixed cap.
A hairline in `WorkbenchTheme.editorGroupBorder` (VS Code `editorGroup.border`)
runs down each inner edge, and the canonical sash overlays each. **Dragging
either sash resizes the editor symmetrically** — both edges move and the column
stays centered — and double-click resets to the default (VS Code
`onDidSashReset`). Below
`WorkbenchLayoutConstants.centeredLayoutMinEditorWidth` the column is too narrow
to center, so the editor fills it (VS Code's `centeredLayoutAutoResize`).

**Why symmetric drag, and one width not two margins.** VS Code's centered
SplitView sets `inverseAltBehavior`, so a plain (no-modifier) margin drag takes
the split's *symmetric* path: the dragged sash's partner resizes by the opposite
amount on the same frame, keeping the editor centered. The off-center asymmetric
drag is the Alt-modified escape hatch, dropped here as a deliberate
simplification. Because both margins stay equal, the shell models centered width
as a single margin value, not two. It is shell-owned state — like the active
container, tracked for the life of the layout; host persistence is deferred.

**Why proportional, not a fixed 900px cap.** VS Code's default centered mode is
proportional (the golden-ratio split), with the 900px `targetWidth` only the
seed for the opt-in fixed-width mode (`centeredLayoutFixedWidth`, which governs
constant width across *window resizes*, not drag symmetry). A fixed cap shows
nothing until the column exceeds it; the proportional default always margins the
editor, which is the behavior a host comparing against VS Code expects.

**Why independent toggles, not one enum.** VS Code treats them separately
and they compose: a centered editor renders inside an otherwise-bare Zen
workbench. The composition is a single editor subtree the shell renders
either bare (Zen) or amid chrome, capped or not (centered) — no
special-cased combination.

**Why these two and not "modes" generally.** Full Screen, the third VS
Code mode, is the OS window's (scope boundary above). Zen and centered
are the two that live entirely within the shell's region, so they are
the two the shell can own without crossing into host/window territory.

---

## Drag-Resize Geometry §spec:resize-geometry

*Status: complete*

**Problem**: the sidebar width, bottom-panel height, and view-stack pane sizes
(§spec:view-stack) shipped (0.15.0) as controlled/uncontrolled properties — a
controlled value plus a per-frame `on…Changed` callback. The callback fired
every drag frame (the canonical sash drives it from pointer-move,
§spec:workbench-layout), so a host persisting layout wrote ~60×/sec and
reimplemented a debounce — the boilerplate the shell exists to remove
(§spec:problem-statement). Controlled mode also modeled an interaction that does
not exist: driving resize geometry frame-by-frame, independent of the user's
drag. Reported in #68.

**Resize geometry is shell-owned, seeded at startup and committed on
drag-end.** The layout owns the live value; storage seeds it once and records
it on change, never per frame. Each value is internal state (there is no
controlled geometry property), takes an `initial…` seed, and fires one drag-end
callback:

- `WorkbenchLayout.initialSidebarWidth` + `onSidebarWidthChangeEnd`
- `WorkbenchLayout.initialPanelHeight` + `onPanelHeightChangeEnd`
- the view container's `initialSizes` + `onSizesChangeEnd`

Each `…ChangeEnd` fires once with the final clamped value (the full sizing map,
for the container) off the canonical sash's drag-end (`WorkbenchSash.onChangeEnd`,
VS Code's `Sash.onDidEnd`). A host persists on `…ChangeEnd` and seeds from
`initial…` — one write per drag, no debounce.

**Why no controlled geometry, unlike the rest of the layout.** The
controlled/uncontrolled pattern (§spec:layout-customization) fits state a host
drives programmatically — active view container, pane expansion, pane order —
each of which VS Code drives from outside user input. It does *not* drive resize
geometry that way: the Sash's per-frame `onDidChange` feeds VS Code's own
`SplitView` relayout, never an external store. Importing controlled mode for
drag geometry invents a non-canonical interaction (resizing without user input)
and is the source of the per-frame trap. Removing the controlled
`sidebarWidth`/`panelHeight`/`sizes` properties is breaking; taken pre-1.0 to
land the canonical shape before the API stabilizes. This supersedes the
controlled-`sizes`/`onSizesChanged` language in §spec:view-stack and
§spec:view-container-state for sizing; pane *order* and *expansion* keep their
controlled/uncontrolled contracts.

**Observable behavior**:

- Dragging the sidebar, panel, or a view-pane sash resizes the widget tree per
  frame with no host callback; the host is notified only on release.
- Each geometry exposes an `initial…` seed and a `…ChangeEnd` callback that
  fires once on drag-end with the final clamped value (or sizing map).
- No controlled per-frame geometry property exists; resize geometry changes only
  from a user drag or the startup seed.

---

## Custom Window Chrome Is Deferred §spec:custom-window-chrome

*Status: complete*

`workbench_shell` does **not** take over the OS window frame. On
every platform the host application keeps the standard title bar
with native min/max/close (or macOS traffic lights), and the shell
renders its chrome below that bar. VS Code's
`window.titleBarStyle: "custom"` — a shell-drawn title bar that
merges window controls, menu, and title into one strip and
reclaims the row the OS bar occupies — is recorded here as a
deferred shape, not a current capability.

**Why deferred, not rejected**: stock OS title bars are now the
minority for app-like software, so the custom look has product
value. But the cost is platform-fragmented (below) and the
shell's existing invariants constrain who can pay it. The decision
is "not now," with the shape recorded so a future promotion starts
from a design rather than a blank page.

**Why the shell cannot ship it turnkey**: §spec:capability-boundary
fixes `lib/`'s dependency footprint at Flutter, `equatable`,
`material_color_utilities`, and `material_symbols_icons`. Frame
takeover needs a desktop window plugin (e.g. `window_manager`),
`main()` initialization before `runApp`, and native runner edits
(`MainFlutterWindow.swift`, `main.cpp`, `my_application.cc`) — all
of which live in the consuming application, not a published widget
library. A self-contained "add custom chrome" package change is
therefore impossible without breaking the dependency invariant.

**The shape if promoted** — a host/shell split:

- *Shell owns* a typed title-bar widget that renders defined
  chrome (the window title per §spec:chrome-typography-canon, and
  on Windows/Linux shell-drawn min/max/close glyphs) themed from
  `WorkbenchTheme`, plus an abstract window-controller interface
  carrying drag/minimize/maximize/close intents. Per the
  canon-enforcement rule in §spec:capability-boundary the bar is
  **not** a host-fillable `Widget` slot — it renders canon chrome
  from typed inputs, like every other shell surface.
- *Host owns* the frame takeover: the plugin dependency, `main()`
  init, native runner configuration, and the concrete
  implementation of the controller interface. Mobile and web bind
  no implementation, so the contract is a no-op there and tablet
  builds are unaffected.

**Platform cost gradient** (why one flag will not cover it):

- *macOS* — cheapest. A full-size content view with a transparent
  title bar keeps the native traffic lights inset over shell
  content; the shell draws no window buttons and the menu stays in
  the system bar (§spec:menu-bar), so nothing conflicts. This is
  the only platform where custom chrome is close to free.
- *Windows* — the shell must draw its own min/max/close and handle
  `WM_NCHITTEST` for the Win11 snap-layouts hover. Reclaims the
  in-window `MenuBar` row that §spec:menu-bar lists as an accepted
  loss.
- *Linux* — most expensive. Flutter's embedder owns the GTK
  `HeaderBar`; going frameless makes the host responsible for
  resize borders, shadows, and Wayland edge cases.

**Promotion gate**: custom window chrome earns shell support when
(a) a consuming application demonstrates the macOS host wiring and
the shell title-bar widget against a real product surface, and (b)
the typed title-bar and controller contract is specified against
that working integration rather than designed in the abstract.
Until then the shell ships chrome below the OS bar on every
platform.

---

## Theming §spec:theming

*Status: complete*

The theme architecture splits along a single axis: **chrome vs
domain**. `workbench_shell` owns chrome via `WorkbenchTheme`.
Consuming applications own domain tokens (e.g. axis colors,
alarm severities) via their own `ThemeExtension` and bridge to
`WorkbenchTheme`'s `surfaceTone` for HCT tonal resolution when
contrast-safe colors are required against the chrome background.

**Reference integration**: the bundled example app
([`example/`](example/)) wires
`WorkbenchThemeController` end-to-end — a top-level
`AnimatedBuilder` rebuilds `MaterialApp.theme` when the active
theme changes, and a "Settings" sidebar exposes the bundled
theme list (`controller.availableThemes`) as a tap-to-select
picker. Selecting a theme swaps every chrome surface (tab strip,
status bar, sidebar headings, panel borders) in the same frame,
with no per-surface wiring on the consumer side. Pub.dev
consumers get the canonical pattern by reading
`example/lib/main.dart`.

**Why split by ownership, not by UI surface**: the useful
question is "who owns the semantic?" Chrome semantics belong to
the shell (a VS Code theme can set them without knowing the
host exists). Domain semantics belong to the host (no VS Code
theme defines "alarm red" or "X axis color"). Splitting by
ownership puts each token next to the code that defines and
consumes it, and makes theme switching a shell-level operation.

**Why `workbench_shell` owns theme switching**:
`WorkbenchThemeController` holds everything needed to swap
themes — JSON assets, parser, token map, active theme state.
Domain colors in the host adapt automatically via HCT tonal
resolution driven by `WorkbenchTheme.surfaceTone`.

### VS Code Theme Format §spec:vscode-theme-format

Color themes use the VS Code color theme JSON format: a `colors`
object mapping [VS Code workbench color
tokens](https://code.visualstudio.com/api/references/theme-color)
to hex values (`#RRGGBB` or `#RRGGBBAA`). The format is a de
facto standard with thousands of community themes available.

The package ships bundled themes as assets under
`assets/themes/` (Dark Modern, Light Modern, Dark (Visual
Studio), Light (Visual Studio)). Applications load their own
themes (or accept `.vsix` uploads) by passing JSON to
`WorkbenchThemeController`.

**Why VS Code theme format**: simple JSON, well-documented, and
backed by the largest theme ecosystem in existence. Adopting it
gives consumers access to thousands of themes without designing
a bespoke format or building a theme editor.

### HCT Tonal Resolution Contract §spec:hct-tonal-resolution

`WorkbenchTheme.surfaceTone` exposes the active theme's HCT
tone on the editor background. Consuming applications declare
their domain semantics as HCT tonal palettes
(`package:material_color_utilities`), fix a hue and chroma per
semantic, and resolve the concrete `Color` against
`surfaceTone`. On dark chrome the resolver returns a lighter
tone; on light chrome a darker tone. The contrast target is
fixed per semantic role (alarms target higher contrast than
passive indicators).

**Why HCT**: perceptually uniform tone shifts across hues.
`material_color_utilities` is Google-maintained and already a
transitive dependency of Flutter Material 3. The alternative —
hand-maintaining dark/light palettes per semantic — scales
poorly and invites drift.

**Why not APCA**: more principled but adds a dependency without
meaningfully improving non-text UI contrast. The system can
adopt APCA later by replacing the resolver's tone selection
without changing the domain token shape or call sites.

**Observable behavior**: swapping the active VS Code theme
updates every chrome widget through `WorkbenchTheme` in the
same frame. Domain colors adjust tone automatically against the
new `surfaceTone` while staying identifiable by hue (red is
still red, blue is still blue).

### TokenTheme §spec:token-theme

`TokenTheme` is the syntax-highlighting companion surface,
populated from a VS Code theme's `tokenColors` section. The
controller exposes it alongside `WorkbenchTheme` so syntax
highlighters in consuming apps resolve against the same theme
switch.

### Tab strip canon §spec:tab-strip-canon

*Status: complete*

`WorkbenchTabbedPanel`'s tab strip renders three VS Code-canonical
treatments the shell owns under §spec:capability-boundary: the active-tab underline reads
from
[`panelTitle.activeBorder`](https://code.visualstudio.com/api/references/theme-color#panel-colors)
with the resolved foreground as fallback; pointer hover over an
inactive tab tints the label to
[`panelTitle.activeForeground`](https://code.visualstudio.com/api/references/theme-color#panel-colors)
(the active-tab text colour) without painting a background overlay;
and the `PanelTabBadge` pill paints in
[`badge.background`](https://code.visualstudio.com/api/references/theme-color#badge-colors)
/ `badge.foreground` — VS Code's generic badge accent, separate
from the underline (Light Modern uses a saturated blue badge
against a near-black underline; Dark Modern coincidentally uses
similar colours for both).

**Why match VS Code instead of Material defaults**. VS Code's
panel tab strip is the visual reference the package targets;
diverging from it on hover would mean every consumer who has used
VS Code reads the chrome as off-canon. The Material overlay-box
treatment also looks heavy on a workbench-thin tab strip — it
fills a region whose only "background" is the panel chrome itself,
producing a doubled-rectangle effect. Suppressing the overlay
removes the doubling without inventing a new visual treatment;
the label colour change is signal enough on a strip whose tabs
already have generous click targets.

**Why hover matches the active-tab text colour, not the
underline accent**. The selection underline (`panelTitle.activeBorder`)
signals "this tab is the active one." Hover signals "if you
click, this tab becomes active" — its visual goal is to
preview the active-tab styling on the prospective click target.
Active tabs render their label in `panelTitle.activeForeground`,
so hovered inactive tabs tint to the same colour. Tying hover to
the underline accent would conflate selection state with hover
state and produce a colour that doesn't match what the tab
becomes when clicked.

**Why not a separate `tabBarHoverColor` theme token**. The hover
colour is already the active-tab text colour
(`panelTitle.activeForeground`); surfacing a separate slot
would let consumers diverge hover from selected styling, which
is exactly the canon violation the shell exists to prevent. The
two colours come from `WorkbenchTheme`'s existing tab tokens and
nowhere else.

**Tradeoff accepted**. Wiring a hover-aware label colour requires
the tab strip to track pointer state per tab. The shell uses a
`MouseRegion` wrapper around each tab's label widget, which adds
a small amount of state per tab. The alternative — a single
hit-test region across the strip with pointer-position math —
would couple hover to tab geometry and break under tab reordering.
Per-tab `MouseRegion` is the standard Flutter pattern for
hover-on-individual-children and matches how `InkResponse` already
tracks per-button hover under Material.

**Observable behaviour**:

- A theme JSON that defines `panelTitle.activeBorder` renders the
  active-tab underline in that colour; a theme that omits it
  falls back to the resolved foreground.
- Hovering an inactive tab tints its label to the active-tab
  text colour (`panelTitle.activeForeground`); the active tab
  is unchanged on hover.
- No background overlay or box appears on hover; the tab strip
  remains visually flat aside from the underline.
- A `PanelTabBadge` pill paints in `badge.background` /
  `badge.foreground` — independent of the underline colour, so
  themes that distinguish them (e.g. Light Modern) render
  correctly without consumer wiring.

### Platform Brightness Sync §spec:platform-brightness-sync

*Status: complete*

Workbench chrome tracks the host OS's appearance setting. The theme
list is brightness-paired so `Light Modern` and `Dark Modern` (and
similar pairs) act as one logical theme at different brightnesses,
swapping automatically when the OS toggles. The native title bar —
which sits outside the Flutter view — follows the same signal so the
window chrome stays coherent across the OS-managed and Flutter-managed
surfaces.

§spec:platform-brightness-sync introduces a three-mode theme preference (System / Light / Dark),
nominates the active theme via a brightness-indexed registry, and
emits a brightness signal hosts wire into per-platform window-chrome
APIs.

**Theme mode**

`WorkbenchThemeController` carries a `ThemeMode` (`system | light |
dark`). In `system` mode the active theme resolves from
`PlatformDispatcher.platformBrightness` and the controller subscribes
to `onPlatformBrightnessChanged`, so OS-driven flips swap the theme
within one frame. In `light` or `dark` mode the active theme is the
preferred theme of the named brightness; the platform brightness signal
is ignored.

**Brightness-paired registry**

Theme entries declare a `Brightness` on `WorkbenchThemeEntry` so the
controller can pair without loading the asset. The host (or the user,
via persisted preference) nominates two slots: `preferredLight` and
`preferredDark`. In `system` mode the controller selects the slot that
matches the resolved brightness. The slots may name any registered
theme of the matching brightness; defaults are `Light Modern` for
`preferredLight` and `Dark Modern` for `preferredDark`.

**Why explicit pairing, not name-suffix matching**. The bundled list
contains obvious pairs (`Dark Modern` / `Light Modern`, `Dark+` /
`Light+`, `Solarized Dark` / `Solarized Light`, `Dark 2026` / `Light
2026`) but also `Monokai`, which has no light counterpart. A
suffix-matching scheme would silently refuse to resolve Monokai under
`system` mode, or invent an arbitrary fallback. Explicit nomination
gives the user a deliberate choice — pick any pair, including
unexpected ones (`Solarized Light` against `Dark+`) — and the
controller always has a defined answer.

**Why three modes, not two**. A two-mode `system | manual` model would
need a single "manual" theme slot, and toggling between manual themes
of different brightness while in `system` mode would silently override
the user's pair. The three-mode model treats `light` and `dark` as
explicit overrides of the OS signal — picking a theme in either mode
records intent ("I want a light workbench right now"), independent of
the System-mode pair. This matches macOS, iOS, Android, and VS Code's
appearance preference, which users already understand.

**Native window chrome**

The controller emits a resolved `Brightness` alongside the active
`WorkbenchTheme`. Hosts subscribe and forward the signal across the
canonical `workbench_shell/window_chrome` method channel — defined in
the bundled example app and documented as the contract every host
mirrors:

- Channel name: `workbench_shell/window_chrome`
- Method: `setBrightness`
- Argument: `String` — `'light'` or `'dark'`
- Direction: unidirectional Dart → host; the host runner replies
  `nil` on success and a `FlutterError` for malformed payloads.
- A `MissingPluginException` raised by the runner is benign — Dart
  treats it as a no-op so the signal degrades cleanly on platforms
  without a registered receiver.

Per-platform receivers:

- macOS: set `NSWindow.appearance` to `NSAppearance(named: .aqua)` or
  `.darkAqua` in the host's `MainFlutterWindow` runner.
- Windows: call `DwmSetWindowAttribute(hwnd,
  DWMWA_USE_IMMERSIVE_DARK_MODE, ...)` in the host's `flutter_window`
  runner.
- Linux: not supported. GTK title bars follow the system theme via
  `gtk-application-prefer-dark-theme`; per-window override requires
  client-side decorations or a window-manager-specific dance and
  produces inconsistent results across desktops. Hosts may add it if
  their target distribution warrants the cost.

`workbench_shell` ships the brightness signal and demonstrates the
wiring in the bundled example app's runners. The package itself does
not ship a platform plugin — its pure-Dart dependency footprint (§spec:capability-boundary)
is preserved, and the native code stays in each host's runner where
the window is already constructed.

**Why not vendor `macos_window_utils` or a similar package**. Each
platform needs ~10 lines of native code. A platform plugin would add
a runtime dependency, a method-channel hop on every brightness
change, and a publish-readiness coupling between `workbench_shell`'s
release cadence and an external maintainer's. The host runner is the
right home.

**Why brightness lives on the controller, not derived from
`MediaQuery.platformBrightnessOf`**. The controller already owns
theme switching state and is the single place where "the workbench is
currently in dark mode" is decided — whether by the system or by a
manual override. Hosts that read brightness elsewhere (e.g. a sidebar
that adapts an inline preview) get the override semantics for free:
flipping to `light` mode on a dark Mac makes the preview, the
workbench chrome, and the title bar all light in the same frame.

**Default mode**

`system` is the default for new users. A flat `light` or `dark`
default loses information — the user has not said they want a light
workbench on a dark Mac, only that they want a workbench. `system`
honours the OS until the user expresses a preference.

**Observable behaviour**

- `WorkbenchThemeController` exposes `themeMode`, `preferredLight`,
  `preferredDark`, and a `brightness` getter that returns the effective
  brightness of the active theme.
- In `system` mode, toggling the OS appearance swaps the active theme
  to the matching preferred slot within one frame and emits a
  brightness change.
- In `light` or `dark` mode, OS appearance changes do not affect the
  active theme.
- Selecting a theme via the picker while in `system` mode updates the
  matching preferred slot when the picked theme's brightness matches
  the current OS brightness; picking a theme of the opposite
  brightness flips the mode to `light` or `dark` to match.
- The example app's macOS and Windows runners observe the brightness
  signal over a method channel and update the window title bar
  appearance in the same frame as the chrome swap.

**Persistence**

The host owns persistence for `themeMode`, `preferredLight`, and
`preferredDark` (consistent with §spec:theming's existing position that the host
persists theme selection). The controller accepts initial values for
all three on construction.

**Tradeoff accepted**

Subscribing to platform brightness ties the controller's lifecycle to
`WidgetsBinding`. The controller already mounts as a `ChangeNotifier`
near the widget tree root, so the dependency is satisfied in practice
for every consumer; tests pass an explicit `PlatformDispatcher` (the
binding's, with `platformBrightnessTestValue` overrides) so the
subscription path is exercised deterministically.

### Chrome Typography Canon §spec:chrome-typography-canon

*Status: complete*

`workbench_shell`'s chrome typography — sidebar part titles, panel
tab labels, status bar items, body text, buttons, badges, structural
primitives — mirrors VS Code's workbench CSS literals. Both the
family rule and the per-surface point sizes follow the upstream
stylesheets, so a host running on the platform's default UI font
renders chrome at the same density VS Code does with no per-call-site
adjustment.

**Why typography belongs in the §spec:capability-boundary canon.** Typography drift is the
failure mode the package exists to remove — one sidebar's heading
rendering at 13pt, the next at 14pt, neither matching VS Code
itself. Pinning typography to VS Code's CSS literals at the theme
construction layer removes the per-host tuning step that made drift
inevitable. Earlier drafts owned family *names* and per-token sizes
without anchoring either to VS Code's actual values; consumers that
brought a font asset got narrower glyphs that visually compressed
the oversized sizes back toward VS Code's apparent density, while
consumers without that asset rendered chrome a point or more larger
than VS Code on the same surface.

**Family rule: platform UI sans.** Chrome `fontFamily` defaults to
`null`. Flutter resolves to the platform's default UI font, matching
VS Code's rules in
[`src/vs/workbench/browser/media/style.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/media/style.css)
(`-apple-system` / `Segoe UI` / `system-ui`). Hosts that need a brand
font pass `chromeFontFamily` on
`WorkbenchTheme.fromVscodeColorMap`; the override applies uniformly
to every chrome surface.

**Why not bundle a fixed chrome font.** Pinning a single family
(Roboto, Inter, etc.) would force every consumer onto the same
typeface regardless of OS context. VS Code deliberately follows the
host OS appearance because OS appearance is what users have already
tuned for legibility; the package follows the same rule.

**Why not branch `chromeFontFamily` defaults on
`defaultTargetPlatform`.** Returning explicit `'SF Pro'` / `'Segoe
UI'` / `'system-ui'` strings would resolve to the same platform
fallback Flutter already picks for `fontFamily: null`, while
introducing a maintenance surface that drifts as platforms ship new
system fonts.

**Surface-by-surface sizes.** Token literals mirror VS Code's
workbench CSS:

| Surface | VS Code source | Size / weight |
|---|---|---|
| Sidebar / panel part title ("EXPLORER") | `part.css` — `.title-label h2` | 11 / w400 |
| Sidebar pane header / `WorkbenchViewPane` | `paneview.css` — `.pane-header` | 11 / w700, uppercase |
| Workbench body content | `part.css` — `.part > .content` | 13 / w400 |
| Settings label / form label | `settingsEditor2.css` — `.setting-item-category` | 13 / w500 |
| Status bar item | `statusbarpart.css` | 12 / w400 |
| Button (default) | `button.css` | 12 / w400 |
| Editor tab label | `editortabscontrol.css` | 13 / w400 |
| Title bar / window title | `titlebarpart.css` | 12 / w400 |
| Description / caption | inherits body, painted in `descriptionForeground` | 12 / w400 |
| Badge pill (panel tab count, dense numeric labels) | `paneCompositeBar.css` activity / pane badge tier | 11 / w600 |

`WorkbenchTheme`'s `sectionTitle`, `bodyText`, `labelText`,
`statusText`, `statusBarTextStyle`, `buttonTextStyle`,
`sidebarOrPanelHeading`, `captionText`, `helperStyle`, and
`smallText` tokens carry these literals.

**`sectionTitle` adopts pane-header semantics.** The token's role —
top-level grouping inside a sidebar or panel body, per
`WorkbenchViewPane` and `WorkbenchEmptyState` (§spec:structural-primitives) — maps onto VS
Code's pane header (`.pane-header`, `11 / bold / uppercase`).
`WorkbenchViewPane.title` renders uppercase in the shell regardless
of input casing, parallel to the §spec:tabbed-panel tab-label canon.

**`smallText` is the badge tier.** Internal token the panel-tab
badge pill paints in, and the host analogue for dense numeric
indicators. VS Code's titlebar badge is `9 / w400` and the
activity-bar / pane-composite badges are `11 / w600`; the package
picks `11 / w600` to keep one shared token across in-strip and host
badge surfaces.

**Rejected — registering Inconsolata as a bundled chrome asset.**
An earlier draft bundled Inconsolata as a package asset and stamped
it as the chrome family on every token. Chrome is not a monospaced
surface anywhere in VS Code; platform UI sans is both the
consumer-equivalent default and the canonically correct one.

**Observable behavior.**

- A `MaterialApp` consumer that constructs
  `WorkbenchTheme.fromVscodeColorMap(...)` with no font override
  renders every chrome surface in the platform's default UI sans at
  VS Code's literal pixel values.
- `WorkbenchViewPane.title` renders uppercase regardless of input
  casing; the shell applies the transform internally.
- Setting `chromeFontFamily` on the factory flips every chrome
  surface in the next frame.
- `WorkbenchTabbedPanel`, `WorkbenchStatusBar`, `WorkbenchMenuBar`,
  and the structural primitives paint with the same chrome family
  — host content composed against `theme.bodyText` /
  `theme.sectionTitle` matches the package's internal chrome.

### Editor-derived Surfaces §spec:editor-derived-surfaces

*Status: complete*

Log-line surfaces (output panels, terminal-style consoles) and host
numeric surfaces (DRO readouts, tabular values) do not live in the
chrome typography canon (§spec:chrome-typography-canon) — they live in the editor's. VS Code
uses configurable `editor.fontFamily` and `editor.fontSize` for
these surfaces, both defaulting to a per-platform monospace via
`EDITOR_FONT_DEFAULTS` in
[`src/vs/editor/common/config/fontInfo.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/editor/common/config/fontInfo.ts).
`workbench_shell` exposes the same anchor so log-line and value
styles read from one place that downstream hosts can swap.

**Anchor token: `editorStyle`.** `WorkbenchTheme` carries
`editorFontFamily` (`String`) and `editorFontSize` (`double`) plus
a derived `editorStyle` (`TextStyle`). Tokens whose role is
editor-derived monospace — `loglineMessage` and `valueText` —
derive from `editorStyle` via `copyWith` rather than fabricating
their own font ladders.

**Per-platform defaults.** When `editorFontFamily` /
`editorFontSize` are not overridden on the factory, the package
mirrors VS Code's `EDITOR_FONT_DEFAULTS` primary family per
platform:

| Platform | `editorFontFamily` | `editorFontSize` |
|---|---|---|
| macOS / iOS | `Menlo` | 12 |
| Windows | `Consolas` | 14 |
| Linux / Android / Fuchsia | `Droid Sans Mono` | 14 |

Values mirror `DEFAULT_MAC_FONT_FAMILY`,
`DEFAULT_WINDOWS_FONT_FAMILY`, `DEFAULT_LINUX_FONT_FAMILY`, and the
`isMacintosh ? 12 : 14` size selector in upstream `fontInfo.ts`.
Flutter falls back to the platform monospace when the primary is
missing.

**Why a single anchor rather than per-surface families.** Log-line,
value, and DRO surfaces all want the same property — tabular
monospace at a configurable family and size. Repeating the family
resolution at every surface would let one surface drift (a future
log style accidentally hardcodes `'Menlo'`); a single anchor makes
the override path one parameter wide.

**Host override path.** Hosts whose brand requires a specific
monospace pass `editorFontFamily: 'Inconsolata'` on
`WorkbenchTheme.fromVscodeColorMap`. The override flows through
`editorStyle` to every editor-derived token without per-call-site
changes. Hosts may override `editorFontSize` for compact readouts;
tokens that need a different size per role apply `copyWith` against
`editorStyle` rather than re-resolving the family.

**Rejected — separate `loglineFontFamily` and `droFontFamily`
parameters.** Two parameters for the same underlying role would let
a host wire log-lines to one family and DRO to another, splitting
visual identity for no clear reason. VS Code uses one
`editor.fontFamily` for both the Output panel and the editor.

**Rejected — moving log-line and `valueText` tokens out of
`WorkbenchTheme` entirely.** Pushing them host-side would force
every consumer to reinvent the editor-derived ladder. The tokens
are generic in shape; only the family / size choice is host-tunable.

**Observable behavior.**

- `WorkbenchTheme.editorStyle` resolves to a `TextStyle` carrying
  the active `editorFontFamily` / `editorFontSize`. Switching
  chrome themes does not change either; switching `editorFontFamily`
  on the factory does.
- `loglineMessage` and `valueText` paint in the same family —
  neither reaches outside `editorStyle` for its base.
- A consumer that omits `editorFontFamily` gets the platform's
  default monospace per the table above. A host can render log-line
  and value surfaces in a brand monospace (e.g. Inconsolata) by
  setting `editorFontFamily` on theme construction.

### Chrome Material Theming Contract §spec:chrome-material-theming

*Status: complete*

`applyWorkbenchChrome` composes VS Code styling onto a host's
`ThemeData` so the standard Material widgets a host places inherit chrome
control without per-widget wiring. The contract is **parity**: every
Material surface the chrome composes onto is brought fully under chrome
control; none falls back to a `ColorScheme` role or base `ThemeData`
value the chrome leaves unset.

**Why parity, not a curated subset.** A host that drops a stock Material
widget into the chrome expects it to read as VS Code chrome, the way its
themed siblings do. A surface the chrome covers only partially inherits
whatever the host's base `ThemeData` carries — typically a default
Material role the chrome never remaps, rendering uncontrolled and often
low-contrast against the chrome background. Partial coverage reintroduces
the per-widget drift the shell exists to remove (§spec:capability-boundary). The invariant is
therefore all-or-nothing per surface: if the chrome themes a widget
family, it themes every member, and no member reads from a role the
chrome leaves unset.

**Why this is not a §spec:form-controls-excluded violation.** §spec:form-controls-excluded excludes Material *primitives* —
the shell publishes no reusable widget. This contract themes the host's
*own* Material widgets; it adds no primitive. No widget is exposed, yet
no host widget escapes chrome control.

**Currently owned surface: the button family.** The chrome themes the
full Material button family at a shared flat, compact VS Code sizing
(§spec:layout-constants-canon: elevation 0, 4px shape, compact height, shrink-wrapped tap
target):

- `FilledButton` (primary) / `FilledButton.tonal` (secondary) — fills
  driven through the `primary`/`onPrimary` and
  `secondaryContainer`/`onSecondaryContainer` roles.
- `TextButton` (text / link) — link-accent label.
- `SegmentedButton` (single-select selectors) — neutral selected fill.
- `IconButton` — foreground from a dedicated `iconForeground` token
  mapping VS Code's
  [`icon.foreground`](https://code.visualstudio.com/api/references/theme-color#icon-colors).

The set is extensible: input decoration and other Material surfaces can
join the contract without changing call sites. Each addition obeys
parity — it themes the whole widget, not a subset of its states.

**Why `IconButton` maps `icon.foreground`, not `foreground` or
`descriptionForeground`.** VS Code colors workbench icon buttons (toolbar
and view-title action icons) from a dedicated `icon.foreground` token —
near-full contrast (`#C5C5C5` dark / `#424242` light), deliberately
distinct from `foreground` (body text) and `descriptionForeground`
(secondary text, derived as 70%-opacity foreground). Reusing an existing
chrome token would diverge from VS Code: `descriptionForeground` renders
icon buttons dimmer than upstream and conflates an actionable affordance
with secondary text; `foreground` overshoots. The chrome therefore
carries its own `iconForeground` token mapping `icon.foreground`, the
same token-per-VS-Code-semantic pattern every other chrome token follows.
Hover is left to Material's default state-layer overlay rather than a
glyph-color change — matching VS Code, which signals icon-button hover
with a `toolbar.hoverBackground` background, not a foreground shift.

**Observable behavior.**

- For every owned widget family, `applyWorkbenchChrome` installs the
  corresponding `*ThemeData`; no member resolves a foreground or fill
  from a `ColorScheme` role the chrome's override leaves unset.
- A stock instance of any owned widget, placed bare under the chrome,
  renders legibly against the chrome background on both light and dark
  themes, at the chrome's sizing.
- A bare `IconButton` resolves its foreground from `iconForeground`
  (← VS Code `icon.foreground`), never from the base
  `ColorScheme.onSurfaceVariant` the chrome leaves unset.

## Layout Constants §spec:layout-constants

*Status: complete*

`WorkbenchLayoutConstants` is the single authority for
workbench geometry: structural dimensions (activity bar width,
sidebar min/max width, status bar height, view-pane header height,
view-pane minimum body height — the floor below which the view-stack
splitview engages its overflow scroll, §spec:view-stack), spacing
scale, icon sizes, and container radius.

**Why not theme-driven**: icon sizes and spacing are fixed
geometry, not appearance. VS Code treats them identically to
activity bar width. Putting them on `WorkbenchTheme` would add
runtime resolution and widget rebuilds for values that never
change.

**Why not a shared `layout_tokens` package**: consumers already
depend on `workbench_shell`. A third package for a handful of
constants adds overhead with no new information.

### Layout Constants Canon §spec:layout-constants-canon

*Status: complete*

`WorkbenchLayoutConstants` (§spec:layout-constants) mirrors VS Code's per-part
geometry literals — both the values defined in workbench CSS
(`part.css`, `statusbarpart.css`, `activitybarpart.css`) and the
constants registered in TypeScript (`sidebarPart.ts`,
`panelPart.ts`, `notificationsToasts.ts`, `baseSizes.ts`). Each
constant whose purpose maps cleanly onto a VS Code part takes
the value of its upstream literal. Slots without an upstream
peer (default sizes that VS Code persists per user, package-
local spacing and icon scales) keep their workbench_shell-chosen
value with rationale recorded here.

**Why typography canon (§spec:chrome-typography-canon) is not enough.** §spec:chrome-typography-canon pinned font
families and per-token sizes to VS Code's CSS, but did not touch
container heights, widths, or padding scales. A 25px status bar
against VS Code's 22px and a 200px sidebar minimum against VS
Code's 170 produce the same "looks IDE-adjacent, not IDE-
canonical" failure mode that §spec:capability-boundary exists to remove. The fix is
the same shape as §spec:chrome-typography-canon: source-cite each value; leave drift no
place to hide.

**Canonical source table**:

| Constant | Value | VS Code source |
|---|---|---|
| `activityBarWidth` | 48 | [`activitybarpart.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/activitybar/media/activitybarpart.css) — `width: 48px` |
| `activityBarIndicatorWidth` | 2 | activity bar item left-border indicator (same file) |
| `sidebarHeadingHeight` | 35 | [`part.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/media/part.css) — `.part > .title { height: 35px }` |
| `panelTabStripHeight` | 35 | shared `.part > .title` (same file) |
| `statusBarHeight` | 22 | [`statusbarpart.css`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/statusbar/media/statusbarpart.css) — `height: 22px`. Cross-confirmed by inline comment in `notificationsToasts.css`: `bottom: 25px; /* 22px status bar height + 3px */` |
| `sidebarMinWidth` | 170 | [`sidebarPart.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/sidebar/sidebarPart.ts) — `readonly minimumWidth: number = 170` |
| `panelMinHeight` | 77 | [`panelPart.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/panel/panelPart.ts) — `readonly minimumHeight: number = 77` |
| `notificationCardWidth` | 450 | [`notificationsToasts.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/browser/parts/notifications/notificationsToasts.ts) — `private static readonly MAX_WIDTH = 450` |
| `containerRadius` | 4 | [`baseSizes.ts`](https://github.com/microsoft/vscode/blob/main/src/vs/platform/theme/common/sizes/baseSizes.ts) — `cornerRadius.small = 4px` |
| `notificationCardRadius` | 4 | same as `containerRadius` (`cornerRadius.small`) |
| `buttonRadius` | 4 | [`button.css`](https://github.com/microsoft/vscode/blob/main/src/vs/base/browser/ui/button/button.css) — `.monaco-text-button { border-radius: 4px; }` |

**Constants without a VS Code peer.** Some
`WorkbenchLayoutConstants` slots intentionally diverge because
VS Code resolves them at runtime (user-preference persistence,
dynamic max bounded by workspace size, grid-sash machinery)
rather than declaring a literal. The package picks a static
default and records the rationale:

| Constant | Value | Why no peer | Rationale |
|---|---|---|---|
| `sidebarDefaultWidth` | 300 | VS Code persists last user width | Common starting point that fits an Explorer-plus-OUTLINE column without truncation on a 1440-wide screen |
| `panelDefaultHeight` | 200 | VS Code persists last user height | Tall enough to show a useful number of log lines without dominating the editor area |
| `panelMaxHeight` | 400 | VS Code allows dynamic max bounded by editor area | Static cap keeps the shell from re-implementing VS Code's layout-service min/max negotiation; consumers that need taller panels override at the layout call site |
| `sidebarMaxWidth` | 600 | VS Code caps at ~75% of window width dynamically | Same reasoning as `panelMaxHeight` |
| Spacing scale (`spacingXxs` … `spacingXl`) | 2 / 4 / 6 / 8 / 12 / 16 / 24 | VS Code uses ad-hoc paddings throughout; no shared scale | Package-internal consistency so primitives (`WorkbenchViewPane`, `WorkbenchCard`) compose without hardcoded paddings at call sites |
| Icon sizes (`iconXs`, `iconSm`, `iconMd`, `iconLg`, `iconXl`, `iconXxl`, `iconActivityBar`) | 12 / 14 / 16 / 18 / 20 / 32 / 24 | VS Code uses 16 for most codicons (`codiconFontSize` in `baseSizes.ts`), 12 for compact (`codiconFontSize.compact`) | Provides a scale around VS Code's 16 default for surfaces (close affordances, status indicators) where a single fixed icon size doesn't fit |
| `notificationProgressBarHeight` | 4 | not surfaced within search scope of VS Code source | Matches the visible progress bar height VS Code renders |

**Panel tab strip: one container, not three constants.** VS Code
lays the tab strip inside a single 35px `.part > .title` container
and flex-centres its children. `panelTabStripHeight` is that single
constant; `WorkbenchTabbedPanel`'s `Row` flex-aligns its children
with no padding constants. An earlier split
(`panelTabStripPaddingY` + a 22px height + trailing padding ≈ 34px)
was a workbench_shell invention that approximated 35px while
exposing "three constants for one dimension" on the public API;
it is removed.

**Container radius: keep as constant, document the upstream.**
`containerRadius` already matches VS Code's
`cornerRadius.small = 4`. VS Code resolves it through a CSS
custom property (`var(--vscode-cornerRadius-small)`) registered
via `baseSizes.ts` — theoretically theme-overridable, but every
shipped VS Code theme uses the same value (the registration uses
`sizeForAllThemes(4, 'px')`, which the registration helper
enforces as constant across themes). The package keeps the value
as a constant; §spec:layout-constants's "no runtime resolution for never-changing
values" rationale stands. If a future VS Code release introduces
per-theme overrides, the constant migrates to `WorkbenchTheme`
as a token.

**Rejected — keeping the existing values for "visual comfort".**
Earlier defenses of the 25 / 200 / 100 / 360 deltas argued each
one gives a more spacious feel than VS Code's tighter literals.
The case fails on the same grounds as the typography canon:
"workbench_shell as a more spacious VS Code" is a position the
package has nowhere claimed and that consumers do not expect;
under §spec:capability-boundary, matching VS Code's IDE-canonical density is the goal.

**Rejected — making layout constants theme-driven.** Moving
geometry onto `WorkbenchTheme` would let chrome themes ship
their own status bar height or sidebar minimum. VS Code itself
does not expose these as per-theme tokens (the values live in
CSS and TS constants, not theme JSON), so the indirection would
add no expressive power and would split the geometry surface
between two ownership boundaries.

**Tradeoffs accepted**.

- *Geometry shifts for hosts laying out around the previous
  status bar / sidebar / panel / notification widths.* A host that
  pinned offsets against the old 25px status bar, bounded sidebar
  content above 170px, or sized toasts against 360px shall adapt to
  the canon values. The shifts match VS Code's observable layout;
  consumers needing product-specific geometry re-pin at the layout
  call site (no per-value override is exposed — the canon covers
  the known consumers).

**Observable behavior**.

- The status bar renders at 22px (one row of `12 / w400` text
  with VS Code's line-height). Side-by-side with VS Code, the
  status bar height matches to the pixel.
- The sidebar collapses to 170px when dragged to its minimum,
  matching VS Code's collapse floor.
- The bottom panel collapses to 77px at minimum, matching VS
  Code's panel floor.
- Notification toasts render 450px wide on every shipped theme,
  matching VS Code's `MAX_WIDTH`.
- Panel tab strip and sidebar heading both render in a 35px
  container (one shared constant, not three split constants).
- The bundled example app renders at the same pixel measurements
  as VS Code for every chrome part with a canonical upstream value.

---

## Notification Center §spec:notification-center

*Status: complete*

Application events need non-blocking, non-modal user feedback
for outcomes that do not warrant a dialog: file saved, profile
imported, operation failed, background task finished. Flutter's
`ScaffoldMessenger.showSnackBar` renders a single full-width
bar at the bottom of the window, blocks the status bar, uses
severity-incorrect colours, and dismisses previous events on
every new one — a burst of three events shows only the last.

`workbench_shell` owns a notification center modelled on VS
Code's: stacked toast cards anchored bottom-right, severity-keyed
dismissal, an injected `NotificationService`, and a separate
progress-controller API for long-running tasks.

**Why in `workbench_shell`**: the notification center is generic
workbench chrome. Any host building on the shell needs the same
stacked-toast affordance with the same severity semantics. The boundary test applies: no host-specific types
cross the API — `NotificationSeverity`, `String` message,
optional `List<NotificationAction>` only.

**Why an injected service, not a widget API**: hosts should not
plumb `Overlay` or `GlobalKey`s. `NotificationService` is a
shell-provided `ChangeNotifier`; hosts mount a single
`NotificationHost` widget inside `WorkbenchLayout` and call
`context.read<NotificationService>().show(...)` anywhere in the
subtree. This mirrors `ScaffoldMessenger`'s ergonomics without
requiring a `Scaffold`. The service extends `ChangeNotifier`
because the host widget subscribes to it; descendant hosts that
only call `show` get `ChangeNotifierProvider.value` plumbing
without observable rebuilds.

**Why a stack rather than a queue**: a burst of events (three
file writes completing in quick succession) is not transient
noise — each is a distinct outcome the operator may need to
see. Stacking preserves them; a queue would hide all but the
current event and defeat the system's purpose.

**Why separate `showProgress` from `show`**: progress has a
controller-shaped lifecycle (mutable value, cancel affordance,
terminal `complete`/`fail`) that doesn't fit the fire-and-forget
shape of severity toasts. VS Code's `window.withProgress`
separates them for the same reason; Apple's Live Activities
split from `UNUserNotification` on the same boundary. Windows
AppNotifications unifies them but recommends *replacing* on
completion as a workaround for the unified shape. A separate
controller keeps `show` trivial for the common case and gives
progress callers exactly the affordances they need.

**Dismissal policy by severity**:

| Severity | Lifetime |
|---|---|
| `info`, `success` | Auto-dismiss after 6 s of uninterrupted, non-hover, window-focused time |
| `warning`, `error` | Persist until operator or host dismisses |
| `progress` | Persist until controller's `complete`/`fail` (or operator `cancel` on cancellable) |

Hover and window-focus pauses prevent a card fired during a
context switch from ticking down invisibly while the operator
is in another app. The pause persists `AppLifecycleState.inactive`
and `paused`; `resumed` resumes from the remaining duration.

**Theming**: `WorkbenchTheme` carries notification tokens — card
background, border, foreground, severity-keyed accent (reusing
the existing `infoForeground`, `successForeground`, etc.
tokens), action-button colours, progress track and fill. No
widget reads host palettes directly.

**Action invocation**: tapping a `NotificationAction` invokes
its callback and dismisses the card in the same frame —
terminal interaction matching VS Code. Hosts that want to keep
state visible after an action post a follow-up card from inside
the callback. No sticky-action flag.

**Observable behavior**:

- `show(severity, message)` causes a themed card to appear
  bottom-right within one frame. Successive calls stack
  vertically, newest at the bottom.
- Auto-dismiss timers pause on hover, on window-unfocus, or
  while the operator has any card hovered. Persistent
  severities and in-flight progress cards have no timer.
- The notification stack renders above all workbench surfaces
  (sidebar, editor, bottom panel, status bar) but below
  platform modals (dialogs, menus).
- More than five simultaneous cards collapse the oldest
  non-persistent ones into a "+N more" summary at the top of
  the visible stack; tapping expands the hidden cards into a
  scrollable list. Persistent cards (warning, error, progress)
  fill visible slots first and push transient cards into the
  summary.
- `showProgress(...)` returns a `NotificationProgressController`
  whose `report` updates the live card in place (same id, no
  re-stacking), `complete(successMessage:)` converts the card
  to a 6-second success toast, `fail(message)` converts to a
  persistent error toast, and `cancellation` resolves when the
  operator presses the cancel affordance or the card is
  dismissed externally.

---

## Testing Strategy §spec:testing-strategy

*Status: complete*

The package uses `flutter_test` for widget-level coverage. Tests
exercise structural primitives, chrome widgets, layout constants,
theming controller, and the platform-agnostic bits of the menu
bar (platform-conditional code paths are gated by host-side
integration tests in consuming applications).

Each theme JSON asset ships with a regression test that asserts
the token map parses without diagnostics and resolves every
referenced `WorkbenchTheme` token.

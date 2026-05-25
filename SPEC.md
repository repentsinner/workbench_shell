# workbench_shell Specification

A Flutter package that renders VS Code-style workbench chrome — the
activity bar, sidebar, editor area, bottom panel, status bar, menu
bar, and a small vocabulary of structural primitives that sidebars
and bottom panels compose to build their bodies. The package
depends only on Flutter and a handful of general-purpose
pub.dev libraries, so any Flutter desktop or mobile app can adopt
the chrome without inheriting a host application's domain model.

Rove consumes this package from the monorepo via `path:` during
development; on pub.dev the same package will ship with an
independent semver track (§15.2 in the upstream Rove SPEC). The
governance here is package-local — it describes the workbench
shell's design intent as the standalone published artifact, not
the consuming application.

---

## 1. Problem Statement

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

## 2. Scope

*Status: complete*

**In scope**

- Workbench layout: activity bar, sidebar stack, editor area,
  bottom panel, status bar.
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
- Structural primitives: `WorkbenchSection`, `WorkbenchSubsection`,
  `WorkbenchCard`, `WorkbenchToggleCard`, `WorkbenchEmptyState`.
- Theming: `WorkbenchTheme` (chrome tokens),
  `WorkbenchThemeController` (theme switching, VS Code JSON
  loader, `TokenTheme` for syntax highlighting), `TokenTheme`,
  `WorkbenchLayoutConstants` (fixed geometry).
- UI extension slots: `SlotRegistry`, `SidebarSlot`, `SidebarZone`,
  `SlotId`. Hosts register content for named slots; the shell
  renders registered slots in z-order per zone.
- Notification Center (§7) — planned; not yet implemented.

**Out of scope**

- Form controls (text fields, dropdowns, toggles, action
  buttons). See §6 for the re-promotion gate.
- Host-specific domain types, BLoCs, or state management.
- Editor widgets (text editing, syntax-highlighted viewers).
  Consumers supply their own editor content inside
  `WorkbenchLayout`'s editor slot.

---

## 3. Shell Capability Boundary

*Status: complete*

Chrome that is generic to a VS Code-style workbench belongs in
`workbench_shell`; chrome that encodes a specific product's
domain belongs outside.

**Boundary test**: could a non-Rove application use the shell
without knowing Rove exists? Section navigation, status-bar
chrome, the View menu, and tabbed bottom-panel composition
satisfy this test.

**Dependency footprint**: `workbench_shell/lib/` imports only
Flutter, `equatable`, `material_color_utilities`, and
`material_symbols_icons`. A CI gate
(`tools/lint-workbench-shell-boundary.sh` in the consuming
monorepo) fails the build if any file under `lib/` imports a
Rove or CNC-specific package. The package ships with its own
allowlist so downstream consumers can add an equivalent gate.

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
exists to remove (§1).

The precedent is in the codebase: `WorkbenchSection` and
`WorkbenchSubsection` headings render uppercase regardless of how
the consumer cases the input string; `WorkbenchTabbedPanel` does
the same for tab labels and renders the inline count badge from
a typed `PanelTabBadge` payload, painting the pill in VS Code's
generic badge accent (`badge.background`). Every new chrome
surface follows the same model.

---

## 4. Structural Primitives

*Status: complete*

Structural primitives encode the workbench's visual hierarchy as
types. A sidebar that uses `WorkbenchSection` inside a
`WorkbenchSubsection` inside a `WorkbenchCard` gets consistent
heading sizes, card borders, and section padding by construction.
Every sidebar and panel reads the same `WorkbenchTheme` tokens
through the same widgets, so styling drift (one sidebar's
"subsection" rendering 12pt, another's 14pt because each file
reaches into tokens directly) cannot happen.

**Why primitives, not style mixins**: VS Code's webview and
tree-view APIs make the same choice — the hierarchy is a type,
not a convention. A mixin approach would let a host skip the
primitive, reach into the theme, and invent inconsistent
typography at one call site — which is the failure mode the
primitives exist to prevent.

**Primitive vocabulary**:

| Widget | Purpose |
|---|---|
| `WorkbenchSection` | Top-level section in a sidebar or panel body with title typography and padding |
| `WorkbenchSubsection` | Nested section with smaller title typography |
| `WorkbenchCard` | Bordered container; the atom of sidebar content |
| `WorkbenchToggleCard` | Card with a leading toggle and expand/collapse |
| `WorkbenchEmptyState` | Canonical empty-state with icon, title, optional action |

**Observable behavior**: every sidebar and bottom panel renders
with consistent section framing — section titles at the same
size and weight, subsection titles at the same smaller size,
cards and toggle cards at the same border radius and border
color. Layout tokens come from `WorkbenchLayoutConstants`; colors
and typography come from `WorkbenchTheme`.

---

## 5. Chrome Widgets

*Status: complete*

### 5.1 WorkbenchLayout

`WorkbenchLayout` composes activity bar + sidebar + editor +
bottom panel + status bar. It accepts `activeSectionId` and
`onSectionChanged` from the host, so applications can drive shell
navigation (for example, a bottom-panel action that switches
sidebars) while the shell still supports an uncontrolled mode for
callers that do not need external control.

### 5.2 WorkbenchTabbedPanel and WorkbenchPanelTab

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

**Canonical tab strip rendering**. Per §3 enforcement, the tab
strip is text-only and labels render uppercase. The shell applies
both invariants in its rendering — consumers pass `String` labels
in natural case (`'Output'`, `'Debug Console'`) and the shell
renders `'OUTPUT'`, `'DEBUG CONSOLE'`. Consumers needing the VS
Code "Problems (3)" pattern supply a typed `PanelTabBadge` (count
only) which the shell renders inline next to the uppercased label,
painting the pill in VS Code's generic badge accent
(`badge.background` / `badge.foreground`) — a separate slot from
the panel-active underline. The badge does not vary by severity:
a multi-severity collection (Rove's UserTasks has error / warning
/ info) has no obvious "summary severity" to project (highest?
most populous?), so the count stands on its own.

### 5.3 Status Bar

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

### 5.4 WorkbenchMenuBar

`WorkbenchMenuBar` owns a top-level View menu and the standard
app/Window menus that frame it. The View menu lists a static
"Panel" entry plus one entry per host-supplied
`WorkbenchViewMenuTab`. Each `WorkbenchViewMenuTab` carries an
arbitrary `Intent` the host defines; the menu item dispatches
that intent via `Actions.maybeInvoke`. The "Panel" entry always
dispatches `ToggleBottomPanelIntent` (§5.6). `WorkbenchMenuBar`
itself takes no callback props.

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

**Why not custom window chrome**: VS Code on Windows defaults to
a custom title bar that merges the menu bar and window controls
into one strip (`window.titleBarStyle: "custom"`). Replicating
that in Flutter requires taking over the window frame via
`bitsdojo_window` or equivalent, which adds custom drag regions,
custom min/max/close button rendering, HiDPI handling, Wayland
fallout, and a separate traffic-light story on macOS. Rove is
not trying to reskin the window — it only needs the View menu to
live somewhere predictable and platform-appropriate. The in-
window `MenuBar` strip below the standard OS title bar achieves
this with no custom chrome; VS Code itself supports the same
layout via `window.titleBarStyle: "native"`.

**Tradeoffs accepted**: the in-window menu strip on Windows and
Linux costs one row of vertical space below the OS title bar
that VS Code's custom-titlebar mode would reclaim. This is
acceptable given the complexity savings and the absence of any
first-party Flutter API that would let us recover the space
without taking over the window frame. If a future Flutter
release exposes native menu surfaces on Windows or Linux,
`WorkbenchMenuBar` can switch render paths without changes to
the descriptor model — `WorkbenchViewMenuTab` (intent + label +
optional shortcut glyph) is platform-agnostic.

**Menu bar theming**: the Windows/Linux strip resolves its
background, foreground, hover, and border colours from
`WorkbenchTheme` (`menuBarBackground`, `menuBarForeground`,
`menuBarHoverBackground`, `menuBarBorder`) rather than the
ambient `Theme.of(context)` defaults, so the strip reads as
workbench chrome rather than a generic Material surface. Custom
window-frame takeover (merging the menu bar into a custom title
bar à la `bitsdojo_window`) is explicitly out of scope —
`workbench_shell` does not reskin the OS window.

### 5.5 WorkbenchShortcuts

`WorkbenchShortcuts` installs the one keyboard binding every
workbench ships: Cmd+J and Ctrl+J both dispatch
`ToggleBottomPanelIntent` through Flutter's `Shortcuts`/`Actions`
pair (§5.6). Both activators are registered so the same intent
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

### 5.6 Action Dispatch

*Status: complete*

Menu entries (§5.4) and keyboard shortcuts (§5.5) dispatch
through Flutter's `Actions`/`Intent` machinery. The shell
publishes exactly one public intent: `ToggleBottomPanelIntent`.
Every other command is host-defined — `WorkbenchViewMenuTab`
carries an arbitrary `Intent`, and hosts install their own
`Shortcuts` bindings for host-specific activators. Hosts
register `Action<Intent>` handlers at the widget that owns the
target state.

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
item or shortcut dispatches must be declared publicly either by
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
to adopt Rove's layout. Each host defines its own intents
(Rove's is `FocusBottomPanelTabIntent(BottomPanelTabIds tab)`)
and installs its own `Shortcuts` map around the shell.

**Scope**. Covers the View menu + Cmd/Ctrl+J. Notification-center
dispatch (§10) is out of scope — that section defines its own
intents. Host-defined shortcuts continue to pass through
`extraShortcuts` or a surrounding `Shortcuts` widget.

### 5.7 Bottom Panel Lifecycle

*Status: complete*

`WorkbenchPanel` is the single declaration for one bottom-panel
tab; `WorkbenchPanelHost` consumes an ordered list of them and
derives the View menu (§5.4), keyboard-shortcut map, tab strip
(§5.2), and per-panel `PanelLifecycle` instances. Consumers
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

**Coexistence with §5.2**. `WorkbenchTabbedPanel` and
`WorkbenchPanelTab` remain as the low-level tab-strip primitive.
`WorkbenchPanelHost` composes them internally. Consumers that
need a tab strip outside the shell's menu-integrated model
continue to use §5.2 directly. The §5.2 descriptor itself is
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

**Scope**. Bottom panel only. Sidebars (§5.1) compose
differently — single builder per activity-bar section, not a
tabbed stack — and do not need a parallel lifecycle abstraction.
Notification-center surfaces (§10) live outside the bottom-panel
model and do not participate in this contract.

---

## 6. Form Controls Are Excluded

*Status: complete*

`workbench_shell` does **not** own form controls — text fields,
dropdowns, toggles, action buttons. Consuming applications keep
those in their own UI packages, themed against `WorkbenchTheme`
so theme switching still works but not exposed as reusable
primitives.

**Why form controls are not primitives yet**:

- *Single-consumer in practice.* Each form-control variant in
  the current Rove app has one to three call sites. "Reusable
  primitive" is aspirational framing for what is currently a
  locally-extracted helper.
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

## 7. Theming

*Status: complete*

The theme architecture splits along a single axis: **chrome vs
domain**. `workbench_shell` owns chrome via `WorkbenchTheme`.
Consuming applications own domain tokens (e.g. axis colors,
alarm severities) via their own `ThemeExtension` and bridge to
`WorkbenchTheme`'s `surfaceTone` for HCT tonal resolution when
contrast-safe colors are required against the chrome background.

**Reference integration**: the bundled example app
(`packages/workbench_shell/example/`) wires
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

### 7.1 VS Code Theme Format

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

### 7.2 HCT Tonal Resolution Contract

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

### 7.3 TokenTheme

`TokenTheme` is the syntax-highlighting companion surface,
populated from a VS Code theme's `tokenColors` section. The
controller exposes it alongside `WorkbenchTheme` so syntax
highlighters in consuming apps resolve against the same theme
switch.

### 7.4 Tab strip canon

*Status: complete*

`WorkbenchTabbedPanel`'s tab strip renders three VS Code-canonical
treatments the shell owns under §3: the active-tab underline reads
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

### 7.5 Platform Brightness Sync §spec:platform-brightness-sync

*Status: complete*

Workbench chrome tracks the host OS's appearance setting. The theme
list is brightness-paired so `Light Modern` and `Dark Modern` (and
similar pairs) act as one logical theme at different brightnesses,
swapping automatically when the OS toggles. The native title bar —
which sits outside the Flutter view — follows the same signal so the
window chrome stays coherent across the OS-managed and Flutter-managed
surfaces.

§7.5 introduces a three-mode theme preference (System / Light / Dark),
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
not ship a platform plugin — its pure-Dart dependency footprint (§3)
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
`preferredDark` (consistent with §7's existing position that the host
persists theme selection). The controller accepts initial values for
all three on construction.

**Tradeoff accepted**

Subscribing to platform brightness ties the controller's lifecycle to
`WidgetsBinding`. The controller already mounts as a `ChangeNotifier`
near the widget tree root, so the dependency is satisfied in practice
for every consumer; tests pass an explicit `PlatformDispatcher` (the
binding's, with `platformBrightnessTestValue` overrides) so the
subscription path is exercised deterministically.

## 8. Layout Constants

*Status: complete*

`WorkbenchLayoutConstants` is the single authority for
workbench geometry: structural dimensions (activity bar width,
sidebar min/max width, status bar height), spacing scale,
icon sizes, and container radius.

**Why not theme-driven**: icon sizes and spacing are fixed
geometry, not appearance. VS Code treats them identically to
activity bar width. Putting them on `WorkbenchTheme` would add
runtime resolution and widget rebuilds for values that never
change.

**Why not a shared `layout_tokens` package**: consumers already
depend on `workbench_shell`. A third package for a handful of
constants adds overhead with no new information.

---

## 9. UI Extension Slots

*Status: complete*

`SlotRegistry`, `SidebarSlot`, and `SidebarZone` are the shell's
extension points for hosts that want to compose sidebar content
from independent modules. A host registers `SidebarSlot`
instances against a named `SlotId` in a chosen `SidebarZone`;
the shell renders registered slots in z-order per zone.

**Why in the shell**: the slot types are pure widget-factory
shapes with no knowledge of the host's module system. Placing
them in the shell keeps sidebar composition decoupled from
application layering and makes the extension point available to
any consumer.

---

## 10. Notification Center

*Status: not started*

Application events need non-blocking, non-modal user feedback
for outcomes that do not warrant a dialog: file saved, profile
imported, operation failed, background task finished. The
current Flutter convention (`ScaffoldMessenger.showSnackBar`)
renders a single full-width bar at the bottom of the window,
blocks the status bar, uses severity-incorrect colours, and
dismisses previous notifications on every new event — a burst
of three events shows only the last one.

`workbench_shell` owns a notification center modelled on VS
Code's. Notifications render as stacked toast cards anchored to
the bottom-right of the workbench. Newest notification appears
at the bottom of the stack; older notifications shift upward as
new ones arrive. Each card carries a severity icon, message,
optional action buttons, and a close affordance. When two or
more cards are present, a "Clear All" control appears above the
stack.

**Dismissal policy by severity**:

- Info and success: auto-dismiss after 6 seconds unless the
  pointer is hovering the card. Hover pauses the timer; leaving
  resumes it.
- Warning and error: remain until the operator dismisses them,
  or the host invokes the programmatic dismiss API. VS Code
  uses the same rule — problems that need acknowledgement must
  not disappear on their own.
- Progress (indeterminate or determinate): remain until the
  host completes or cancels them.

**Why in `workbench_shell`**: the notification center is
generic workbench chrome. A non-Rove application building on
the shell needs the same stacked-toast affordance with the same
severity semantics. The boundary test applies: no host-specific
types cross the API.

**Why an injected service, not a widget API**: hosts should not
need to plumb `Overlay` or `GlobalKey`s. `NotificationService`
is a shell-provided service; hosts mount a single
`NotificationHost` widget inside `WorkbenchLayout` and call
`context.read<NotificationService>().show(...)` from anywhere
in the subtree. This mirrors `ScaffoldMessenger`'s ergonomics
without requiring a `Scaffold`.

**Why a stack rather than a queue**: a burst of events (three
file writes completing in quick succession) is not transient
noise the operator wants hidden — each event is a distinct
outcome the operator may need to see. Stacking preserves them;
a queue would hide all but the current one and defeat the
purpose of having a notification system at all.

**Theming**: `WorkbenchTheme` gains notification tokens — card
background, border radius, severity-keyed icon and accent
colours, action-button styles, close-button colour. No widget
reads host domain palettes directly. The severity palette reuses
existing `infoForeground`, `warningForeground`, `errorForeground`,
`successForeground` tokens rather than introducing parallel
ones.

**Boundary**: the service API accepts primitive types —
`NotificationSeverity` enum, `String` message, optional
`List<NotificationAction>` with label and callback. No domain
types, no BLoCs. `workbench_shell`'s Flutter-only dependency
footprint is preserved.

**Observable behavior**:

- Calling `NotificationService.show(severity, message)` causes
  a themed card to appear in the bottom-right within one frame.
- A second `show` call while the first is visible causes both
  to render, stacked vertically, with the second below the
  first.
- An info notification disappears automatically after 6 seconds
  of uninterrupted non-hover time; an error notification
  persists until the close button is tapped or `dismiss(id)` is
  called.
- The notification stack renders above all workbench surfaces
  (sidebar, editor, bottom panel, status bar) but below
  platform modals (dialogs, menus).
- When the stack exceeds five visible cards, older cards
  collapse into a "+N more" summary card that expands on tap.

---

## 11. Testing Strategy

*Status: complete*

The package uses `flutter_test` for widget-level coverage. Tests
exercise structural primitives, chrome widgets, layout constants,
theming controller, and the platform-agnostic bits of the menu
bar (platform-conditional code paths are gated by host-side
integration tests in consuming applications).

Each theme JSON asset ships with a regression test that asserts
the token map parses without diagnostics and resolves every
referenced `WorkbenchTheme` token.

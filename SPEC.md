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
of tab descriptors (stable id, label widget, content builder), an
`initialTabId`, an `onTogglePanel` callback for the close button,
and optional `onActiveTabChanged` / `onRegisterFocusTab` hooks so
the View menu and keyboard shortcuts can drive tab focus through
the same controller. `WorkbenchTheme` carries the tab strip
tokens (`panelBackground`, `tabBarLabelColor`,
`tabBarUnselectedLabelColor`, `tabBarIndicatorColor`,
`tabBarDividerColor`), so hosts no longer patch
`Theme.of(context).copyWith(tabBarTheme: …)` around the primitive.

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
"Panel" entry that toggles bottom-panel visibility and one static
entry per bottom-panel tab. Selecting a tab focuses it (showing
the panel first if hidden), or hides the panel if that tab is
already focused. The shell does not own tab content; the host
supplies tab descriptors and the focus-or-hide handler.

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
the descriptor model — `WorkbenchViewMenuTab` and the
`onSelectTab` contract are platform-agnostic.

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

`WorkbenchShortcuts` installs the keyboard bindings the View
menu displays, modeled on VS Code's defaults: Cmd/Ctrl+J toggles
the bottom panel, Ctrl+backquote focuses MDI (Ctrl on every
platform — matches VS Code's Terminal binding), Shift+Cmd/Ctrl+M
focuses Tasks (VS Code Problems), Shift+Cmd/Ctrl+Y focuses
Machine State (VS Code Debug Console), and Shift+Cmd/Ctrl+U
focuses Output. Bindings carry both Cmd and Ctrl activators
where VS Code's macOS default uses Cmd, so the macOS system menu
bar renders the Cmd glyph while Windows/Linux fire on Ctrl.

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

---

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

# Requirements

`workbench_shell` is a published Flutter package that renders VS
Code-style workbench chrome for host applications. This document
captures the problem space in the language of its users — the Flutter
developers who adopt the package — and the outcomes that define its
success. Solution design lives in [SPEC.md](SPEC.md); this document
stays in the problem space.

## Problem statement §req:problem-statement

**Target users** are Flutter developers building desktop (and mobile)
applications with VS Code-style IDE chrome — an activity bar, a
stacked sidebar of collapsible view panes, an editor area, a tabbed
bottom panel, a status bar, and a menu bar. Their apps span domains;
what they share is the shell around the content, not the content
itself. Rove is one such consumer among many; the package assumes no
particular host.

**The problem** is that every such app re-implements the same chrome,
and every re-implementation drifts. Section headers render at
different sizes across sidebars in the same app. Tab strips reinvent
their close affordance. Status bar items invent their own badge
geometry. The result looks IDE-adjacent rather than IDE-canonical, and
the visual grammar fragments as features land.

The cost compounds below the surface. Hosts re-implement not just how
the chrome *looks* but how it *behaves* — pane reordering, collapse
and expand, view visibility, drag-resize, and persisting all of that
across restarts. This is shell-internal mechanics (reconciling saved
state against changed content, splicing a reordered pane back into a
stack) leaking into every host, where it is written once per app and
maintained forever.

This problem is **frequent** (it appears in every IDE-style Flutter
app), **expensive** (repeated implementation plus a long tail of
drift and state-restoration bugs), and **growing** as Flutter desktop
adoption widens. Current alternatives fall short: rolling your own
chrome reproduces the drift and the plumbing; general-purpose Flutter
widget kits are not VS Code-canonical and make no promise of
cross-app consistency; and no shared artifact owns the canon so that
adopting it *prevents* drift rather than merely offering a starting
point.

## Success criteria §req:success-criteria

Success is measured first by **integration ease**: how little a host
must build, and how little shell mechanics it must reimplement, to
ship canonical chrome.

- A host renders a complete VS Code-style workbench — activity bar,
  sidebar, editor, bottom panel, status bar, menu bar — by adopting a
  single layout entry point and supplying content and a theme. It
  writes no chrome layout, typography, or spacing of its own.
- A host does not reimplement shell mechanics. Pane order, collapse
  and expand, view visibility, and drag-resize are owned by the shell
  and survive interaction without the host tracking them. A host that
  wants these preserved across application restarts serializes a
  shell-provided layout state and hands it back on next launch — it
  writes no logic to reconcile saved state against changed content and
  no logic to re-place a reordered pane.
- Two independent consumers render the same chrome element
  identically. Given the same content, section headers, tab strips,
  status bar items, and badges are visually indistinguishable across
  apps — no cross-consumer drift.
- The chrome is indistinguishable from VS Code across the surface the
  package covers, verifiable against a VS Code reference.
- The package depends only on Flutter and a small set of
  general-purpose libraries, verifiable by inspecting its
  dependencies. A host can enforce the same boundary — that no
  domain code leaks into the chrome — with a lint of its own.
- The chrome renders and behaves correctly on macOS, Windows, and
  Linux, with platform-correct affordances (a native menu bar on
  macOS, an in-window menu strip elsewhere).
- Keyboard shortcuts and focus traversal match VS Code defaults, so a
  user's IDE muscle memory carries over.

## User stories §req:user-stories

**Host developers** (the primary adopters):

- As a host developer, I want to render the whole workbench by
  supplying typed descriptors and my own content, so I get
  IDE-canonical chrome without designing any layout.
- As a host developer, I want the shell to own pane order, collapse,
  visibility, and resize, so a user's rearrangements persist through a
  session without me holding that state.
- As a host developer, I want to persist a user's sidebar arrangement
  across restarts by saving a shell-provided state value into my own
  storage and handing it back at startup, so I never write
  reconcile-on-load or pane-reorder logic — only "store these bytes."
- As a host developer, I want to theme the chrome — including loading
  existing VS Code color themes — so it matches my product's palette.
- As a host developer, I want the shell to stop me from breaking canon
  (lowercase headers, icons in tab labels, ad-hoc status badges) at
  the point I write the code, so my app cannot drift even by accident.

**End users** (of the host apps):

- As a user, I want keyboard shortcuts and focus behavior that match
  VS Code, so my habits transfer.
- As a user, I want my sidebar arrangement — pane order, which panes
  are collapsed, their sizes, and which views are hidden — to survive
  restarting the app.

## Quality attributes §req:quality-attributes

- **Canon fidelity and zero drift.** The chrome matches VS Code, and
  adopting the package *prevents* cross-consumer variation rather than
  merely enabling consistency — a host cannot render a canonical
  element non-canonically. This is the package's reason to exist; a
  permissive API that lets drift back in fails the requirement.
- **Cross-platform parity.** The chrome is correct on macOS, Windows,
  and Linux, and degrades sensibly on mobile. Platform conventions
  that users expect (the macOS menu bar living in the system bar, not
  in the window) are honored, not flattened.
- **Strict capability boundary.** The package carries no host domain
  types, no application state management, and no storage. It is
  chrome, theme, and layout only. A host's domain model and its
  persisted bytes never become the shell's concern; conversely, shell
  arrangement never becomes something the host must model.
- **Accessibility and keyboard parity.** Keyboard bindings, focus
  order, and pane navigation follow VS Code, and chrome carries the
  semantics assistive technology needs.
- **Responsiveness.** Chrome the user never opens costs nothing —
  a view container is built only when first shown, so adopting the
  full surface does not tax startup for parts a user never visits.

## Constraints §req:constraints

- Distributed as a Flutter package on pub.dev. Its dependency
  footprint is limited to Flutter and a few general-purpose libraries;
  no host- or domain-specific package appears in it.
- The package owns no storage. Persisting anything across restarts is
  the host's responsibility; the shell's role is to hand the host a
  serializable value and accept it back, not to write bytes.
- Form controls (text fields, dropdowns, toggles, action buttons) are
  out of scope, behind an explicit re-promotion gate.
- Editor content and hierarchical tree rows are host-supplied, not
  shell chrome.
- Governance is package-local: requirements and design describe the
  standalone published artifact, not any consuming application.

## Priorities §req:priorities

**Must have** — the canonical workbench baseline, already shipped:
activity bar and stacked sidebar, tabbed bottom panel, status bar,
platform-conditional menu bar, theming with VS Code theme loading,
structural primitives, and the notification center. This is the floor
the package's value rests on.

**Must have, ongoing** — the integration-ease seams that keep hosts
from reimplementing shell mechanics. Every persistable concern (pane
order, expansion, visibility, sizing, outer layout dimensions) is
exposed so a host can rehydrate to VS Code parity, and the shell — not
the host — owns the mechanics of applying that state. Reducing the
plumbing a host writes is a first-class, continuing goal, not a
finished one.

**Nice to have** — broader coverage of the VS Code workbench surface
as consumers need it, and re-promotion of deferred surfaces (custom
window chrome, tree rows, form controls) only when a concrete consumer
need clears their gate.

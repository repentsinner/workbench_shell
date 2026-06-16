# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Section-header Band and Rule §road:section-header-chrome

Render the VS Code section-header chrome on each view-pane header — a
filled background band and a 1px top rule — so stacked panes read as
distinct, canonical bars (§spec:view-stack).

### Render the section-header band and rule §road:render-header-chrome

Add nullable `sideBarSectionHeader.background` / `sideBarSectionHeader.border`
tokens to `WorkbenchTheme` (parsed from the VS Code theme JSON) and a
view-pane header height to `WorkbenchLayoutConstants`, and paint a header
background band plus a 1px top rule on `WorkbenchViewPane`, in
`lib/src/workbench_theme.dart` and `lib/src/workbench_content.dart`.
§spec:view-stack, §spec:theming, §spec:layout-constants.

**Verify:** Run the example; each Explorer view-pane header shows a
filled background band and a 1px top rule, themed (visible in the
bundled dark and light themes and changing on theme switch). A widget
test asserts the header paints its background and top border from the
tokens and that a null token suppresses each paint; `flutter analyze`
and `flutter test` pass.

## View Stack Container and Sidebar Inversion §road:view-stack-container

Give the shell the stacked view container: typed view descriptors
render as a flush stack of view panes with container-derived
collapsibility and a single shared scroll, and `WorkbenchLayout`'s
sidebar takes descriptors instead of a host-built widget
(§spec:view-stack). Sash-resize and drag-reorder are out of scope here
(staged, below).

### Build the view-stack container §road:view-stack-widget

Add a `WorkbenchViewContainer` that renders an ordered list of typed
view descriptors as a flush stack of `WorkbenchViewPane`s with no
inter-pane gap, derives each pane's collapsibility from the view count,
and provides one shared scroll region, in `lib/src/`. §spec:view-stack.
Depends on §road:render-header-chrome.

### Invert the WorkbenchLayout sidebar API §road:sidebar-api-inversion

Replace `WorkbenchLayout`'s `sidebarBuilder` → `Widget` slot with
per-container typed view descriptors rendered through
`WorkbenchViewContainer`, rename the section navigation to
view-container navigation, retire the host-set `collapsible` flag on
`WorkbenchViewPane` (now container-derived), and migrate the example
Explorer to view descriptors, in `lib/src/workbench_layout.dart`,
`lib/src/workbench_content.dart`, and `example/lib/main.dart`.
§spec:view-stack, §spec:section-disclosure, §spec:workbench-layout.
Depends on §road:view-stack-widget.

**Verify:** Run the example; the Explorer sidebar is a flush stack of
view panes built from typed view descriptors (the host supplies no
sidebar-body widget), separated by the header band and rule; collapsing
one pane redistributes its height to the sibling panes; one scroll
region covers overflow; a single-view container renders non-collapsible
(or merged); no `collapsible` flag is accepted from the host. `flutter
analyze` and `flutter test` pass and `flutter pub publish --dry-run` is
clean.

---

Staged for a later `/roadmap` pass (specced in §spec:view-stack, not yet
queued): **sash-resize** (drag the divider between two panes to
reapportion height) and **drag-reorder** (drag a header to reorder panes
within a container).

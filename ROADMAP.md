# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Container Title Source §road:container-title-source

Closes the §spec:view-container-title gap surfaced by #93: a view
container's composite title resolves only from `activityBarItems`, so a
container assigned to the secondary side bar (§spec:secondary-sidebar) —
which has no activity bar — renders a blank title strip.

### Spec-level container title §road:container-title-field

Add an optional `title` to `WorkbenchViewContainerSpec`
(`lib/src/workbench_view_container.dart`) and resolve the composite title
as `spec.title ?? _activeLabelFor(id)` where the layout builds the side bar
title (`lib/src/workbench_layout.dart:924`, `_buildSideBar`). The
activity-item label stays the default for primary containers; a
host-supplied `title` names any container independent of the activity bar
(§spec:view-container-title, §spec:secondary-sidebar).

**Verify:** In the example app assign a multi-view container to the
secondary side bar via `secondaryViewContainerId` without a `title`;
confirm the current blank strip, then set `WorkbenchViewContainerSpec.title`
and confirm the composite title renders it. Confirm a primary container with
no `title` still shows its activity-bar item label unchanged.

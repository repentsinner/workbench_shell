# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Section Header Actions §road:section-header-actions

Close the gap in §spec:section-header-actions: `WorkbenchSection`
has no inline action slot, so a host action strands on a row below
the title instead of sharing it (VS Code section-action parity).

### Add inline header actions §road:add-header-actions

`WorkbenchSection`'s header is `Row([Expanded(title), infoIcon?])`
with `child` rendered beneath, so an action passed via `child` sits
below the title rather than inline with it. Add an ordered `actions`
slot rendered inline on the header row, right of the title and
vertically centered with it; leave the `infoTooltip` affordance and
the no-actions layout unchanged. Reported in #24.

**Verify:** A widget test pumps a `WorkbenchSection` with one action
and asserts the action's vertical center equals the title's
(`actionY == titleY`) — inverting the MCVE in #24, which asserts
`actionY > titleY` today. `flutter analyze` and `flutter test` pass;
existing structural-primitive tests are unchanged when no actions
are supplied.

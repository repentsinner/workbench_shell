# workbench_shell Roadmap

Workstream queue for `workbench_shell`. Each section closes a
documented gap between the current implementation and SPEC.md.
Workstreams are sized to fit one agent session; rationale and
design decisions live in the cited spec sections, not here.

## Extraction Cleanup §road:extraction-cleanup

Code that migrated in from the Rove monorepo extraction but belongs
to the host, not the shell.

### Remove UI extension slots §road:remove-extension-slots

`SlotRegistry`, `SlotId`, `SidebarSlot`, and `SidebarZone` migrated
with the chrome during extraction. No shell widget consumes them —
the rendering integration they fed stayed in the host. Delete
`lib/src/slots/`, `test/slots/`, and the four slot exports in
`workbench_shell.dart`. The spec scope correction landed with the
triage PR; this workstream closes the code side of the gap.

Removing published API is breaking. semantic-release has no
bump-minor-pre-major, so a `!`-suffixed commit cuts v1.0.0; commit
as `feat: remove the UI extension-slot API` instead → v0.3.0,
matching pub.dev's pre-1.0 convention that minors may break.
Triaged from a maintainer report; no GitHub issue filed.

**Verify:** `grep -ri "SlotRegistry|SlotId|SidebarSlot|SidebarZone" lib test example`
returns nothing; `flutter analyze` and `flutter test` pass;
`flutter pub publish --dry-run` lists no `slots/` files.

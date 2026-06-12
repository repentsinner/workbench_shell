# Contributing

## How this repo handles PRs (Flywheel)

This repo uses [Flywheel](https://github.com/point-source/flywheel) to orchestrate PRs and releases. Read these rules before opening a PR — non-compliant PRs get labeled `flywheel:needs-review` and stall.

**How releases happen here.** You don't cut releases manually. A release is published automatically when you merge a PR whose title bumps the version: `feat:` (minor), `fix:` / `perf:` (patch), or anything `!`-suffixed (major). Non-bumping types (`chore`, `style`, `docs`, `test`, `ci`, `build`, `refactor`) accumulate silently and ship with the next qualifying PR. There is no `git tag`, no "release" button, no `release` workflow you trigger by hand.

**Target branch.** Open all PRs against `main`. It is the only managed branch.

**PR title format.** Must be a [Conventional Commit](https://www.conventionalcommits.org/): `<type>(<optional scope>): <description>`. Recognized types: `feat`, `fix`, `chore`, `refactor`, `perf`, `style`, `test`, `docs`, `build`, `ci`, `revert`. Append `!` for breaking changes (e.g. `feat!: rename foo to bar`). Flywheel will rewrite a malformed title, but getting it right first time avoids re-runs.

**One logical change per PR.** Flywheel derives the version bump from the title, so squashing two unrelated `feat`s into one PR loses one of them in the release notes.

**Branch naming.** Use `<type>/<short-kebab-description>` (e.g. `feat/panel-resize-handle`, `fix/null-deref-on-empty-list`).

**Closing linked issues.** If this PR fixes a tracked issue, include a `Closes #N` trailer in the PR body (or `Fixes #N` / `Resolves #N` — all three are recognised, case-insensitive). Flywheel preserves these trailers when it rewrites the PR body. The trailing `(#N)` GitHub appends to a squash-merge title is **not** a closing reference — without an explicit keyword, the issue stays open. AI agents authoring PRs: when the work resolves an issue, always include the trailer; do not rely on the title parenthetical.

**Auto-merge eligibility on `main`.** PRs whose title type is in `[chore, docs, style, test, ci, build, refactor]` get labeled `flywheel:auto-merge` and merge automatically once required checks pass. Any other type — `feat`, `fix`, `perf`, and every `!`-suffixed breaking variant — routes to human review and waits for an approval.

**Required status checks.** Your PR must pass `quality` (Flutter analyze + package and example tests) and the governance lint before merging. Run them locally before pushing:

```bash
flutter analyze && flutter test && (cd example && flutter test)
npx markdownlint-cli2 SPEC.md ROADMAP.md README.md
```

**Open PRs only when ready to merge.** A branch is your private work-in-progress; a PR is a request to merge. Iterate on the branch beforehand; open the PR when the work is done. Once open and eligible, Flywheel auto-merges as soon as required checks pass.

**One PR per branch; the branch dies on merge.** After your PR lands on `main`, the branch is done. Cut a new branch off the latest `main` for your next change. The remote branch is deleted automatically on merge; reusing a stale local copy causes phantom rebase conflicts.

**Things you must not do:**

- Do not push to or force-push `main`; it is protected.
- Do not create version tags (`v1.2.3`, etc.). Only Flywheel's GitHub App may mint them.
- Do not edit a PR's title or body after Flywheel has rewritten them — push a new commit with the corrected conventional-commit message instead.
- Do not edit `pubspec.yaml`'s `version:` line or add CHANGELOG entries for unreleased work — Flywheel writes both on release.

**If your PR was labeled `flywheel:needs-review` and you expected `flywheel:auto-merge`:** the title's commit type is not in `main`'s `auto_merge` list, or you used a breaking variant (`chore!`) when only the non-breaking variant (`chore`) is allowed. Check `.flywheel.yml`.

## Governance documents

SPEC.md (declarative, the desired end state), ROADMAP.md (imperative, the
work queue), and CHANGELOG.md (what shipped) follow the
[symphonize notation contract](https://github.com/repentsinner/symphonize).
Headings carry `§spec:`/`§road:` slugs; reference sections by slug, never
by position. CI enforces this via the governance-lint workflow.

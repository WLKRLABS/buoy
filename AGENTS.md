# Repository Agent Notes

## Scope

- This repo ships a macOS CLI and native app wrapper for Buoy.
- `VERSION` is the single source of truth for the CLI, app bundle, tags, and release assets.
- Release automation is tag-driven through `.github/workflows/release.yml`.

## Working Rules

- Treat `VERSIONING.md` and `CONTRIBUTING.md` as the release policy.
- Update `CHANGELOG.md` for user-visible CLI, app, installer, or README changes.
- Do not bump `VERSION` during normal feature work. Bump it only in release prep.
- Build with the repo scripts, not ad hoc `swiftc` commands, when validating a release.
- Install locally with `./install.sh` when the user asks to update the machine’s installed Buoy copy.

## Release Shortcut

- For future Buoy releases, consult [release-buoy skill](./.codex/skills/release-buoy/SKILL.md).
- Default release flow:
  1. Make sure `CHANGELOG.md` is updated under `## [Unreleased]`.
  2. Run `./scripts/release.sh prepare X.Y.Z`.
  3. Run `./install.sh` when the user asks to update the local machine copy.
  4. Commit release prep as `release: vX.Y.Z`.
  5. Run `./scripts/release.sh tag`, then push branch and tag.
  6. Verify the GitHub release workflow published assets.

## Linear work queue

- Team: **WLKR LABS**.
- Project: [Buoy](https://linear.app/wlkr-labs/project/buoy-08c696a32d5f).
- Linear is the task source of truth. Existing GitHub issues and Markdown plans are historical context; this section supersedes older tracker or backlog guidance.
- Before starting substantive work, read the Linear issue and discussion and check for existing work. Find or create a Linear issue for substantive user-requested work, not every question or minor action.
- Keep status current, include the issue ID in branches and PRs, and post concise outcomes or blockers. Mark Done only when completion criteria are met.
- Do not maintain a competing Markdown backlog or import or sync GitHub issues.

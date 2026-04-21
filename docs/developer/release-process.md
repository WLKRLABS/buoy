# Release Process

## Audience

Maintainers preparing and shipping a Buoy release.

## Purpose

Document the release-prep workflow, tag rules, and GitHub Actions handoff in one place.

## Release Sources Of Truth

- `VERSION`
  Purpose: current product version
- `CHANGELOG.md`
  Purpose: user-visible release history
- `.github/workflows/release.yml`
  Purpose: tag-triggered release automation

## Rules Before You Begin

- do not bump `VERSION` in normal feature work
- make sure `CHANGELOG.md` already contains the relevant `Unreleased` entries
- release tags must be `vX.Y.Z`
- the tag must match `VERSION`
- release tags must point at a commit named `release: vX.Y.Z`

## Standard Release Flow

1. Confirm `main` is stable and CI is green.
2. Pick the next version from `VERSIONING.md`.
3. Run:

```bash
./scripts/release.sh prepare X.Y.Z
```

This command:

- moves the current `Unreleased` changelog body into `## [X.Y.Z] - YYYY-MM-DD`
- resets `Unreleased` to empty release headings
- updates `VERSION`
- runs version validation, smoke checks, CLI build, app build, packaging, packaged-release verification, and release-notes rendering

4. Install the release locally if you need to update the current machine:

```bash
./install.sh
```

5. Review the diff, then commit the release prep with:

```bash
git commit -m "release: vX.Y.Z"
```

6. Tag the release with:

```bash
./scripts/release.sh tag
```

The tag command refuses to run unless:

- the worktree is clean
- `CHANGELOG.md` and `VERSION` still validate
- `HEAD` is a commit named `release: vX.Y.Z`

7. Push the branch and tag.
8. Let GitHub Actions publish the release assets.
9. Verify the published release and assets.

## Release Assets

Current packaged assets:

- `buoy`
- `Buoy.app.zip`
- `install.sh`
- `SHA256SUMS.txt`

Produced by:

- `scripts/package-release.sh`

## Release Notes

Release notes are rendered from the current version section in `CHANGELOG.md`.

Command:

```bash
./scripts/render-release-notes.sh
```

Template reference:

- `.github/release-notes.md`

## GitHub Release Workflow

Trigger:

- push of tag matching `v*.*.*`

Current steps:

- validate version and tag match
- validate the release commit subject
- build release assets
- verify packaged release assets
- render release notes
- publish a GitHub release with attached files

Source:

- `.github/workflows/release.yml`

## What To Verify After Push

- the tag matches `VERSION`
- the GitHub release exists
- `buoy` is attached
- `Buoy.app.zip` is attached
- `install.sh` is attached
- `SHA256SUMS.txt` is attached
- release notes match the changelog section you intended to ship

## Current Release Constraints

- build scripts compile native binaries for the build host
- the current repo ships non-notarized GitHub release downloads
- current release automation is tag-driven, not branch-driven

## Related Docs

- [Versioning Policy](../../VERSIONING.md)
- [Changelog Guide](../changelog.md)
- [Testing](testing.md)

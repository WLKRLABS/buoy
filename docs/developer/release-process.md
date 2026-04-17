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

## Standard Release Flow

1. Confirm `main` is stable and CI is green.
2. Move release-ready bullets from `Unreleased` into a new versioned section in `CHANGELOG.md`.
3. Update `VERSION`.
4. Run:

```bash
bash scripts/validate-versioning.sh
./scripts/smoke-test.sh
./scripts/build-cli.sh
./scripts/build-app.sh
./scripts/package-release.sh
./scripts/render-release-notes.sh
```

5. Install the release locally if you need to update the current machine:

```bash
./install.sh
```

6. Commit the release prep.
7. Tag the release:

```bash
git tag vX.Y.Z
```

8. Push the branch and tag.
9. Let GitHub Actions publish the release assets.
10. Verify the published release and assets.

## Release Assets

Current packaged assets:

- `buoy`
- `Buoy.app.zip`

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
- build release assets
- render release notes
- publish a GitHub release with attached files

Source:

- `.github/workflows/release.yml`

## What To Verify After Push

- the tag matches `VERSION`
- the GitHub release exists
- `buoy` is attached
- `Buoy.app.zip` is attached
- release notes match the changelog section you intended to ship

## Current Release Constraints

- build scripts compile native binaries for the build host
- the current repo shows signing but no notarization step
- current release automation is tag-driven, not branch-driven

## Related Docs

- [Versioning Policy](../../VERSIONING.md)
- [Changelog Guide](../changelog.md)
- [Testing](testing.md)

# Versioning Policy

This repo uses Semantic Versioning with a lightweight public-release process.

## Current State

- Current version source of truth: `VERSION`
- Current release line: pre-1.0
- First formal release: `0.1.0`
- Stable target model: `1.0.0`

## What Counts As Public Surface

For Buoy, the public contract is:

- CLI behavior and flags
- installer behavior
- `Buoy.app` behavior
- release assets and install flow
- documented operational behavior in `README.md`
- user and developer behavior documented in `docs/`

If a change alters one of those surfaces, it should be reflected in the version bump and changelog.

## Version Strategy

`VERSION` is the single source of truth for:

- the CLI version output
- `Buoy.app` bundle version
- release tags
- changelog release sections
- CI validation

Only plain `X.Y.Z` versions are allowed. No extra formatting, prefixes, or metadata in `VERSION`.

## Bump Rules

### While pre-1.0

- `PATCH` for fixes, wording cleanup, packaging fixes, non-breaking installer fixes, and safe internal refactors
- `MINOR` for new CLI commands, new app actions, new installer capabilities, or backward-compatible behavior additions
- `MAJOR` for breaking changes to flags, command behavior, config/state compatibility, installer expectations, or app behavior contracts

Before `1.0.0`, breaking changes are allowed, but they must be called out explicitly in `CHANGELOG.md` and release notes.

### After 1.0.0

- `PATCH` for backward-compatible fixes only
- `MINOR` for backward-compatible additions
- `MAJOR` for breaking changes

## CHANGELOG Strategy

- Keep one top-level `Unreleased` section
- Add one dated section per released version
- Write for users and future-you, not for Git internals
- Prefer short bullets under `Added`, `Changed`, `Fixed`, and `Removed`
- If a release includes a breaking change, say so plainly in the version section

## Contributor Rules For Version Bumps

When a pull request changes the public surface:

1. Decide the bump level before merge.
2. Update `CHANGELOG.md` under `Unreleased` during the PR.
3. Do not change `VERSION` in normal feature PRs.
4. Change `VERSION` only in the release-prep commit or PR.
5. Make sure the released version section in `CHANGELOG.md` matches the new `VERSION`.

If a PR is internal-only and does not affect the public surface, it does not need a changelog entry.

## Release Process

1. Confirm `main` is stable and CI is green.
2. Make sure `CHANGELOG.md` has the release-ready bullets under `Unreleased`.
3. Run:

```bash
./scripts/release.sh prepare X.Y.Z
```

4. Review the diff and commit the release prep with `release: vX.Y.Z`.
5. Create the tag with:

```bash
./scripts/release.sh tag
```

6. Push the commit and tag.
7. Let GitHub Actions build assets and publish the release from the tag.

See also:

- [docs/developer/release-process.md](docs/developer/release-process.md)
- [docs/changelog.md](docs/changelog.md)

## CI Validation Logic

CI must fail when:

- `VERSION` is missing or not valid `X.Y.Z`
- `CHANGELOG.md` does not contain `Unreleased`
- `CHANGELOG.md` does not contain a section for the current `VERSION`
- the built CLI version does not match `VERSION`
- the app or packaged release assets fail to build

## Release Notes Template

Use `.github/release-notes.md` for manual drafting. Automated GitHub releases render notes from the current version section in `CHANGELOG.md`.

## Recommendation

Do not release `1.0.0` yet.

This repo is close to a first public release, but versioning, CI, and release handling are only now being formalized. The right move is to ship `0.1.0`, prove one clean release cycle, then promote to `1.0.0` once the public surface is intentionally stable and release operations are routine.

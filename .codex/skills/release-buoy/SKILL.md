---
name: release-buoy
description: Prepare and ship a new Buoy release after repo changes by updating VERSION and CHANGELOG, running the repo validation/build/package flow, installing the new local copy, tagging the release, pushing it, and verifying the GitHub release workflow.
---

# Release Buoy

Use this workflow when changes in this repo are ready to become a tagged Buoy release.

## Read First

- `VERSIONING.md`
- `CONTRIBUTING.md`
- `CHANGELOG.md`
- `scripts/release.sh`
- `scripts/validate-versioning.sh`
- `scripts/package-release.sh`
- `scripts/render-release-notes.sh`

## Release Rules

- `VERSION` must stay plain `X.Y.Z`.
- Keep `## [Unreleased]` at the top of `CHANGELOG.md`.
- Only bump `VERSION` during release prep.
- Tag format must be `vX.Y.Z` and must match `VERSION`.
- Release assets are published by pushing the tag and letting GitHub Actions run `.github/workflows/release.yml`.

## Required Steps

1. Confirm the worktree only contains the intended release changes.
2. Decide the SemVer bump from `VERSIONING.md`.
3. Make sure `CHANGELOG.md` contains the intended user-visible bullets under `## [Unreleased]`.
4. Run:

```bash
./scripts/release.sh prepare X.Y.Z
./install.sh
```

5. Verify:

```bash
./dist/buoy version
$HOME/.local/bin/buoy version
test -f dist/release/buoy
test -f dist/release/Buoy.app.zip
```

6. Review the final diff and staged changes.
7. Commit with a release-prep message such as `release: vX.Y.Z`.
8. Create the annotated tag:

```bash
./scripts/release.sh tag
```

9. Push the branch and tag:

```bash
git push origin main
git push origin vX.Y.Z
```

10. Verify the GitHub release workflow succeeded and that the release contains:

- `dist/release/buoy`
- `dist/release/Buoy.app.zip`
- release notes rendered from the matching `CHANGELOG.md` section

## Safety Checks

- Do not tag if validation or packaging fails.
- Do not leave `VERSION` bumped without also updating the matching changelog section.
- Do not tag unless `HEAD` is already committed as `release: vX.Y.Z`.
- Do not push a release tag before the release-prep commit is on the remote branch.

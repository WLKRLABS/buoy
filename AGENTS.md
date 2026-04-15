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
  1. Update `CHANGELOG.md` and `VERSION`.
  2. Run `bash scripts/validate-versioning.sh`.
  3. Run `./scripts/smoke-test.sh`.
  4. Run `./scripts/build-cli.sh`.
  5. Run `./scripts/build-app.sh`.
  6. Run `./scripts/package-release.sh`.
  7. Run `./scripts/render-release-notes.sh`.
  8. Run `./install.sh`.
  9. Commit release prep, tag `vX.Y.Z`, push branch and tag.
  10. Verify the GitHub release workflow published assets.

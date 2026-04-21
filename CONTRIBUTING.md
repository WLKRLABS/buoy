# Contributing

Full contributor documentation lives in [docs/developer/contributing.md](docs/developer/contributing.md).

## Release Hygiene

- If you change CLI flags, CLI behavior, installer behavior, app behavior, or public docs in `README.md` or `docs/`, add a short bullet to `CHANGELOG.md` under `Unreleased`.
- Do not bump `VERSION` in normal feature PRs.
- Bump `VERSION` only when preparing an actual release.
- Use `./scripts/release.sh prepare X.Y.Z` and `./scripts/release.sh tag` for release prep instead of manual version and tag commands.
- If your change is breaking, call it out clearly in the changelog.

## Before Opening A PR

Run:

```bash
bash scripts/validate-versioning.sh
./scripts/smoke-test.sh
./scripts/build-cli.sh
./scripts/build-app.sh
./scripts/test-storage-scanner.sh
./scripts/test-storage-cache.sh
./scripts/package-release.sh
./scripts/verify-release.sh
bash -n install.sh scripts/*.sh buoy
```

## Release Tags

- Release tags must be `vX.Y.Z`
- The tag must match the contents of `VERSION`
- GitHub Actions publishes release assets from the tag

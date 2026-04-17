# Contributing

Full contributor documentation lives in [docs/developer/contributing.md](docs/developer/contributing.md).

## Release Hygiene

- If you change CLI flags, CLI behavior, installer behavior, app behavior, or public docs in `README.md` or `docs/`, add a short bullet to `CHANGELOG.md` under `Unreleased`.
- Do not bump `VERSION` in normal feature PRs.
- Bump `VERSION` only when preparing an actual release.
- If your change is breaking, call it out clearly in the changelog.

## Before Opening A PR

Run:

```bash
bash scripts/validate-versioning.sh
./scripts/build-cli.sh
./scripts/build-app.sh
./scripts/smoke-test.sh
./scripts/test-storage-scanner.sh
./scripts/test-storage-cache.sh
```

## Release Tags

- Release tags must be `vX.Y.Z`
- The tag must match the contents of `VERSION`
- GitHub Actions publishes release assets from the tag

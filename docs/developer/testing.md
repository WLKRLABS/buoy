# Testing

## Audience

Developers validating Buoy changes locally or in CI.

## Purpose

Document the current test model and the commands that matter for safe changes.

## Important Context

Buoy is not using a standard Swift Package Manager test target in the current repo.

Instead, the repository uses:

- build scripts
- smoke checks
- standalone Swift test entrypoints compiled by shell scripts
- GitHub Actions validation

## Fast Validation

Run:

```bash
bash scripts/validate-versioning.sh
./scripts/smoke-test.sh
```

What this covers:

- `VERSION` and `CHANGELOG.md` consistency
- expected source files and script presence

## Build Validation

Run:

```bash
./scripts/build-cli.sh
./scripts/build-app.sh
./scripts/package-release.sh
```

What this covers:

- CLI build
- app build
- release packaging shape

## Storage Tests

Run:

```bash
./scripts/test-storage-scanner.sh
./scripts/test-storage-cache.sh
```

What these cover:

- storage scan mode behavior
- protected-scope normalization
- residual system estimate behavior
- cache round trips and invalidation rules

## Manual CLI Checks

Useful commands:

```bash
./dist/buoy version
./dist/buoy doctor
./dist/buoy status --json
./dist/buoy apply --dry-run
./dist/buoy screen-off --dry-run
```

Use dry runs whenever the command would otherwise make a privileged machine change.

## Shell Script Checks

When you touch shell scripts, run:

```bash
bash -n install.sh scripts/*.sh buoy
```

## CI Coverage

Current CI workflow:

- validates versioning
- runs smoke checks
- lints shell syntax
- builds the CLI
- verifies CLI version
- runs `doctor` and `status --json`
- builds the app
- packages release assets
- checks packaged release outputs

Source:

- `.github/workflows/ci.yml`

## Testing Gaps To Keep In Mind

- no automated UI test suite is present in the current repo
- no formal docs lint step is present in CI
- no automated notarization or distribution validation step is shown

## Recommended Change-Based Testing

- power-behavior changes:
  - `./dist/buoy status --json`
  - `./dist/buoy apply --dry-run`
  - app `Power` refresh
- storage changes:
  - both storage test scripts
  - manual Storage tab verification
- build or packaging changes:
  - CLI build
  - app build
  - package release

## Related Docs

- [Build And Run](build-and-run.md)
- [Release Process](release-process.md)

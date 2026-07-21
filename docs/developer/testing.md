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
./scripts/verify-release.sh
```

What this covers:

- CLI build
- app build
- release packaging shape
- packaged installer and asset verification

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

## Power State Tests

Run:

```bash
./scripts/test-power-state.sh
```

What this covers:

- immediate On or Off ownership independent of persistent policy health
- separation of persistent sleep policy from temporary macOS assertions
- Off repair of `SleepDisabled` and system `sleep=Never` on AC and battery
- exact preservation of the independent display-sleep preference, including `displaysleep=0`
- restore verification before Buoy clears its recovery state
- assertion-only activity remaining informational, including successful Off and lid-close behavior

## Manual CLI Checks

Useful commands:

```bash
./dist/buoy version
./dist/buoy doctor
./dist/buoy status --json
./dist/buoy apply --dry-run
./dist/buoy off --dry-run
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
- runs power state reconciliation tests
- runs storage test scripts
- verifies the packaged release installer and assets

Source:

- `.github/workflows/ci.yml`

## Testing Gaps To Keep In Mind

- no automated UI test suite is present in the current repo
- immediate mode-switch behavior and failed-command switch rollback require manual app verification
- no formal docs lint step is present in CI
- no automated notarization step is present in the current repo

## Recommended Change-Based Testing

- power-behavior changes:
  - `./scripts/test-power-state.sh`
  - `./dist/buoy status --json`
  - `./dist/buoy apply --dry-run`
  - `./dist/buoy off --dry-run`
  - app `Power` On/Off switch, `Apply Settings`, failure rollback, and refresh
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

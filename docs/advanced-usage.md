# Advanced Usage

## Audience

Power users, maintainers, and automation tools using Buoy beyond the default app flow.

## Purpose

Document CLI-centric usage, environment-driven defaults, state-path overrides, and script-friendly patterns.

## JSON Output

Use JSON when you need stable field names.

Commands:

```bash
buoy status --json
buoy doctor --json
```

Use cases:

- local scripting
- support collection
- external automation

## Dry Runs

Use dry runs before privileged changes.

Examples:

```bash
buoy apply --dry-run --display-sleep 5
buoy off --dry-run
buoy screen-off --dry-run
buoy install --dry-run --target-dir /tmp/buoy-test
```

## Environment Variable Defaults

The CLI reads these defaults when matching flags are omitted:

- `BUOY_DISPLAY_SLEEP`
- `BUOY_CLAM_MIN_BATTERY`
- `BUOY_CLAM_POLL_SECONDS`

Example:

```bash
BUOY_DISPLAY_SLEEP=15 BUOY_CLAM_MIN_BATTERY=35 buoy apply --clam
```

## Override The State Directory

Use `BUOY_STATE_DIR` to move the Buoy state directory.

Example:

```bash
BUOY_STATE_DIR=/tmp/buoy-state buoy status --json
```

What this changes:

- the location of `state.json`
- the state file used by the closed-lid helper

Use this carefully. `buoy off` can only restore from the state file it sees.

## Install The Current Executable Somewhere Else

Use:

```bash
buoy install --target-dir /custom/bin
```

Purpose:

- copy the current CLI binary into another location

## Update Your Shell PATH

Use:

```bash
buoy path-add
```

What it does:

- detects the current shell profile
- appends the project path if it is not already present

## Use The App And CLI Together

A practical operator pattern:

1. apply or inspect with the CLI
2. open `Buoy.app` for live system context
3. return to `status --json` when you need machine-readable output

## Storage Power-User Notes

- summary refresh is designed for speed, not full file detail
- deep scan is the only current path that refreshes the largest-file list from live data
- saved storage grants are tied to an access fingerprint; changing grants invalidates the cache on purpose

## State And Cache Paths

Primary local paths:

- state: `~/.buoy/state.json`
- storage cache: `~/Library/Application Support/Buoy/storage-scan-cache.json`

## Installer Environment Variables

Useful for scripted installs:

- `BIN_DIR`
- `APP_DIR`
- `DOWNLOAD_REPO`
- `DOWNLOAD_REF`
- `DOWNLOAD_RELEASES`

Example:

```bash
BIN_DIR="$HOME/bin" APP_DIR="$HOME/Apps" ./install.sh
```

## Local Build Signing

If you rebuild the app often and want stable local signing:

```bash
./scripts/setup-local-signing.sh
./scripts/build-app.sh
```

Purpose:

- create a local self-signed identity
- keep the app bundle identity stable across local rebuilds

## Caveats

- the CLI is the power-state source of truth
- deleting the state file removes the saved restore point
- current build scripts compile native binaries for the build host

## See Also

- [Settings Reference](settings-reference.md)
- [Privacy And Permissions](privacy-and-permissions.md)
- [Developer Build And Run](developer/build-and-run.md)

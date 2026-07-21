# Troubleshooting

## Audience

Users and maintainers diagnosing installation, power-control, or dashboard problems.

## Purpose

Map common symptoms to likely causes and the fastest checks to run first.

## Start Here

Run these commands before changing anything else:

```bash
buoy doctor
buoy status --json
```

If Buoy itself does not run, start with the install and PATH issues below.

## Buoy Command Not Found

### Likely Causes

- `buoy` was installed into `~/.local/bin` but that directory is not on `PATH`
- install failed before copying the CLI

### Checks

```bash
ls ~/.local/bin/buoy
echo "$PATH"
```

### Fixes

- run `buoy path-add` if `buoy` already exists but is not on `PATH`
- rerun `./install.sh` or the remote install command if the binary is missing

## App Shows `Status Unavailable`

### Likely Causes

- the app cannot find or run the installed CLI
- `buoy status --json` returned invalid output or failed

### Checks

```bash
buoy status --json
```

### Fixes

- reinstall Buoy
- confirm the CLI works from Terminal first
- relaunch the app after reinstalling

## Mode Switch, Apply Settings, Or Turn Off Fails

### Likely Causes

- administrator authentication was denied
- `pmset` failed
- the CLI is missing from the path the app resolved

### Checks

```bash
buoy apply --dry-run
buoy status
```

### Fixes

- retry and complete the macOS admin prompt
- run the same action in Terminal to inspect the exact error
- confirm `pmset` is available with `buoy doctor`

## Status Shows A Persistent Sleep Policy Problem Or Configuration Mismatch

### Likely Causes

- `SleepDisabled` is still `1`
- an AC or battery system `sleep` timer is set to `0` (`Never`)
- a managed AC value drifted after Buoy was applied
- the closed-lid helper stopped

### Checks

```bash
ls ~/.buoy/state.json
buoy status
```

### Fixes

- inspect `Mode issues`, `Sleep policy`, `SleepDisabled`, and the AC and battery system-sleep timers in `buoy status`
- run `buoy off` or click `Turn Off`; Off clears `SleepDisabled` and repairs blocking system-sleep timers even without a usable restore point
- when a recovery record exists, Buoy keeps it if restoration cannot be verified and reports the exact persistent policy problem

Buoy mode remains On or Off according to Buoy ownership. A persistent policy warning does not replace that mode label.

The display-sleep timer is reported separately. `displaysleep=0` means the display stays on until another action turns it off; it does not prevent system sleep and is not a policy-repair warning.

## Status Shows A Temporary Wake Request While Mode Is Off

### Meaning

- an app or macOS currently has a power assertion
- the request is activity, not Buoy ownership or a persistent sleep setting

### What To Do

- inspect `Temporary wake requests` in `buoy status`
- wait for the task to finish or close the owning app if you need idle sleep immediately
- do not repeatedly run `buoy off`; temporary requests do not make Off fail

`PreventUserIdleSystemSleep` may delay idle sleep while it is active. It does not disable lid-close sleep when `SleepDisabled=0`.

## Closed-Lid Monitor Shows Stopped

### Likely Causes

- the helper process was killed externally
- the saved helper PID is stale

### Checks

```bash
buoy status
```

Look for:

- `Closed-lid monitor: not running`

### Fixes

- reapply the current configuration:

```bash
buoy apply --clam
```

## Storage Scan Skips Folders

### Likely Causes

- the folder is protected and Buoy does not have a saved grant
- the path timed out or could not be scanned

### Checks

- open `Storage`
- review `Access Grants`
- check the status line for skipped protected paths

### Fixes

- enable and grant the protected folder
- run `Refresh Summary` again
- run `Deep Scan` only after the access state is correct

## Storage Page Stays On `Partial Scan`

### What It Means

- Buoy has summary data but no current deep-scan file list

### Fixes

- click `Deep Scan`
- wait for the scan to finish

If it still stays partial:

- clear or change access grants only if needed
- reopen the `Storage` tab and watch whether the scan starts

## Storage Results Feel Old Or Cached

### Likely Causes

- Buoy loaded a cached snapshot for speed
- cached data became stale before the tab was opened

### Fixes

- click `Refresh Summary`
- run `Deep Scan` if you need fresh largest-file results

## macOS Warns When Opening The App

### Likely Causes

- the current release flow does not notarize GitHub downloads
- the app bundle still has quarantine or trust warnings

### Checks

- confirm whether the app was installed via `install.sh`

### Fixes

- prefer `install.sh`, which clears extended attributes on the installed app when possible
- if you built locally, use `scripts/setup-local-signing.sh` for a stable local signing identity
- use standard macOS review-and-open behavior for non-notarized downloads when Gatekeeper blocks first launch

## Battery, Wattage, Or Thermal Values Are Unavailable

### Likely Causes

- the machine has no battery
- the system does not expose that value
- CPU temperature is intentionally unavailable in the current Apple silicon path

### Fixes

- treat missing battery values as normal on desktop Macs
- rely on thermal pressure if CPU temperature is unavailable

## Build From Source Fails

### Likely Causes

- Xcode command-line tools are missing or unhealthy
- `swiftc` or the active SDK path is unavailable

### Checks

```bash
xcrun --find swiftc
xcrun --show-sdk-path
./scripts/build-cli.sh
./scripts/build-app.sh
```

### Fixes

- repair or reinstall the Apple toolchain
- use the repo scripts rather than ad hoc `swiftc` commands

## Remote Install Falls Back To Source Build

### What It Means

- release assets could not be downloaded, so `install.sh` fetched the source archive instead

### Checks

- read the installer output
- confirm `DOWNLOAD_REPO` points at the intended repository

### Fixes

- rerun with the correct `DOWNLOAD_REPO`
- set `DOWNLOAD_RELEASES=0` only when you want to force a source build

## Still Stuck

Collect this before escalating:

```bash
buoy doctor --json
buoy status --json
```

Then note:

- how Buoy was installed
- whether the problem happens in the CLI, the app, or both
- whether the issue affects power control, dashboard metrics, or storage access

## See Also

- [Installation](installation.md)
- [Advanced Usage](advanced-usage.md)
- [Machine Troubleshooting Map](machine/troubleshooting-map.json)

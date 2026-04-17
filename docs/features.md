# Features

## Audience

Users comparing Buoy capabilities or learning what each feature is for.

## Purpose

Describe the major product features in a stable, task-oriented format.

## Feature: Buoy Mode

### What It Is

A reversible AC power profile managed by `buoy apply` and `buoy off`.

### Why It Matters

It keeps a plugged-in Mac awake for server-like use without forcing the display to stay on.

### Where To Find It

- CLI: `buoy apply`, `buoy off`, `buoy status`
- App: `Power` section

### How To Use It

```bash
buoy apply
buoy off
```

### Edge Cases And Limits

- Buoy stores the restore point in `~/.buoy/state.json`.
- If that state is missing, `buoy off` cannot restore the original AC profile.
- Buoy manages AC settings, not a broad set of battery-only policies.

## Feature: Configurable Display Sleep

### What It Is

A `display sleep` value that stays separate from full idle sleep.

### Why It Matters

You can keep the machine awake on AC while still letting the screen sleep.

### Where To Find It

- CLI: `buoy apply --display-sleep MINUTES`
- App: `Power` section slider

### How To Use It

```bash
buoy apply --display-sleep 5
```

### Edge Cases And Limits

- Allowed range in the current source: `1` to `180` minutes.

## Feature: Closed-Lid Awake Mode

### What It Is

An optional helper-driven mode that manages `SleepDisabled` while the Mac is charging or above a configured battery floor.

### Why It Matters

It supports closed-lid use without forcing the machine to stay awake indefinitely on battery.

### Where To Find It

- CLI: `--clam`, `--clam-min-battery`, `--clam-poll-seconds`
- App: `Power` section

### How To Use It

```bash
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 15
```

### Edge Cases And Limits

- It uses a helper process.
- If that helper is killed, the mode can drift until you reapply Buoy.
- Allowed ranges in the current source:
  - battery floor: `0` to `100`
  - poll interval: `5` to `3600` seconds

## Feature: Native Power Control Surface

### What It Is

A native AppKit screen that controls the CLI instead of replacing it.

### Why It Matters

You get explicit controls and live feedback without losing the scriptable CLI contract.

### Where To Find It

- App: `Power` section

### How To Use It

- set the toggles and sliders
- click `Apply`
- click `Turn Off` to restore
- click `Refresh` to re-read status from the CLI

### Edge Cases And Limits

- `Apply` and `Turn Off` trigger the macOS administrator prompt.
- `Sleep Display` is non-destructive and does not change Buoy mode.

## Feature: Live Dashboard

### What It Is

A multi-section dashboard for Overview, System, Processes, Services, Network, and Storage.

### Why It Matters

It lets you inspect the machine state without switching between several terminal commands.

### Where To Find It

- App sidebar

### How To Use It

- use `Overview` for fast orientation
- use `System` for exact live readouts
- use `Processes`, `Services`, and `Network` for targeted inspection

### Edge Cases And Limits

- Some metrics can be unavailable depending on hardware or OS access.
- CPU temperature is intentionally unavailable in the current Apple silicon implementation.

## Feature: Storage Summary Refresh

### What It Is

A fast storage scan that populates the Storage tab without running a full largest-files enumeration.

### Why It Matters

It makes the Storage tab useful quickly and avoids blocking the interface.

### Where To Find It

- App: `Storage` section, `Refresh Summary`

### How To Use It

- open the `Storage` section
- let Buoy load cached data or a seed state
- click `Refresh Summary` for a fast live refresh

### Edge Cases And Limits

- summary mode can show `Partial Scan`
- largest files stay unavailable until a deep scan completes unless a previous deep snapshot exists

## Feature: Storage Deep Scan

### What It Is

A slower scan that walks deeper targets and enumerates the largest files.

### Why It Matters

It is the only storage mode that produces the full heavy-file list from current data.

### Where To Find It

- App: `Storage` section, `Deep Scan`

### How To Use It

- click `Deep Scan`
- wait for the scan to finish
- filter and reveal large items in Finder

### Edge Cases And Limits

- deep scans are slower than summary refreshes
- access limits still apply to protected folders and user-selected external locations

## Feature: Protected Storage Access Grants

### What It Is

Opt-in access controls for Desktop, Documents, Downloads, Pictures, and saved extra locations.

### Why It Matters

Buoy can inspect sensitive folders only after you explicitly allow it.

### Where To Find It

- App: `Storage` section, `Access Grants`

### How To Use It

- enable a protected folder toggle
- grant access in the open panel
- optionally save extra folders or drives with `Saved Drives & Folders`

### Edge Cases And Limits

- choosing an ancestor folder is allowed for protected scopes
- choosing a descendant folder is rejected for those scopes
- changing access grants invalidates the storage cache and starts a new summary refresh

## Feature: Machine-Readable Status

### What It Is

JSON output for status and doctor commands.

### Why It Matters

Scripts, automation, and external tools can inspect Buoy without scraping human-readable text.

### Where To Find It

- CLI: `buoy status --json`, `buoy doctor --json`

### How To Use It

```bash
buoy status --json
buoy doctor --json
```

### Edge Cases And Limits

- JSON reflects current status and known saved state, not historical data
- field presence can vary when the machine has no battery or a metric is unavailable

## See Also

- [Overview](overview.md)
- [Metrics And Definitions](metrics-and-definitions.md)
- [Advanced Usage](advanced-usage.md)

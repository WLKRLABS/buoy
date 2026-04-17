# Getting Started

## Audience

New users who want the shortest path from install to a working setup.

## Purpose

Help you install Buoy, verify it, apply the power profile safely, and understand the first app screens.

## Before You Start

- You need a Mac.
- You need administrator credentials for `apply` and `off`.
- The default install locations are `~/.local/bin` for `buoy` and `~/Applications` for `Buoy.app`.
- If `~/.local/bin` is not already on your shell `PATH`, you may need `buoy path-add`.

## 1. Install Buoy

Recommended release install:

```bash
curl -fsSL https://raw.githubusercontent.com/WLKRLABS/buoy/main/install.sh | DOWNLOAD_REPO=WLKRLABS/buoy bash
```

Local install from a clone:

```bash
./install.sh
```

## 2. Verify The Install

Run:

```bash
buoy doctor
buoy status
```

What you should see:

- `doctor` reports `macOS`, `pmset`, and `osascript` as `ok`
- `status` prints the current power source and managed AC settings

If `buoy` is not found, see [Troubleshooting](troubleshooting.md#buoy-command-not-found).

## 3. Apply Buoy Mode

Smallest useful command:

```bash
buoy apply
```

What this means:

- Buoy saves the current AC settings
- Buoy disables full idle sleep on AC
- the display keeps its own sleep timer

To preview without changing the machine:

```bash
buoy apply --dry-run
```

## 4. Optional: Enable Closed-Lid Awake Mode

Example:

```bash
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 15
```

What this means:

- while plugged in, Buoy keeps `SleepDisabled=1`
- on battery, Buoy keeps the machine awake only above the configured floor
- a helper process polls battery state at the configured interval

## 5. Open The App

Launch `Buoy.app` and start with:

- `Overview` for a quick machine summary
- `Power` to confirm mode, display sleep, and closed-lid settings
- `Storage` when disk pressure matters

## 6. Restore Normal AC Sleep Behavior

Run:

```bash
buoy off
```

This restores the saved AC settings from the Buoy state file and stops the closed-lid helper if it is active.

## First Tasks To Try

- Apply a shorter display sleep timer:

```bash
buoy apply --display-sleep 5
```

- Check machine state as JSON:

```bash
buoy status --json
```

- Sleep the display without changing Buoy mode:

```bash
buoy screen-off
```

- Open the Storage tab and run `Refresh Summary` before `Deep Scan`

## If You Only Read One Rule

Do not delete `~/.buoy/state.json` while Buoy mode is on.

That file holds the restore point for `buoy off`.

## See Also

- [Installation](installation.md)
- [Interface Tour](interface-tour.md)
- [Workflows](workflows.md)
- [Troubleshooting](troubleshooting.md)

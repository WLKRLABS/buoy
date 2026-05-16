# <img src="./buoy-icon.png" alt="Buoy icon" width="72" align="center" /> Buoy

> Keep a Mac awake on AC power, restore the original sleep settings cleanly, and inspect the machine from a native macOS dashboard.

Buoy is a macOS-only utility with two surfaces:

- `buoy`, a CLI that owns power-state changes and restore behavior
- `Buoy.app`, a native wrapper that drives the CLI and adds live system inspection

## Quick start

Install from the latest GitHub release:

```bash
curl -fsSL https://github.com/WLKRLABS/buoy/releases/latest/download/install.sh | bash
```

Install from a local clone:

```bash
./install.sh
```

Then verify the install:

```bash
buoy doctor
buoy status
```

If `~/.local/bin` is not on your shell `PATH`, run:

```bash
buoy path-add
```

## What Buoy does

- applies a server-friendly AC power profile with `pmset`
- keeps display sleep configurable instead of forcing the screen on
- optionally manages closed-lid awake behavior above a battery floor
- restores the previously saved AC settings with `buoy off`
- shows live Overview, Power, System, Processes, Services, Network, and Storage sections in the app
- scans storage in two passes: a fast summary refresh and an explicit deep scan for largest files

## What Buoy does not do

- it does not manage non-macOS systems
- it does not auto-start at login or auto-apply on boot in the current repo
- it does not clean files automatically
- it does not replace `pmset`; it applies a narrow set of reversible settings on top of it

## Common commands

```bash
buoy apply
buoy apply --display-sleep 5
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 15
buoy status
buoy status --json
buoy off
buoy screen-off
buoy doctor
```

## What `buoy apply` changes

`buoy apply` reads the current AC profile, saves the original values, and applies a managed AC profile.

Managed keys:

- `sleep=0`
- `displaysleep=<minutes>`
- `standby=0`
- `powernap=0`
- `womp=1`
- `ttyskeepawake=1`
- `tcpkeepalive=1`

`buoy off` restores the saved AC values from `~/.buoy/state.json` and stops the closed-lid helper if it is running.

## Closed-lid awake mode

When you pass `--clam`, Buoy also manages `SleepDisabled`.

Behavior:

- `SleepDisabled=1` on AC power
- `SleepDisabled=1` on battery above the configured threshold
- `SleepDisabled=0` at or below the threshold unless it was already enabled before Buoy

Example:

```bash
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 10
```

## App overview

`Buoy.app` is not a separate control path. It drives the installed CLI and adds a native dashboard.

Power controls:

- Enable Buoy mode
- Allow closed-lid awake mode
- Display sleep
- Battery floor
- Poll interval
- Appearance
- Apply, Turn Off, Sleep Display, and Refresh

Dashboard sections:

- Overview
- Power
- System
- Processes
- Services
- Network
- Storage

Storage workflow highlights:

- cached snapshots for fast tab open
- background summary refreshes
- explicit `Deep Scan` for largest-file enumeration
- opt-in protected-folder grants for Desktop, Documents, Downloads, and Pictures
- saved bookmarks for extra folders and drives

Privileged writes use the standard macOS administrator prompt. Normal reads run through the CLI or local system APIs without extra elevation.

## Documentation

Start with [Documentation](docs/README.md). The main path is:

- [Overview](docs/overview.md)
- [Getting started](docs/getting-started.md)
- [Installation](docs/installation.md)
- [Interface tour](docs/interface-tour.md)
- [Workflows](docs/workflows.md)
- [Troubleshooting](docs/troubleshooting.md)

Maintainers should also read [Architecture](docs/architecture.md), [Style guide](docs/style-guide.md), and [Glossary](docs/glossary.md).

## Build from source

Build the CLI:

```bash
./scripts/build-cli.sh
```

Build the app:

```bash
./scripts/build-app.sh
```

Optional local signing for stable permissions across repeated local app installs:

```bash
./scripts/setup-local-signing.sh
./scripts/build-app.sh
```

Package release assets:

```bash
./scripts/package-release.sh
./scripts/verify-release.sh
```

Prepare a release from the current `Unreleased` notes:

```bash
./scripts/release.sh prepare X.Y.Z
git commit -m "release: vX.Y.Z"
./scripts/release.sh tag
```

Validate versioning and render release notes manually:

```bash
bash scripts/validate-versioning.sh
./scripts/render-release-notes.sh
```

## Current limits

- macOS only
- Apple Silicon release assets only
- `Buoy.app` declares `LSMinimumSystemVersion` `13.0`
- privileged power changes still depend on standard macOS administrator authentication
- closed-lid awake mode uses a helper process
- GitHub release downloads are not notarized in the current repo
- source builds require a working Apple Swift toolchain
- current build scripts emit native binaries for the build host instead of universal binaries

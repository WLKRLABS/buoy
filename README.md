# <img src="./buoy-icon.png" alt="Buoy icon" width="72" align="center" /> Buoy

> Keep a Mac awake on AC power, let the display sleep on its own timer, and restore a sleep-enabled policy cleanly.

Buoy is a macOS-only utility for Macs that need to stay available without turning power settings into guesswork. It ships as two surfaces:

- `buoy`, the CLI and source of truth for power-state changes.
- `Buoy.app`, a native AppKit dashboard that drives the CLI and adds live system inspection.

## Quick start

Install the latest GitHub release:

```bash
curl -fsSL https://github.com/WLKRLABS/buoy/releases/latest/download/install.sh | bash
```

Verify the install:

```bash
buoy doctor
buoy status
```

If your shell cannot find `buoy`, add the default install directory to `PATH`:

```bash
buoy path-add
```

Default install locations:

| Artifact | Default path |
| --- | --- |
| CLI | `~/.local/bin/buoy` |
| App | `~/Applications/Buoy.app` |

## Source-backed status

| Area | Current repo fact |
| --- | --- |
| Version source | `VERSION` is the source of truth for CLI, app bundle, tags, and release assets. |
| Platform | macOS only. `Buoy.app` declares `LSMinimumSystemVersion` `13.0`. |
| Release shape | GitHub releases package `buoy`, `Buoy.app.zip`, `install.sh`, and `SHA256SUMS.txt`. |
| Architecture | Current release assets are Apple Silicon only. The build scripts emit native host binaries, not universal binaries. |
| Runtime state | Power restore state lives at `~/.buoy/state.json`. |
| Distribution limit | GitHub release downloads are not notarized in the current repo. |

## What Buoy changes

`buoy apply` reads the current AC power profile, saves a restore point, and applies a narrow managed profile:

| `pmset` key | Managed value |
| --- | --- |
| `sleep` | `0` |
| `displaysleep` | chosen minutes |
| `standby` | `0` |
| `powernap` | `0` |
| `womp` | `1` |
| `ttyskeepawake` | `1` |
| `tcpkeepalive` | `1` |

`buoy off` clears closed-lid helper state and `SleepDisabled`, restores the saved AC profile while ensuring the system `sleep` timer permits sleep, and verifies finite AC and battery system-sleep timers. If no usable restore point exists, Off repairs system `sleep=Never` to a safe finite value. The independent `displaysleep` preference is restored exactly, including `0` (`Never`).

`buoy status` reports three separate facts: whether Buoy mode is On or Off, whether the persistent macOS sleep policy permits sleep, and whether an app or macOS currently has a temporary wake request. The display-sleep timer is reported separately because it does not control system sleep. Persistent policy problems never replace the Buoy mode label. Temporary assertions are informational: they do not redefine mode or policy, do not make `buoy off` fail, and an idle-only assertion does not disable lid-close sleep.

Buoy does not replace `pmset`. It adds a reversible layer on top of the macOS power tools that already exist on the machine.

## Commands

| Command | Use |
| --- | --- |
| `buoy apply` | Enable Buoy mode with the default display sleep timer. |
| `buoy apply --display-sleep 5` | Keep the Mac awake while allowing display sleep after 5 minutes. |
| `buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 15` | Enable closed-lid awake mode above a battery floor. |
| `buoy status` | Show the current human-readable state. |
| `buoy status --json` | Emit machine-readable state for scripts. |
| `buoy off` | Turn Buoy mode off, restore nonblocking settings, and repair persistent sleep blockers. |
| `buoy screen-off` | Sleep the display now. |
| `buoy doctor` | Check local runtime dependencies and state paths. |

Use `--dry-run` with apply, off, screen-off, or path-add when you want to inspect the action first.

## Closed-lid awake mode

Closed-lid awake mode is optional. When enabled with `--clam`, Buoy manages `SleepDisabled` from a helper process:

- `SleepDisabled=1` on AC power.
- `SleepDisabled=1` on battery above the configured floor.
- `SleepDisabled=0` at or below the floor.

Turning Buoy mode off always sets `SleepDisabled=0`. Buoy never restores a saved system `sleep=0` as the Off policy, but it does preserve the independent display-sleep preference exactly.

Example:

```bash
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 10
```

## Buoy.app

`Buoy.app` is the native control surface, not a separate power engine. It resolves and runs the installed CLI for power actions.

Power controls:

- Enable Buoy mode
- Allow closed-lid awake mode
- Display sleep
- Battery floor
- Poll interval
- Appearance
- Apply Settings, Turn Off, Sleep Display, and Refresh

The Buoy mode switch acts immediately. `Apply Settings` updates sliders and closed-lid settings only while the mode is active. `Turn Off` is also available as an explicit restore or policy-repair action.

Dashboard sections:

- Overview
- Power
- System
- Processes
- Services
- Network
- Storage

Storage opens from cached data when it can, refreshes summaries in the background, and runs the slower largest-file enumeration only when you choose `Deep Scan`. Protected folders and extra drives stay opt-in.

## Documentation path

Start with [Documentation](docs/README.md) when you need the full manual.

Most readers need:

- [Overview](docs/overview.md)
- [Getting started](docs/getting-started.md)
- [Installation](docs/installation.md)
- [Interface tour](docs/interface-tour.md)
- [Workflows](docs/workflows.md)
- [Troubleshooting](docs/troubleshooting.md)

Maintainers should also read:

- [Architecture](docs/architecture.md)
- [Build and run](docs/developer/build-and-run.md)
- [Release process](docs/developer/release-process.md)
- [Style guide](docs/style-guide.md)
- [Glossary](docs/glossary.md)

## Build from source

Build the CLI:

```bash
./scripts/build-cli.sh
```

Build the app:

```bash
./scripts/build-app.sh
```

Install from a local clone:

```bash
./install.sh
```

Optional local signing for stable permissions across repeated local app installs:

```bash
./scripts/setup-local-signing.sh
./scripts/build-app.sh
```

## Release maintenance

Package and verify release assets:

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

`VERSION` is the source of truth for the CLI version, app bundle version, release tags, and packaged assets.

## Current limits

- macOS only.
- Apple Silicon release assets only.
- `Buoy.app` declares `LSMinimumSystemVersion` `13.0`.
- Privileged power changes depend on standard macOS administrator authentication.
- Closed-lid awake mode uses a helper process.
- GitHub release downloads are not notarized in the current repo.
- Source builds require a working Apple Swift toolchain.
- Current build scripts emit native binaries for the build host instead of universal binaries.
- Buoy does not auto-start at login or auto-apply on boot in the current repo.
- Buoy inspects storage but does not delete files automatically.

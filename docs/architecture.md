# Architecture

## Purpose

Describe Buoy's observable product structure and runtime boundaries without requiring readers to start in source files.

## Product shape

Buoy ships two user-facing binaries:

- `buoy`: the CLI and source of truth for power-state behavior.
- `Buoy.app`: the native AppKit wrapper and dashboard that drives the CLI for power actions.

The CLI owns apply, restore, status, doctor, screen-off, install, and PATH helper behavior. The app does not reimplement the power engine; it resolves and runs the installed CLI.

## Main components

| Component | Paths | Role |
| --- | --- | --- |
| Core engine | `Sources/BuoyCore/` | Models, `pmset` parsing, state storage, apply/off/status/doctor behavior, and system metrics. |
| CLI | `Sources/buoy/main.swift` | Command dispatch, flag parsing, human output, and JSON output. |
| App shell | `Sources/BuoyApp/main.swift` | Main window, power controls, CLI bridge, privilege prompts, and appearance preference. |
| Dashboard | `Sources/BuoyApp/Dashboard/` | Overview, Power, System, Processes, Services, Network, and Storage sections. |
| Scripts | `scripts/` and `install.sh` | Build, test, package, install, uninstall, version, and release helpers. |
| Tests | `Tests/` and script tests | Storage scanner/cache checks plus repo smoke and version validation. |

## Runtime data flow

### Apply Buoy mode

1. User runs `buoy apply` or clicks `Apply` in the app.
2. CLI parses flags into a `BuoyConfig`.
3. Core engine reads current AC `pmset` values.
4. Core engine records the restore point in `~/.buoy/state.json` if one is not already stored.
5. Core engine applies the managed AC profile.
6. If closed-lid awake mode is enabled, the helper manages `SleepDisabled`.

### Restore normal AC behavior

1. User runs `buoy off` or clicks `Turn Off`.
2. Core engine reads `~/.buoy/state.json`.
3. Core engine restores saved AC values.
4. Closed-lid helper state is cleared when Buoy mode is off.

### App inspection

1. App sections refresh through `RefreshCoordinator` and system metric collectors.
2. Power status comes from the CLI contract, especially `buoy status --json`.
3. Storage loads cached data first when valid, then refreshes summary or deep scan data based on user action.

## Persistence

Buoy writes local state only:

- `~/.buoy/state.json`: mode state, restore point, current config, and helper metadata.
- `~/Library/Application Support/Buoy/storage-scan-cache.json`: cached storage snapshots.
- `UserDefaults`: app preferences and storage access metadata.

## External dependencies

Runtime dependencies proved by source and CLI doctor output:

- macOS
- `pmset`
- `osascript`

Build and contributor dependencies:

- Swift toolchain
- Xcode command-line tools or Xcode
- `xcodebuild`
- standard macOS packaging tools used by the scripts

Dashboard collection also uses local macOS APIs and tools such as `launchctl`, `lsof`, and filesystem metadata where relevant.

## Security and permission boundaries

- CLI privileged writes use `sudo`.
- App privileged writes use `osascript` with administrator privileges.
- Storage protected folders and custom paths require explicit user grants.
- Buoy does not send telemetry or cloud data during normal runtime.
- GitHub release installation uses network access only when installing from remote release assets or source archives.

## Distribution

`VERSION` is the single source of truth for CLI version output, app bundle version, tags, and release assets.

The release workflow builds:

- `dist/release/buoy`
- `dist/release/Buoy.app.zip`
- `dist/release/install.sh`
- `dist/release/SHA256SUMS.txt`

## Current constraints

- macOS only.
- `Buoy.app` declares minimum macOS version `13.0`.
- Current release assets are Apple Silicon only.
- Build scripts compile native binaries for the build host instead of universal binaries.
- GitHub release downloads are not notarized in the current repo.
- CPU temperature is intentionally unavailable in the current Apple silicon path.

## Decisions

- Keep the CLI as the source of truth for power behavior.
- Keep the native app thin and source-backed.
- Keep restore behavior as important as apply behavior.
- Keep storage scans local and opt-in for protected locations.
- Keep release automation tag-driven through the repo scripts and GitHub Actions.

## Unresolved questions

- Whether future releases will add notarization.
- Whether future releases will add universal or Intel release targets.
- Whether future app accessibility validation will be documented from a manual VoiceOver, focus-order, and contrast pass.

## Related docs

- [Developer architecture](developer/architecture.md)
- [Data flow](developer/data-flow.md)
- [Build and run](developer/build-and-run.md)
- [Release process](developer/release-process.md)
- [ADR-001](adr/ADR-001-swift-cli-and-swift-wrapper.md)

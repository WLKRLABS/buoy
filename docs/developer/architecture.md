# Buoy Architecture

## Audience

Developers and maintainers working on the Buoy codebase.

## Purpose

Describe the shipped product shape, core runtime components, and the main architectural boundaries in the current repository.

## Product Shape

Buoy is intentionally split into two user-facing binaries:

- `buoy`
  Role: source of truth for power-state behavior
- `Buoy.app`
  Role: native wrapper and live dashboard

This split is deliberate:

- the CLI stays scriptable and auditable
- the app stays thin instead of re-implementing power behavior

## Repository Layout

Primary paths:

- `Sources/BuoyCore/`
  Shared models, engine, state handling, command execution, and parsers
- `Sources/buoy/main.swift`
  CLI entrypoint and argument parsing
- `Sources/BuoyApp/`
  App entrypoint, app bridge, and dashboard UI
- `Sources/BuoyApp/Dashboard/`
  Section controllers, storage subsystem, refresh coordinator, and UI components
- `Tests/`
  standalone Swift test entrypoints
- `scripts/`
  build, package, test, install, uninstall, and release helpers

## Core Runtime Components

## 1. Power Engine

Primary files:

- `Sources/BuoyCore/BuoyEngine.swift`
- `Sources/BuoyCore/Models.swift`
- `Sources/BuoyCore/StateStore.swift`
- `Sources/BuoyCore/PMSetParser.swift`

Responsibilities:

- parse CLI intent into a validated `BuoyConfig`
- read current AC settings through `pmset`
- compute the managed AC profile
- capture safe AC restore values only once per active mode session
- make `apply` and `off` immediate ownership transitions
- restore safe saved values and repair persistent macOS sleep blockers on `off`
- verify `SleepDisabled` and supported AC and battery system-sleep timers after repair
- preserve and restore the saved display-sleep value exactly as an independent setting
- keep temporary power assertions as informational diagnostics
- expose `status` and `doctor`

Key rules:

- the first successful apply captures a restore point whose system-sleep timer cannot restore `Never`; display sleep remains exact
- Off clears `SleepDisabled`, repairs persistent zero timers, and verifies the sleep-enabled policy even when no restore point is available
- assertion activity never changes Buoy ownership or determines whether Off succeeded

### Power State Contract

Power status has four independent dimensions:

1. **Buoy ownership**
   Immediate `On` or `Off`, derived from Buoy's persisted active-mode state. A managed-setting drift can produce a configuration issue without changing the requested ownership.
2. **Persistent sleep policy**
   Derived from `SleepDisabled` plus supported system `sleep` values in the active, AC, and battery profiles. `SleepDisabled=1` or a supported system-sleep timer of `0` is repairable policy drift.
3. **Display sleep**
   Derived from `displaysleep` and reported separately. A value of `0` means the display timer is disabled, not that system sleep is blocked; Off restores the saved value exactly.
4. **Temporary sleep requests**
   Derived from `pmset -g assertions`. These records explain temporary idle deferral but are informational: they do not redefine Mode, policy health, or Off success.

The UI and JSON status must preserve these boundaries. In particular, `PreventUserIdleSystemSleep` means automatic idle sleep is temporarily deferred; it must not be presented as if Buoy remained On or closed-lid sleep were globally disabled.

## 2. CLI Surface

Primary file:

- `Sources/buoy/main.swift`

Responsibilities:

- command dispatch
- argument validation
- human-readable output
- JSON output for `status` and `doctor`

Notable command groups:

- power control: `apply`, `off`, `screen-off`
- inspection: `status`, `doctor`
- install helpers: `install`, `path-add`
- internal helper: `__clam-monitor`

## 3. Closed-Lid Helper

Primary implementation:

- `BuoyEngine.runClamMonitor`

Responsibilities:

- poll battery and power source
- maintain `SleepDisabled` while the configured rules are true
- stop when Buoy mode or closed-lid mode is no longer enabled

Important boundary:

- this is the only background helper Buoy starts automatically
- its `SleepDisabled` mutation belongs to Buoy ownership and must be cleared by Off; unrelated process assertions do not belong to the helper

## 4. App Shell And CLI Bridge

Primary file:

- `Sources/BuoyApp/main.swift`

Responsibilities:

- create the main window
- manage section switching
- resolve the CLI path
- dispatch `apply` immediately when the mode switch turns On
- dispatch `off` immediately when the mode switch turns Off
- expose `Apply Settings` only while mode is On
- expose policy repair when mode is Off but persistent blockers remain
- run normal commands directly
- run privileged commands through `osascript` with administrator privileges

Important rule:

- the app is not allowed to drift into a second source of truth for power behavior
- the switch reflects confirmed CLI ownership after refresh; a command failure refreshes instead of leaving an optimistic UI state

## 5. Dashboard Collection Layer

Primary files:

- `Sources/BuoyApp/Dashboard/RefreshCoordinator.swift`
- `Sources/BuoyCore/SystemMetrics/MetricsCollector.swift`
- `Sources/BuoyCore/SystemMetrics/*.swift`

Responsibilities:

- collect snapshots on a background queue
- broadcast live dashboard updates to section controllers
- stop timer activity when the window is miniaturized

Collected domains:

- CPU
- memory
- disk
- power
- thermal
- processes
- services
- network

## 6. Storage Subsystem

Primary files:

- `Sources/BuoyApp/Dashboard/StorageViewController.swift`
- `Sources/BuoyApp/Dashboard/StorageScanner.swift`
- `Sources/BuoyApp/Dashboard/StorageAccessManager.swift`
- `Sources/BuoyApp/Dashboard/StorageCacheStore.swift`
- `Sources/BuoyApp/Dashboard/StorageModels.swift`

Responsibilities:

- fast Storage tab open from cached or seed data
- two scan modes: `summaryOnly` and `deep`
- protected-folder and custom-location grants
- storage-cache invalidation when access grants change

Important behavior:

- summary mode favors speed and bounded work
- deep mode is the only current path that refreshes the largest-file list from live data

## Persistence

Primary local persistence:

- `~/.buoy/state.json`
  Purpose: active Buoy ownership, safe power restore values, configuration, and closed-lid helper metadata
- `~/Library/Application Support/Buoy/storage-scan-cache.json`
  Purpose: storage snapshot cache
- `UserDefaults`
  Purpose: UI preferences and storage grant metadata

## Security Model

Power writes:

- CLI uses `sudo`
- app uses `osascript` with administrator privileges

Storage access:

- protected folders and custom folders use explicit user grants and saved bookmarks

## Compatibility Boundaries

What the current source proves:

- macOS only
- AppKit app minimum system version `13.0`
- build scripts compile native binaries for the build host

## Design Intent

The codebase is optimized for:

- directness
- reversibility
- an immediate and unsurprising On/Off control
- explicit separation of ownership, persistent policy, and temporary activity
- low runtime surface area
- small distribution and build scripts

It is not optimized for:

- cross-platform support
- agent-heavy background behavior
- a custom package manager or universal build pipeline

## Related Docs

- [Data Flow](data-flow.md)
- [Build And Run](build-and-run.md)
- [Testing](testing.md)
- [Release Process](release-process.md)
- [ADR-001](../adr/ADR-001-swift-cli-and-swift-wrapper.md)

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
- capture the original AC values only once
- restore the saved AC values on `off`
- expose `status` and `doctor`

Key rule:

- the first successful apply captures the restore point

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

## 4. App Shell And CLI Bridge

Primary file:

- `Sources/BuoyApp/main.swift`

Responsibilities:

- create the main window
- manage section switching
- resolve the CLI path
- run normal commands directly
- run privileged commands through `osascript` with administrator privileges

Important rule:

- the app is not allowed to drift into a second source of truth for power behavior

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
  Purpose: power restore state
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

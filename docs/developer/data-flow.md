# Buoy Data Flow

## Audience

Developers who need to understand how data and control move through the system.

## Purpose

Describe the main runtime flows in a way that makes maintenance and debugging faster.

## Flow 1: CLI Apply

```text
CommandLine
  -> Sources/buoy/main.swift
  -> BuoyEngine.apply(config:)
  -> pmset capability read
  -> pmset current AC read
  -> desired-value calculation
  -> state capture in ~/.buoy/state.json
  -> privileged pmset write
  -> optional closed-lid helper launch
  -> user-facing output
```

Key facts:

- validation happens before writes
- original AC values are saved only when the state file does not already have them
- the same CLI path is used whether the caller is Terminal or the app

## Flow 2: CLI Off

```text
CommandLine
  -> Sources/buoy/main.swift
  -> BuoyEngine.disable()
  -> load ~/.buoy/state.json
  -> stop closed-lid helper if present
  -> restore saved AC settings
  -> clear state file
  -> user-facing output
```

Failure mode to remember:

- if the state file is missing, `off` cannot restore the prior AC profile

## Flow 3: App Power Action

```text
Power section UI
  -> ShellBridge.runPrivileged(arguments:)
  -> osascript "do shell script ... with administrator privileges"
  -> installed buoy binary
  -> BuoyEngine
  -> command result
  -> app refreshes status through buoy status --json
```

Key facts:

- the app does not write power state directly
- privileged writes are routed through the CLI contract
- refresh after command execution rehydrates the UI from the CLI state

## Flow 4: App Status Refresh

```text
Power section Refresh
  -> ShellBridge.fetchStatus()
  -> buoy status --json
  -> JSON decode into BuoyStatus
  -> render controls, summary cards, and CLI readout
```

Key facts:

- UI values are reset from current status
- the power panel should be treated as a view over CLI state, not a separate settings store

## Flow 5: Dashboard Snapshot Collection

```text
RefreshCoordinator timer
  -> MetricsCollector.collect()
  -> CPU / Memory / Disk / Power / Thermal collectors
  -> Process / Service / Network collectors
  -> DashboardSnapshot
  -> main-thread fan-out to section controllers
```

Key facts:

- collection happens on a background queue
- consumers receive updates on the main thread
- CPU and process CPU values are delta-based and need prior samples

## Flow 6: Storage Tab Open

```text
StorageViewController.viewDidAppear
  -> load access fingerprint
  -> try storage cache
  -> if cache exists: render cached snapshot
  -> else: render seed disk-only snapshot
  -> decide whether to auto-run summary refresh
```

Key facts:

- fast first paint matters more than exactness on tab open
- a stale cache still renders first, then refreshes

## Flow 7: Storage Summary Refresh

```text
Refresh Summary
  -> begin access session
  -> StorageScanner.scan(mode: summaryOnly)
  -> bounded du measurements on selected roots
  -> cleanup-target measurements
  -> residual system estimate fills remaining used-space gap
  -> snapshot render
  -> cache save
```

Key facts:

- summary mode keeps timeouts tight
- summary mode can preserve a prior deep-scan heavy-item list

## Flow 8: Storage Deep Scan

```text
Deep Scan
  -> begin access session
  -> StorageScanner.scan(mode: deep)
  -> broader child measurements
  -> largest-file enumeration
  -> snapshot render
  -> cache save with deep timestamp
```

Key facts:

- deep mode is slower by design
- deep mode produces the current heavy-file list

## Flow 9: Storage Access Change

```text
User changes protected-folder or custom-location access
  -> StorageAccessManager updates UserDefaults/bookmarks
  -> StorageCacheStore.invalidate()
  -> StorageViewController starts summary refresh
```

Key facts:

- access state is part of the cache fingerprint
- cached storage data is intentionally invalidated on access change

## Flow 10: Release Build

```text
VERSION
  -> scripts/version.sh
  -> build-cli.sh / build-app.sh
  -> package-release.sh
  -> GitHub release workflow
```

Key facts:

- `VERSION` is the single source of truth
- release automation is tag-driven

## Debugging Heuristics

- if power behavior is wrong, start in `BuoyEngine` and `pmset`
- if the app disagrees with the CLI, inspect `ShellBridge` and `status --json`
- if dashboard sections are stale, inspect `RefreshCoordinator`
- if Storage is slow or wrong, inspect access state, cache state, then scanner mode

## Related Docs

- [Architecture](architecture.md)
- [Testing](testing.md)
- [Release Process](release-process.md)

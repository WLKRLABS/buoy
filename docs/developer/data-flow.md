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
  -> safe restore-point capture in ~/.buoy/state.json
  -> privileged pmset write
  -> optional closed-lid helper launch
  -> verified mode ownership On
  -> user-facing output
```

Key facts:

- validation happens before writes
- original AC values are saved only when the state file does not already have them
- a captured restore point normalizes a system-sleep value of `0` to a safe finite value, so Off cannot restore a persistent system-sleep Never policy
- `displaysleep` is independent of system sleep and remains exact in the restore point, including `0`
- the same CLI path is used whether the caller is Terminal or the app

## Flow 2: CLI Off

```text
CommandLine
  -> Sources/buoy/main.swift
  -> BuoyEngine.disable()
  -> load ~/.buoy/state.json when present
  -> stop closed-lid helper if present
  -> restore safe saved AC settings when present
  -> restore saved AC displaysleep exactly when present
  -> set SleepDisabled to 0
  -> repair AC and battery system-sleep timers set to Never
  -> verify persistent sleep policy
  -> clear active restore state after successful verification
  -> verified mode ownership Off
  -> user-facing output
```

Key facts:

- Off is an immediate ownership transition, not a claim that every process has stopped requesting temporary wakefulness
- when the restore point exists, Buoy restores its safe saved AC values before verifying the policy
- when the restore point is missing, Off still repairs `SleepDisabled=1` and supported AC or battery system-sleep timers set to `0` using safe finite values
- Off does not treat `displaysleep=0` as a blocker; it restores a saved display timer exactly and otherwise leaves display sleep independent
- a failed policy repair leaves an explicit policy issue; it does not turn temporary assertions into restore failures
- temporary power assertions are informational and never redefine Mode Off or Off success

## Flow 3: App Power Action

```text
Power section Buoy mode switch
  -> On immediately dispatches apply with the current settings
  -> Off immediately dispatches off
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
- the mode switch is an action, not a draft value waiting for another button
- `Apply Settings` is enabled only while mode is On and updates the active configuration
- `Turn Off` can become `Repair Sleep` when ownership is already Off but persistent policy blockers remain
- refresh after command execution rehydrates the UI from the CLI state

## Flow 4: App Status Refresh

```text
Power section Refresh
  -> ShellBridge.fetchStatus()
  -> buoy status --json
  -> JSON decode into BuoyStatus
  -> persisted state determines Buoy ownership On or Off
  -> SleepDisabled and active/profile system-sleep timers determine persistent policy health
  -> displaysleep is reported as an independent display policy
  -> pmset assertions provide temporary activity diagnostics
  -> render controls, summary cards, and CLI readout
```

Key facts:

- UI values are reset from current status
- the power panel should be treated as a view over CLI state, not a separate settings store
- ownership, persistent system-sleep policy, display sleep, and temporary assertions are orthogonal status dimensions
- an active or unreadable assertion cannot change Mode, make a healthy persistent policy unverified, or invalidate a completed Off action
- `PreventUserIdleSystemSleep` is presented as temporary idle deferral, not as Buoy-owned sleep prevention

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

- if the mode switch is wrong, start with persisted ownership state and the `BuoyEngine` apply/off path
- if persistent sleep policy is wrong, inspect `SleepDisabled` and AC/battery `sleep` values before looking at assertions
- if only the display behavior is wrong, inspect `displaysleep` separately; `0` does not prevent system sleep
- if idle sleep is temporarily deferred, inspect assertion owners as diagnostics without changing Mode or policy health
- if the app disagrees with the CLI, inspect `ShellBridge` and `status --json`
- if dashboard sections are stale, inspect `RefreshCoordinator`
- if Storage is slow or wrong, inspect access state, cache state, then scanner mode

## Related Docs

- [Architecture](architecture.md)
- [Testing](testing.md)
- [Release Process](release-process.md)

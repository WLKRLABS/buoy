# Glossary

## Purpose

This glossary defines the preferred language for active Buoy docs. Use these terms in README, user docs, developer docs, release notes, and machine-readable references.

## Naming rules

- Use `Buoy` for the product.
- Use `buoy` for the CLI binary.
- Use `Buoy.app` for the native macOS app.
- Use `Buoy mode`, not `server mode`, for the managed keep-awake profile.
- Use exact UI labels when naming controls, for example `Enable Buoy mode`, `Apply Settings`, `Turn Off`, `Sleep Display`, `Refresh Summary`, and `Deep Scan`.
- Use `closed-lid awake mode` for the optional `SleepDisabled` behavior.
- Use `restore point` for the saved original AC settings.
- Use `state file` for `~/.buoy/state.json`.
- Use `persistent sleep policy` for `SleepDisabled` plus the AC and battery system `sleep` timers.
- Use `temporary wake request` for a live macOS power assertion; do not call it Buoy mode or a persistent policy setting.

## Product terms

### Buoy mode

Buoy's immediate On or Off ownership of the keep-awake-on-AC profile.

Technical meaning: the managed AC `pmset` profile applied by `buoy apply` or the app switch and restored by `buoy off` or switching the mode off.

### Persistent sleep policy

The macOS settings that continue to govern sleep after temporary activity ends.

Technical meaning: `SleepDisabled` and the `sleep` values in the AC and battery profiles. Off clears `SleepDisabled` and ensures the system-sleep timers are finite.

### Temporary wake request

An app or macOS request that temporarily delays a kind of sleep.

Technical meaning: a live `pmset` assertion reported for diagnostics. It does not redefine Buoy mode or the persistent sleep policy. `PreventUserIdleSystemSleep` delays idle sleep while active but does not disable lid-close sleep.

### Closed-lid awake mode

Optional behavior that keeps the Mac awake with the lid closed above a battery floor.

Technical meaning: a helper-driven mode that manages `SleepDisabled` based on power source and battery threshold.

### Display sleep

How long the screen waits before sleeping.

Technical meaning: the independent `pmset displaysleep` value Buoy applies on AC and restores exactly on Off. `displaysleep=0` means the display timer is `Never`; it does not prevent system sleep.

### Battery floor

The battery percentage below which closed-lid awake mode stops staying on.

Technical meaning: the `clam_min_battery` configuration value used by the closed-lid helper.

### Poll interval

How often Buoy rechecks battery state for closed-lid awake mode.

Technical meaning: the `clam_poll_seconds` value passed to the closed-lid helper.

### Restore point

The saved nonblocking AC settings Buoy returns to when you turn it off.

Technical meaning: the `originalValues` map stored in `~/.buoy/state.json` when Buoy mode is applied. System `sleep=Never` is normalized before it can become the Off policy, while the saved display-sleep value is preserved exactly.

### State file

Buoy's local power-state record.

Technical meaning: the JSON file at `~/.buoy/state.json` that stores mode state, restore values, config, and helper metadata.

## Storage terms

### Summary refresh

The fast storage scan.

Technical meaning: `StorageScanner` `summaryOnly` mode with bounded per-path work and no fresh largest-file enumeration.

### Deep scan

The slower, more exact storage scan.

Technical meaning: `StorageScanner` `deep` mode that walks deeper targets and enumerates large files.

### Partial scan

Storage data is available, but the current largest-file list is incomplete or missing.

Technical meaning: a storage cache or live snapshot where the scan mode is `summaryOnly` and no current deep timestamp is available.

### Storage cache

Saved storage results for faster tab opening.

Technical meaning: the cache record stored at `~/Library/Application Support/Buoy/storage-scan-cache.json`.

### Access fingerprint

A record of which storage locations Buoy is allowed to scan.

Technical meaning: a normalized list of enabled protected scopes and custom paths used to validate cached storage data.

### Protected folder

A sensitive folder that Buoy scans only after you opt in.

Technical meaning: one of the Desktop, Documents, Downloads, or Pictures scopes managed by `StorageAccessManager`.

### Security-scoped bookmark

The saved permission Buoy uses to revisit a folder you approved.

Technical meaning: bookmark data stored in `UserDefaults` and resolved into a security-scoped URL at scan time.

### Cleanup signal

Buoy's advice about how safe an item might be to review for cleanup.

Technical meaning: the storage safety classification: `Likely Safe`, `Review First`, or `Essential`.

### Reclaimable

Space Buoy thinks is worth reviewing for cleanup.

Technical meaning: the sum of storage items currently classified as cleanup candidates.

## Dashboard terms

### Thermal pressure

macOS's current thermal stress level for the machine.

Technical meaning: `ProcessInfo.thermalState` rendered as `Nominal`, `Fair`, `Serious`, or `Critical`.

### Overview posture

The top summary that tells you whether the machine looks ready, busy, tight, or under thermal watch.

Technical meaning: the derived summary in `OverviewViewController` based on thermal, CPU, memory, disk, and battery heuristics.

## Avoid

- `server mode` unless quoting old notes.
- `optimize` unless the code actually optimizes a measurable behavior.
- `daemon` for the closed-lid helper.
- `cleanup` as an automatic action. Buoy helps inspect storage; it does not delete files automatically.

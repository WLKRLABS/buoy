# Privacy And Permissions

## Audience

Users and maintainers who need to know what Buoy reads, what it writes locally, and when it asks for permission.

## Purpose

Describe Buoy's local-data model, permission prompts, and non-goals around telemetry.

## Privacy Summary

The current app and CLI are local-first tools.

What the current source shows:

- no telemetry pipeline
- no analytics pipeline
- no cloud sync
- no remote service dependency for the app or CLI runtime

Important exception:

- the installer can download release assets or source archives from GitHub when you use the remote install path

## Local Data Buoy Writes

### Power State

Path:

- `~/.buoy/state.json`

Purpose:

- stores whether Buoy mode is enabled
- stores the saved original AC values
- stores the active configuration
- stores the closed-lid helper PID and original `SleepDisabled` value

### Storage Cache

Path:

- `~/Library/Application Support/Buoy/storage-scan-cache.json`

Purpose:

- stores the last storage snapshot for faster tab loading
- stores whether the snapshot was summary-only or deep
- stores the last deep-scan timestamp
- stores an access fingerprint so cached storage data stays tied to the active grants

### App Preferences

Storage location:

- `UserDefaults`

Known persisted items in the current source:

- appearance mode
- last selected dashboard section
- protected-folder enable flags
- protected-folder bookmarks
- custom-location enable flag
- custom-location bookmarks

## When Buoy Prompts For Permission

### Administrator Prompt

Triggered by:

- `buoy apply`
- `buoy off`
- equivalent actions from `Buoy.app`

Why:

- Buoy changes power settings through privileged `pmset` operations

### Folder Access Prompt

Triggered by:

- enabling a protected storage scope without a saved bookmark
- choosing saved custom folders or drives

Why:

- Buoy uses explicit access grants before scanning protected or custom storage locations

## What Buoy Reads

### Power State

Sources include:

- `pmset`
- IOKit power APIs

### Dashboard Metrics

Sources include:

- local system APIs for CPU, memory, disk, and thermal state
- `launchctl` and launchd plist files for service inventory
- `lsof` for listening ports
- `getifaddrs` for network interfaces
- local filesystem inspection for storage scanning

## Network Behavior

### Runtime

The app and CLI inspect local machine state only.

The `Network` section shows:

- local listeners
- local interfaces

It does not act as a network client for telemetry or account sync in the current source.

### Installer

The installer can contact:

- GitHub release download URLs
- GitHub source archive URLs

This happens only when you use the install path that downloads from GitHub.

## Security-Scoped Bookmarks

Buoy uses saved bookmarks for:

- protected folders
- user-selected custom folders and drives

Why this matters:

- access can persist across app relaunches
- Buoy can limit scans to locations you approved

## Things Buoy Does Not Currently Do

- no account system
- no remote dashboard
- no background data export
- no automatic file deletion

## Open Questions

- `[TBD — requires product/source confirmation]` for any formal privacy policy outside the repository
- `[TBD — requires product/source confirmation]` for any planned notarized distribution or signing policy statement

## See Also

- [Installation](installation.md)
- [Accessibility](accessibility.md)
- [Compatibility](compatibility.md)

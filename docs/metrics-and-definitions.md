# Metrics And Definitions

## Audience

Users, maintainers, and automation tools that need precise meanings for the values Buoy shows.

## Purpose

Define the dashboard metrics, their plain-language meaning, and the current source limitations behind them.

## CPU

### Overall CPU

Definition:

- percentage of total CPU time in use across all cores

How Buoy collects it:

- `host_processor_info` deltas between samples

Where it appears:

- `Overview`
- `System`

Limits:

- the first sample after launch can read as `0%` because delta-based history has not formed yet

### Per-Core CPU

Definition:

- per-core CPU usage percentages

How Buoy collects it:

- `host_processor_info` per-core tick deltas

Where it appears:

- `System`

### CPU Frequency

Definition:

- nominal CPU frequency in GHz when the current source can determine it

How Buoy collects it:

- `hw.cpufrequency` on Intel
- brand-string parsing fallback where possible

Where it appears:

- `Overview`
- `System`

Limits:

- it is a nominal value, not a live turbo or efficiency/performance-core readout

## Memory

### Total Memory

Definition:

- physical RAM installed on the machine

How Buoy collects it:

- `hw.memsize`

### Used Memory

Definition:

- an approximate macOS working-set view calculated as active plus wired plus compressed memory

How Buoy collects it:

- `host_statistics64`

### Available Memory

Definition:

- an approximate available-memory view calculated as free plus inactive memory

Where memory appears:

- `Overview`
- `System`
- `Processes` for per-process memory values

Limits:

- Buoy uses a practical dashboard approximation, not a full Activity Monitor memory-pressure model

## Disk

### Total, Used, And Available Disk

Definition:

- capacity values for the root mount point `/`

How Buoy collects it:

- first choice: volume metadata
- fallback: `statfs`

Important behavior:

- Buoy prefers `volumeAvailableCapacityForImportantUsage` when available
- this is closer to what macOS considers realistically available than a raw free-block count

Where it appears:

- `Overview`
- `System`
- `Storage`

## Power

### Power Source

Definition:

- current source such as `AC Power`, `Battery Power`, or `UPS Power`

How Buoy collects it:

- IOKit power-source APIs

### Battery Percent

Definition:

- current charge percentage when the machine has a battery

### Time Remaining

Definition:

- minutes to empty while discharging or minutes to full while charging

### Condition

Definition:

- battery-health string when the system exposes it

### Wattage Draw

Definition:

- approximate instantaneous power draw in watts

How Buoy collects it:

- battery amperage and voltage from the `AppleSmartBattery` registry

Limits:

- desktop Macs and some hardware paths can report no battery or no wattage

Where power appears:

- `Overview`
- `System`
- `Power`

## Thermal

### Thermal Pressure

Definition:

- the process thermal state reported by macOS, such as `Nominal`, `Fair`, `Serious`, or `Critical`

How Buoy collects it:

- `ProcessInfo.processInfo.thermalState`

### Battery Temperature

Definition:

- battery temperature in Celsius when the smart battery registry exposes it

### CPU Temperature

Definition:

- CPU temperature in Celsius

Current state:

- `[TBD — requires product/source confirmation]` for direct support on hardware that can safely expose it without extra entitlements

Current implementation detail:

- the current source intentionally returns `nil` for CPU temperature and falls back to thermal pressure instead

Where thermal appears:

- `Overview`
- `System`

## Processes

### CPU Percent

Definition:

- process CPU percent normalized to a single core, so multi-threaded processes can exceed `100%`

How Buoy collects it:

- `proc_pidinfo` deltas between samples

### Memory MB And Memory Percent

Definition:

- resident memory size in megabytes and as a share of total physical memory

### State

Definition:

- decoded process state such as `running`, `sleeping`, `stopped`, or `zombie`

Where process data appears:

- `Processes`
- `Overview` top-process summaries

## Services

### Service Inventory

Definition:

- launchd services discovered from known plist directories

Service locations:

- `/System/Library/LaunchDaemons`
- `/System/Library/LaunchAgents`
- `/Library/LaunchDaemons`
- `/Library/LaunchAgents`
- `~/Library/LaunchAgents`

### Status

Definition:

- `Running`, `Stopped`, `Disabled`, or `Unknown`

How Buoy collects it:

- plist inspection plus `launchctl list`

### Enabled On Boot

Definition:

- `RunAtLoad` or `KeepAlive` is present in the plist

Where service data appears:

- `Services`

## Network

### Listening Services

Definition:

- local TCP or UDP listeners currently bound by processes

How Buoy collects it:

- `lsof -nP -iTCP -sTCP:LISTEN -iUDP`

### Interfaces

Definition:

- local network interfaces with IPv4, IPv6, MAC, and link state

How Buoy collects it:

- `getifaddrs`

Where network data appears:

- `Network`

## Storage

### Summary Refresh

Definition:

- a fast storage pass focused on major folders and cleanup targets

Behavior:

- uses bounded `du` calls
- can leave the page in `Partial Scan`
- does not produce a new largest-file list unless a previous deep snapshot already exists

### Deep Scan

Definition:

- a slower scan that measures deeper targets and enumerates large files

### Reclaimable

Definition:

- the sum of storage items Buoy currently marks as cleanup candidates

Important note:

- reclaimable means review-worthy according to Buoy's heuristics, not safe for automatic deletion

### System + Hidden

Definition:

- system, library, hidden, and residual usage that Buoy could not or should not fully walk

Important note:

- this includes estimated residual usage, not only directly measured folders

### Storage Categories

- `Applications`
  Meaning: app bundles and application directories
- `User Data`
  Meaning: general user-owned folders and files
- `Downloads`
  Meaning: downloads and installer-like artifacts
- `Documents`
  Meaning: Documents and Desktop-style work files
- `Media`
  Meaning: Movies, Music, Pictures, and similar media
- `Developer`
  Meaning: developer toolchains, package-manager locations, simulators, and build artifacts
- `Backups`
  Meaning: mobile backups and similar backup data
- `Caches`
  Meaning: caches and logs that are often rebuildable
- `Library`
  Meaning: application support, containers, indexes, and shared libraries
- `System`
  Meaning: macOS-managed system paths
- `Hidden`
  Meaning: hidden folders, including user-hidden paths such as `.Trash`
- `Other`
  Meaning: user-selected locations or paths that do not fit a stronger category

### Cleanup Signal

Possible values:

- `Likely Safe`
  Meaning: usually rebuildable or expected cleanup material, but still review it
- `Review First`
  Meaning: may be safe, but Buoy cannot assume deletion is harmless
- `Essential`
  Meaning: system-managed or critical support data

## See Also

- [Alerts And Thresholds](alerts-and-thresholds.md)
- [Storage Workflows](workflows.md#review-storage-pressure-and-cleanup-targets)
- [Machine Glossary](machine/glossary.json)

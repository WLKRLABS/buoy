# Compatibility

## Audience

Users deciding whether Buoy fits their machine and maintainers documenting current support boundaries.

## Purpose

Record what the source proves about platform, hardware, and runtime compatibility.

## Supported Platform

### Operating System

- macOS only

Why:

- Buoy depends on macOS power tools such as `pmset`
- the app is built with AppKit

### Minimum macOS Version

What the current source proves:

- `Buoy.app` declares `LSMinimumSystemVersion` `13.0`

What to assume for the product:

- treat macOS `13.0` or later as the supported app baseline unless a release says otherwise

## Processor Architecture

What the current source proves:

- local builds in this workspace produce `arm64` binaries
- current build scripts call `swiftc` directly and do not build universal binaries

What to assume for the product:

- Buoy `1.0.0` supports Apple Silicon Macs only
- Intel Macs are not a supported release target in the current repo
- official universal release assets are not part of the current release pipeline

## Hardware Expectations

### Notebooks

Best fit when you need:

- AC-aware keep-awake behavior
- optional closed-lid awake mode
- battery floor management

### Desktop Macs

Still useful for:

- Buoy mode on AC
- system dashboard sections
- storage scanning

Expected differences:

- battery percent may be unavailable
- time remaining may be unavailable
- closed-lid mode is generally not relevant

## System Tools Buoy Depends On

The current repo expects these macOS tools or APIs:

- `pmset`
- `osascript`
- `launchctl`
- `lsof`
- IOKit power APIs
- AppKit for the native app

`buoy doctor` checks a subset of those dependencies directly.

## Metric Availability Limits

- CPU temperature is intentionally unavailable in the current source on Apple silicon
- battery and wattage values can be unavailable on hardware without a battery
- service and network views depend on what local system tools expose at runtime

## Storage Access Limits

- protected folders are opt-in
- custom folders and drives require saved grants
- summary mode and deep mode return different levels of detail by design

## Distribution Limits

What the current repo shows:

- build scripts sign the app bundle
- release automation packages `buoy`, `Buoy.app.zip`, `install.sh`, and `SHA256SUMS.txt`
- GitHub release downloads are not notarized in the current repo

## Compatibility Summary

Buoy is a current macOS utility for local use. It is safest to treat the documented support envelope as:

- macOS `13.0+`
- Apple Silicon release assets
- best experience on machines where macOS exposes battery and power telemetry

## See Also

- [Installation](installation.md)
- [Privacy And Permissions](privacy-and-permissions.md)
- [Troubleshooting](troubleshooting.md)

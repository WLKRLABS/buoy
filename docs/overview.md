# Buoy Overview

## Audience

End users, power users, maintainers, and automation tools that need the product explained in one place.

## Purpose

Define what Buoy is, what it is for, and the boundaries of the product.

## What Buoy Is

Buoy is a macOS utility with a CLI-first architecture.

It has two shipped surfaces:

- `buoy`, the command-line tool that reads and writes power state
- `Buoy.app`, the native macOS app that wraps the CLI and adds a live machine dashboard

## Who Buoy Is For

Buoy is aimed at people using a Mac as a dependable utility machine instead of a sleep-first personal laptop.

Typical users:

- developers running long local workloads
- operators and homelab users keeping a Mac available on AC power
- technical users who want a reversible power profile and a direct status dashboard

## What Problem Buoy Solves

macOS is tuned for general-purpose, sleep-friendly use. That is usually correct, but it gets in the way when you want a plugged-in Mac to stay reachable, keep wake-on-LAN behavior, and still behave like a normal Mac when you are done.

Buoy solves that by:

- applying a narrow AC-only power profile
- preserving the original AC values for restore
- exposing the current state through a CLI and a native app
- surfacing machine health and storage pressure in the same app

## What Buoy Does

Power management:

- disables full idle sleep on AC power
- keeps display sleep configurable
- enables wake-on-LAN and keepalive-related settings when supported
- optionally manages closed-lid awake behavior above a battery threshold
- restores the saved AC profile with `buoy off`

Inspection and dashboard:

- shows CPU, memory, disk, power, and thermal state
- lists active processes and launchd services
- shows listening ports and network interfaces
- scans storage pressure, cleanup targets, and protected-folder coverage

## What Buoy Does Not Do

- it does not manage Windows, Linux, or non-macOS hosts
- it does not provide automatic cleanup or file deletion
- it does not auto-apply on login or boot in the current repo
- it does not replace `pmset`; it layers a reversible policy on top of it
- it does not ship a background daemon except the closed-lid helper when that mode is enabled

## Product Surfaces

### CLI

Use the CLI when you want:

- direct control from Terminal
- scriptable status and doctor output
- dry runs before a privileged change
- a stable source of truth behind the app

### App

Use the app when you want:

- native controls for Buoy mode
- a live dashboard of the machine state
- storage scanning with cached results and Finder reveal
- menu shortcuts for section switching

## Local State

Buoy writes local state in two main places:

- `~/.buoy/state.json`
  Purpose: restore point and current power configuration state
- `~/Library/Application Support/Buoy/storage-scan-cache.json`
  Purpose: cached storage snapshots for fast Storage tab loading

The app also stores UI and access-grant preferences in `UserDefaults`.

## Known Product Boundaries

- `Buoy.app` declares macOS `13.0` as its minimum system version.
- Current build scripts compile native binaries for the build host instead of producing universal binaries.
- CPU temperature is intentionally unavailable in the current source on Apple silicon without extra entitlements.
- Protected storage folders stay off until you explicitly grant access.

## See Also

- [Getting Started](getting-started.md)
- [Installation](installation.md)
- [Features](features.md)
- [Privacy And Permissions](privacy-and-permissions.md)
- [Compatibility](compatibility.md)

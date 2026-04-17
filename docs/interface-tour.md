# Interface Tour

## Audience

Users who have installed Buoy and want to understand the app layout quickly.

## Purpose

Explain the structure of `Buoy.app`, where each control lives, and what each section is for.

## Main Window Structure

The app window has two primary regions:

- a sidebar for section selection
- a main content area for the selected section

The sidebar order is:

1. Overview
2. Power
3. System
4. Processes
5. Services
6. Network
7. Storage

## Global Shortcuts

Available from the app menu and window:

- `Cmd+1` through `Cmd+7`
  Purpose: jump directly to a section
- `Cmd+[`
  Purpose: previous section
- `Cmd+]`
  Purpose: next section
- `Cmd+W`
  Purpose: close the main window
- `Cmd+Q`
  Purpose: quit the app

## Overview

What it shows:

- current CPU, memory, disk, and battery state
- recent trend cards
- leading CPU and memory processes
- power and thermal facts

Why it matters:

- it turns several machine signals into one fast summary

Where to find it:

- sidebar `Overview`

## Power

What it shows:

- the current Buoy mode state
- the current power source
- battery state
- closed-lid state
- a plain-text CLI readout

Controls:

- `Enable Buoy mode`
- `Allow closed-lid awake mode`
- `Display sleep`
- `Battery floor`
- `Poll interval`
- `Appearance`
- `Apply`
- `Turn Off`
- `Sleep Display`
- `Refresh`

Why it matters:

- this is the main control surface for changing power behavior

## System

What it shows:

- current CPU, memory, disk, and thermal cards
- machine facts such as power source, charge, condition, and temperatures
- a dense monospaced system readout

Control:

- `Refresh` interval popup

Why it matters:

- it is the most exact dashboard view for a single live snapshot

## Processes

What it shows:

- current processes with CPU, memory, state, and user
- summary cards for visible count, top CPU, top memory, and user count

Controls:

- search by process name
- filter by user
- sort by CPU, memory, PID, name, or user

Why it matters:

- it helps you identify what is consuming resources right now

## Services

What it shows:

- launchd services from system and user locations
- boot state, live PID, CPU, memory, and plist path

Controls:

- search by service or plist path
- filter by status
- filter by location

Why it matters:

- it shows background services and where they are defined on disk

## Network

What it shows:

- listening TCP and UDP services
- active and inactive interfaces
- primary IPv4 address and protocol footprint

Why it matters:

- it gives a local network surface summary without leaving the app

## Storage

What it shows:

- used and available disk space
- user data, reclaimable space, and system or hidden usage estimates
- capacity breakdown
- heavy items and cleanup targets
- protected-folder grant state

Controls:

- `Refresh Summary`
- `Deep Scan`
- search, scope, kind, and sort filters
- `Reveal in Finder`
- access toggles for Desktop, Documents, Downloads, Pictures, and saved custom locations

Why it matters:

- it explains where disk pressure is coming from
- it separates fast summary refreshes from slower exact file enumeration

## Appearance

The `Power` section includes an `Appearance` picker with:

- `System`
- `Light`
- `Dark`

This changes the app appearance only. It does not change Buoy mode or any machine-level setting.

## Interface Boundaries

- The app is not the source of truth for power behavior. The CLI is.
- The app reads live status from the installed `buoy` binary.
- Privileged changes happen through the macOS administrator prompt.
- Storage access stays opt-in and can remain partial until you grant more folders or run a deep scan.

## See Also

- [Features](features.md)
- [Settings Reference](settings-reference.md)
- [Workflows](workflows.md)

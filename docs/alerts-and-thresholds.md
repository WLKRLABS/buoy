# Alerts And Thresholds

## Audience

Users and maintainers who need to know how Buoy turns raw metrics into visual emphasis.

## Purpose

Document the current thresholds Buoy uses for status emphasis. Buoy does not currently implement a notification or alert-delivery system.

## Important Scope

This document covers:

- visual warning and critical thresholds
- posture changes in the `Overview` section
- freshness states in the `Storage` section

This document does not cover:

- notifications
- background alerting
- persistent monitoring rules

## Overview Thresholds

### CPU

- warning at `70%`
- critical at `90%`

Used in:

- `Overview` CPU trend card
- `Overview` CPU state card

### Memory

- warning at `78%`
- critical at `90%`

Used in:

- `Overview` memory trend card
- `Overview` memory state card

### Disk

- warning at `85%`
- critical at `94%`

Used in:

- `Overview` disk state card

### Thermal

Thermal tone rules:

- `Critical` thermal state becomes critical
- any non-nominal thermal state becomes warning
- if CPU temperature becomes available in a future implementation, warning begins at `75 C` and critical at `88 C`

### Battery

Battery tone rules while on battery:

- warning at `25%` or below
- critical at `10%` or below

If the machine is on AC power, the `Overview` battery tone stays accent.

## Overview Posture Changes

The `Overview` posture summary changes when:

- thermal tone is elevated
- CPU reaches `85%` or memory reaches `88%`
- disk reaches `92%`
- battery tone is elevated while on battery

These posture changes affect the headline summary, not the underlying machine behavior.

## Power Section Thresholds

### Battery Card

- warning when battery is below `20%`

This is a simple visual cue in the `Power` section.

### Closed-Lid Defaults

Power-control defaults in the current source:

- display sleep default: `10` minutes
- battery floor default: `25%`
- poll interval default: `20` seconds

These are defaults, not alerts.

## System Section Thresholds

The `System` section uses simpler card emphasis:

- CPU warning above `80%`
- memory warning above `85%`
- disk warning above `90%`
- thermal warning when thermal state is non-nominal

## Storage States

The `Storage` section uses state labels rather than numeric alerts.

Possible states:

- `Live`
  Meaning: current snapshot from a finished scan
- `Cached`
  Meaning: a saved storage snapshot was loaded immediately
- `Partial Scan`
  Meaning: a summary-only view exists without a matching deep-scan file list
- `Refreshing Summary`
  Meaning: a summary scan is running
- `Deep Scan Running`
  Meaning: a deep scan is running

### Freshness Window

The current storage freshness interval is:

- `30 minutes`

Meaning:

- cached storage data older than `30` minutes is treated as `Stale`
- stale data triggers an automatic summary refresh when the Storage tab opens

## What These Thresholds Mean

- They change presentation.
- They do not force Buoy mode on or off.
- They do not send alerts outside the app.
- They should be treated as operator cues, not universal system-health rules.

## See Also

- [Metrics And Definitions](metrics-and-definitions.md)
- [Settings Reference](settings-reference.md)
- [Troubleshooting](troubleshooting.md)

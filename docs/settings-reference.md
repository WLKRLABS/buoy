# Settings Reference

## Audience

Users who want a precise reference for every control Buoy exposes.

## Purpose

Document the current settings and actions in the app and the CLI defaults behind them.

## Important Scope

Buoy does not currently have a separate Settings or Preferences window.

This reference covers:

- controls in the `Power` section
- refresh cadence in the `System` section
- access and scan controls in the `Storage` section
- relevant persisted local preferences

## Power Controls

### Enable Buoy Mode

Type:

- checkbox

Purpose:

- turns Buoy mode on or off in the current configuration panel

Effect:

- when applied, Buoy either writes the managed AC profile or restores the saved one

Default:

- reflects live CLI status after refresh

### Allow Closed-Lid Awake Mode

Type:

- checkbox

Purpose:

- enables the closed-lid helper behavior

Effect:

- only matters when Buoy mode is enabled

Default:

- reflects live CLI status after refresh

Limits:

- disabled in the UI when Buoy mode is off

### Display Sleep

Type:

- slider

Purpose:

- sets the AC display sleep value Buoy will apply

CLI equivalent:

- `--display-sleep MINUTES`

Default:

- `10` minutes in the current source

Allowed range:

- `1` to `180` minutes

### Battery Floor

Type:

- slider

Purpose:

- sets the minimum battery percent for closed-lid awake mode on battery

CLI equivalent:

- `--clam-min-battery PERCENT`

Default:

- `25`

Allowed range:

- `0` to `100`

### Poll Interval

Type:

- slider

Purpose:

- sets how often the closed-lid helper rechecks battery state

CLI equivalent:

- `--clam-poll-seconds SECONDS`

Default:

- `20` seconds

Allowed range:

- `5` to `3600` seconds

### Appearance

Type:

- popup

Choices:

- `System`
- `Light`
- `Dark`

Purpose:

- changes the app appearance only

Persistence:

- stored locally in `UserDefaults` under `appearance_mode`

## Power Actions

### Apply

Purpose:

- commits the current power settings in one privileged step

Notes:

- uses the macOS administrator prompt

### Turn Off

Purpose:

- restores the saved AC settings and stops the closed-lid helper

Notes:

- uses the macOS administrator prompt

### Sleep Display

Purpose:

- runs `pmset displaysleepnow`

Notes:

- non-destructive
- does not change Buoy mode

### Refresh

Purpose:

- re-reads status from the installed `buoy` binary

## System Controls

### Refresh Interval

Type:

- popup

Choices:

- `2 sec`
- `5 sec`
- `10 sec`
- `30 sec`
- `1 min`

Purpose:

- controls the dashboard snapshot cadence for the live metrics collector

Default:

- `2 sec`

## Storage Controls

### Refresh Summary

Purpose:

- runs a bounded summary scan

Use when:

- you want updated storage totals and cleanup targets quickly

### Deep Scan

Purpose:

- runs a deeper scan and refreshes the largest-file list

Use when:

- you need exact heavy-file results from current data

### Search

Purpose:

- filters heavy items by name, path, or note

### Scope

Choices:

- `All Heavy Items`
- `Cleanup Candidates`
- `User Files`
- `Applications`
- `Developer`
- `System / Hidden`

### Kind

Choices:

- `All`
- `Folders`
- `Files`

### Sort

Choices:

- `Size`
- `Name`
- `Category`
- `Path`

### Reveal In Finder

Purpose:

- opens the selected storage item in Finder

### Protected Folders

Individual toggles:

- `Desktop`
- `Documents`
- `Downloads`
- `Pictures`

Purpose:

- allow those folders to participate in storage scans

Behavior:

- toggling on without a saved grant opens a folder chooser
- changing these settings invalidates the storage cache and starts a new summary scan

### Saved Drives & Folders

Controls:

- enable switch
- `Choose...` or `Change...` button

Purpose:

- add extra folders or drives through saved bookmarks

Behavior:

- disabled saved locations remain stored until changed or cleared in a later update

## Persisted Local Preferences

Known local persistence in the current source:

- selected app appearance
- last selected dashboard section
- protected-folder enable flags
- protected-folder bookmarks
- custom-location enable flag
- custom-location bookmarks

## CLI Defaults From Environment Variables

If the corresponding flags are not provided, the CLI reads these defaults:

- `BUOY_DISPLAY_SLEEP`
  Default fallback: `10`
- `BUOY_CLAM_MIN_BATTERY`
  Default fallback: `25`
- `BUOY_CLAM_POLL_SECONDS`
  Default fallback: `20`

## See Also

- [Advanced Usage](advanced-usage.md)
- [Interface Tour](interface-tour.md)
- [Privacy And Permissions](privacy-and-permissions.md)

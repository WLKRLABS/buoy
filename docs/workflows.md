# Workflows

## Audience

Users who want task-based instructions instead of a full reference.

## Purpose

Document the main jobs Buoy helps you complete.

## Enable Buoy Mode On AC

### Goal

Keep the computer awake on AC while allowing the display to sleep.

### Steps

1. Verify the install:

```bash
buoy doctor
```

2. Apply Buoy mode:

```bash
buoy apply
```

3. Confirm the result:

```bash
buoy status
```

### What To Expect

- `sleep` is disabled on AC
- `displaysleep` remains configurable
- wake-on-LAN and keepalive-related keys are enabled when supported

## Set A Shorter Display Sleep Time

### Goal

Keep the machine awake but let the screen sleep faster.

### Steps

```bash
buoy apply --display-sleep 5
```

Or in the app:

1. Open `Power`
2. Move `Display sleep`
3. Click `Apply`

## Use Closed-Lid Awake Mode With A Battery Floor

### Goal

Keep a notebook awake with the lid closed while plugged in, but stop doing that once battery drops below a chosen floor.

### Steps

```bash
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 15
```

Or in the app:

1. Open `Power`
2. Enable `Allow closed-lid awake mode`
3. Set `Battery floor`
4. Set `Poll interval`
5. Click `Apply`

### Notes

- this mode uses a helper process
- if that helper stops, reapply the mode

## Restore Normal AC Sleep Behavior

### Goal

Undo Buoy-managed power changes cleanly.

### Steps

```bash
buoy off
```

Or in the app:

1. Open `Power`
2. Click `Turn Off`

### Important

This depends on the restore point still being present in `~/.buoy/state.json`.

## Check The Current State From A Script

### Goal

Read Buoy status in a machine-friendly form.

### Steps

```bash
buoy status --json
```

### Use Cases

- shell scripts
- local automation
- support diagnostics

## Inspect Live Machine Load

### Goal

Find the current source of heat, CPU load, memory pressure, or disk pressure.

### Steps

1. Open `Buoy.app`
2. Start in `Overview`
3. Move to:
   - `System` for exact live values
   - `Processes` for noisy processes
   - `Services` for launchd state
   - `Network` for listening services

## Review Storage Pressure And Cleanup Targets

### Goal

Understand where disk usage is coming from and which items are worth reviewing first.

### Steps

1. Open `Storage`
2. Let cached or seed data load
3. Click `Refresh Summary`
4. Review:
   - `Capacity Summary`
   - `Capacity Breakdown`
   - `Cleanup Targets`
5. If you need the current largest-file list, click `Deep Scan`

### Notes

- summary refresh is faster
- deep scan is slower but more exact
- `Reveal in Finder` opens the selected result directly

## Grant Protected Storage Access

### Goal

Include protected folders in storage scans without granting more access than you want.

### Steps

1. Open `Storage`
2. Go to `Access Grants`
3. Enable the folder you want
4. Choose that folder or one of its parent folders in the picker

### Notes

- Desktop, Documents, Downloads, and Pictures are opt-in
- Buoy normalizes ancestor grants back to the intended folder
- choosing a descendant folder for a protected scope is rejected

## Add External Drives Or Extra Folders To Storage Scans

### Goal

Scan removable or custom locations on demand.

### Steps

1. Open `Storage`
2. In `Access Grants`, enable `Saved Drives & Folders`
3. Click `Choose...`
4. Pick one or more folders or drives

### Notes

- Buoy stores bookmarks so selections survive app relaunches
- changing saved locations invalidates the storage cache

## Put The CLI On Your PATH

### Goal

Make `buoy` available from new shell sessions.

### Steps

```bash
buoy path-add
```

### Notes

- Buoy updates the shell rc file it detects from your current shell
- restart the shell or source the file afterward

## Sleep The Display Without Changing Buoy Mode

### Goal

Turn the screen off immediately while leaving the underlying power policy alone.

### Steps

```bash
buoy screen-off
```

Or click `Sleep Display` in the app.

## See Also

- [Getting Started](getting-started.md)
- [Settings Reference](settings-reference.md)
- [Troubleshooting](troubleshooting.md)

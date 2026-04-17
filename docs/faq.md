# FAQ

## Audience

Users who want short answers to common questions.

## Purpose

Answer recurring product and behavior questions without making the reference docs longer.

## Does Buoy Keep My Mac Awake All The Time?

No.

Buoy manages a server-friendly AC profile. Closed-lid awake mode is optional and only stays active on battery above the configured floor.

## Does Buoy Keep The Display Awake?

No by default.

Buoy separates full idle sleep from display sleep, so the screen can still sleep after the configured number of minutes.

## Does Buoy Change Battery Power Settings?

Not in the same way it changes AC power settings.

Buoy's main managed profile is AC-focused. Closed-lid mode can also manage `SleepDisabled` on battery above a threshold.

## Can I Use Buoy Without The App?

Yes.

The CLI is the source of truth. The app is a native control surface and dashboard around it.

## Can I Use The App Without Installing The CLI?

Not reliably.

The app reads status from the installed `buoy` binary and uses the CLI contract for power actions.

## Does Buoy Start Automatically At Login?

Not in the current repo.

No launch-at-login or auto-apply-on-boot behavior is documented in the source.

## Does Buoy Send Telemetry Or Cloud Data?

The app and CLI do not show telemetry or cloud-upload behavior in the current source.

The remote installer can fetch release assets or source archives from GitHub when you use it that way.

## Where Does Buoy Store State?

Primary paths:

- `~/.buoy/state.json`
- `~/Library/Application Support/Buoy/storage-scan-cache.json`

## Why Does `buoy off` Matter So Much?

Because `buoy off` restores the saved AC profile.

That restore point lives in the Buoy state file.

## Why Is CPU Temperature Missing?

Because the current source intentionally returns `nil` for CPU temperature and relies on thermal pressure instead.

## Why Does Storage Use A Summary Scan And A Deep Scan?

Because those jobs have different costs.

- summary refresh is fast and good for the main capacity story
- deep scan is slower but needed for current largest-file results

## Why Is A Protected Folder Disabled By Default?

Because Buoy keeps sensitive folders opt-in and avoids surprise permission prompts.

## Does Buoy Delete Files For Me?

No.

The Storage page helps you inspect cleanup targets and reveal them in Finder. Deletion stays your choice.

## Does Buoy Build Universal Binaries?

Not from the current build scripts.

Current scripts compile native binaries for the build host.

## See Also

- [Overview](overview.md)
- [Compatibility](compatibility.md)
- [Privacy And Permissions](privacy-and-permissions.md)

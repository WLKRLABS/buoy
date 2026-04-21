# Installation

## Audience

Users installing Buoy for the first time, updating an existing install, or building it from source.

## Purpose

Document every supported install path, the default install locations, and the local requirements behind each path.

## Install Methods

### Method 1: Install From The Latest Release

Recommended when you want the normal end-user path.

```bash
curl -fsSL https://github.com/WLKRLABS/buoy/releases/latest/download/install.sh | bash
```

What the installer does:

- tries to download the latest release assets first
- installs `buoy`
- installs `Buoy.app`
- falls back to the matching release source archive if release assets cannot be downloaded

### Method 2: Install From A Local Clone

Recommended when you already have the repo checked out.

```bash
./install.sh
```

This path builds locally if needed and then copies the CLI and app into the install directories.

### Method 3: Build Without Installing

Use this when you are testing the repo or working on Buoy itself.

```bash
./scripts/build-cli.sh
./scripts/build-app.sh
```

Artifacts land in `dist/`.

## Default Install Locations

- CLI: `~/.local/bin/buoy`
- App: `~/Applications/Buoy.app`

Override them with:

```bash
./install.sh --bin-dir /custom/bin --app-dir /custom/apps
```

Or via environment variables:

- `BIN_DIR`
- `APP_DIR`

## Remote Installer Environment Variables

The remote installer also accepts:

- `DOWNLOAD_REPO`
  Purpose: choose the GitHub repo used for release assets or source fallback
- `DOWNLOAD_RELEASE_TAG`
  Purpose: pin release downloads to a specific tag instead of `latest`
- `DOWNLOAD_REF`
  Purpose: choose the Git ref for source fallback
- `DOWNLOAD_RELEASES`
  Purpose: set to `0` to skip release downloads and force a source build
- `LOCAL_RELEASE_DIR`
  Purpose: install directly from a local packaged release directory

## PATH Setup

If `~/.local/bin` is not already on your shell `PATH`, Buoy may install successfully but still fail as a shell command.

Add it with:

```bash
buoy path-add
```

Or add it manually in your shell profile.

## Verify The Install

Run:

```bash
buoy doctor
buoy status --json
```

Confirm:

- the CLI runs
- the state paths are printed correctly
- JSON output is returned for `status --json`

## Update An Existing Install

Update by running the same install command again:

```bash
curl -fsSL https://github.com/WLKRLABS/buoy/releases/latest/download/install.sh | bash
```

Or from a clone:

```bash
./install.sh
```

Buoy does not currently document an in-app updater.

## Uninstall

Remove the default installed artifacts:

```bash
./scripts/uninstall.sh
```

By default this removes:

- `~/.local/bin/buoy`
- `~/Applications/Buoy.app`

It does not remove:

- `~/.buoy/state.json`
- `~/Library/Application Support/Buoy/storage-scan-cache.json`
- app preferences in `UserDefaults`

Remove those manually only if you want a full reset.

## Source Build Requirements

For source builds, the repo expects:

- macOS
- Xcode command-line tools or Xcode with a working `swiftc`
- access to the active macOS SDK through `xcrun --show-sdk-path`

Use the repo scripts rather than calling `swiftc` directly.

## Signing And Trust Notes

- `scripts/build-app.sh` signs the app bundle.
- `scripts/setup-local-signing.sh` can create a stable self-signed identity for repeated local builds.
- GitHub release builds are not notarized in the current repo.
- `install.sh` clears extended attributes on the installed app bundle when `xattr` is available.

If macOS still blocks the app, see [Troubleshooting](troubleshooting.md#macos-warns-when-opening-the-app).

## See Also

- [Getting Started](getting-started.md)
- [Compatibility](compatibility.md)
- [Developer Build And Run](developer/build-and-run.md)

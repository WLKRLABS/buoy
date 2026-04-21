# Build And Run

## Audience

Developers building Buoy locally.

## Purpose

Document the local prerequisites, build scripts, outputs, and the safest way to run the app and CLI during development.

## Requirements

- macOS
- Xcode command-line tools or Xcode with working `xcrun` and `swiftc`
- access to the active macOS SDK

Useful checks:

```bash
xcrun --find swiftc
xcrun --show-sdk-path
```

## Build The CLI

```bash
./scripts/build-cli.sh
```

Output:

- `dist/buoy`

## Build The App

```bash
./scripts/build-app.sh
```

Output:

- `dist/Buoy.app`

Important behavior:

- the app build script first builds the CLI
- the app bundle includes a copy of the built CLI in `Contents/Resources/bin/buoy`
- the app declares bundle identifier `com.scwlkr.buoy`

## Run The Built Artifacts

Run the CLI from the build output:

```bash
./dist/buoy help
```

Open the app:

```bash
open dist/Buoy.app
```

## Install The Local Build

Use the repo installer:

```bash
./install.sh
```

Why:

- it installs both artifacts together
- it mirrors the documented local install path

## Local Signing For Repeat Development Builds

If you rebuild the app often and want a stable local identity:

```bash
./scripts/setup-local-signing.sh
./scripts/build-app.sh
```

What it does:

- creates a local self-signed code-signing identity
- writes an env file that `build-app.sh` loads automatically

## Build Outputs

Primary output directories:

- `dist/`
  Purpose: local build artifacts
- `dist/release/`
  Purpose: packaged release artifacts

## Package Release Assets Locally

```bash
./scripts/package-release.sh
```

Outputs:

- `dist/release/buoy`
- `dist/release/Buoy.app.zip`
- `dist/release/install.sh`
- `dist/release/SHA256SUMS.txt`

Verify the packaged release:

```bash
./scripts/verify-release.sh
```

## Common Problems

- if `swiftc` cannot be found, fix the Apple toolchain first
- if the app opens but status fails, verify `./dist/buoy status --json`
- if permissions drift across local app rebuilds, use the local signing setup

## Related Docs

- [Testing](testing.md)
- [Release Process](release-process.md)
- [Installation](../installation.md)

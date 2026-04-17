# Changelog

This changelog is intentionally lightweight. Each released version gets one short section with the user-visible changes that matter.

## [Unreleased]

### Added

### Changed

### Fixed

### Removed

## [0.3.1] - 2026-04-16

### Added

- Added a dedicated Storage dashboard tab with a deeper disk scan, largest files and folders table, cleanup-focused filters, and a breakdown graph that makes hidden or system-heavy usage easier to spot.
- Added opt-in Storage access controls for protected folders plus saved-location bookmarks for extra folders and drives so scans do not spam permission prompts and your grants persist across app relaunches.
- Added a complete documentation system for users, power users, developers, and automation tools, including structured machine-readable product references.

### Changed

- Changed the Storage tab to open from a persisted snapshot instantly, refresh folder summaries in the background when data is stale, and reserve the full largest-files pass for the manual `Deep Scan` action.
- Reworked the Buoy app shell into a retro, keyboard-friendly control surface with a sidebar section navigator, explicit View menu shortcuts, and cleaner power/dashboard hierarchy.
- Updated the dashboard panels, cards, and tables to use a more consistent utilitarian visual system instead of the previous mismatched default AppKit styling.
- Reworked the Overview, Power, System, Processes, Services, Network, and Storage pages into a more structured stage-based layout so each tab reads in a clearer order and holds its composition more reliably as the window resizes.
- Added a guarded `./scripts/release.sh` flow for release prep and tagging so version bumps, changelog rollups, build validation, and release-tag safety checks run through one path instead of several manual steps.

### Fixed

- Fixed a startup crash in the app shell where restoring or applying the current sidebar section could recurse until `Buoy.app` crashed on launch.
- Fixed the app window and dashboard layouts so they hold up better at both smaller and larger sizes, including wrapped controls for dense tabs like Storage.
- Fixed the sidebar section navigator so labels no longer clip against the right border at common window sizes.
- Fixed missing window and section navigation affordances by wiring `⌘W`, `⌘Q`, `⌘1` through `⌘7`, and section cycling commands into the native menu bar.
- Fixed the Storage tab summary refresh so it uses a macOS-closer disk-used metric, normalizes protected-folder grants like `~` back to the intended Desktop/Documents/Downloads/Pictures folders, and avoids stalling on giant system roots.
- Fixed repeated Photos permission popups by making `Pictures` opt-in for storage scans and signing the built app bundle with a stable identifier so macOS can persist app permissions.
- Fixed local build identity drift by adding a repo-managed local signing setup so Buoy can keep the same macOS code-signing identity across local rebuilds and installs.
- Fixed release packaging so `Buoy.app` builds can continue when `iconutil` rejects the generated iconset instead of failing the entire local or CI release flow.
- Fixed local app builds so a stale repo-managed signing identity now falls back to ad hoc signing instead of breaking release prep on machines with an old keychain setup.

## [0.2.0] - 2026-04-15

### Added

- Added a live sleep-behavior summary card in the Power tab so it is obvious when Buoy will keep the Mac awake, let the display sleep, or restore normal sleep.

### Fixed

- Fixed the Power tab status refresh path so the app can decode `buoy status --json` without falling back to `Status unavailable`.
- Clarified the power status copy to show whether sleep is currently prevented or allowed.

## [0.1.1] - 2026-04-09

### Fixed

- Fixed the piped `install.sh` path so remote installs no longer emit a `BASH_SOURCE[0]` shell error.

## [0.1.0] - 2026-04-09

### Added

- Formal SemVer source of truth in `VERSION`.
- Lightweight release policy, contributor bump rules, and release notes template.
- CI validation for version, changelog, builds, and packaged assets.

### Changed

- Build scripts now read the app and CLI version from `VERSION` instead of hardcoded values.

## Versioning Rules

- Use `MAJOR.MINOR.PATCH`.
- Keep `Unreleased` at the top.
- Add entries only for public-facing changes, fixes, or release-process changes that affect users or contributors.

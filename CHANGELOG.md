# Changelog

This changelog is intentionally lightweight. Each released version gets one short section with the user-visible changes that matter.

## [Unreleased]

### Added

- Added a dedicated Storage dashboard tab with a deeper disk scan, largest files and folders table, cleanup-focused filters, and a breakdown graph that makes hidden or system-heavy usage easier to spot.
- Added opt-in Storage access controls for protected folders plus saved-location bookmarks for extra folders and drives so scans do not spam permission prompts and your grants persist across app relaunches.

### Changed

- Changed the Storage tab to open from a persisted snapshot instantly, refresh folder summaries in the background when data is stale, and reserve the full largest-files pass for the manual `Deep Scan` action.
- Reworked the Buoy app shell into a retro, keyboard-friendly control surface with a sidebar section navigator, explicit View menu shortcuts, and cleaner power/dashboard hierarchy.
- Updated the dashboard panels, cards, and tables to use a more consistent utilitarian visual system instead of the previous mismatched default AppKit styling.

### Fixed

- Fixed the app window and dashboard layouts so they hold up better at both smaller and larger sizes, including wrapped controls for dense tabs like Storage.
- Fixed missing window and section navigation affordances by wiring `⌘W`, `⌘Q`, `⌘1` through `⌘7`, and section cycling commands into the native menu bar.

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

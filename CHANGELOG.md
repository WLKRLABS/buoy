# Changelog

This changelog is intentionally lightweight. Each released version gets one short section with the user-visible changes that matter.

## [Unreleased]

- No unreleased changes yet.

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

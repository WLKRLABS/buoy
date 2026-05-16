# Documentation

## Purpose

This is the canonical map for Buoy documentation. Start here after the root README when you need installation steps, user workflows, source-backed architecture, maintenance rules, or machine-readable product references.

## Reader path

New users:

1. [Overview](overview.md)
2. [Getting started](getting-started.md)
3. [Installation](installation.md)
4. [Interface tour](interface-tour.md)
5. [Workflows](workflows.md)
6. [Troubleshooting](troubleshooting.md)

Power users:

1. [Features](features.md)
2. [Settings reference](settings-reference.md)
3. [Metrics and definitions](metrics-and-definitions.md)
4. [Alerts and thresholds](alerts-and-thresholds.md)
5. [Advanced usage](advanced-usage.md)

Trust, support, and boundaries:

1. [Privacy and permissions](privacy-and-permissions.md)
2. [Compatibility](compatibility.md)
3. [Accessibility](accessibility.md)
4. [FAQ](faq.md)
5. [Changelog guide](changelog.md)

Maintainers:

1. [Architecture](architecture.md)
2. [Developer architecture](developer/architecture.md)
3. [Data flow](developer/data-flow.md)
4. [Build and run](developer/build-and-run.md)
5. [Testing](developer/testing.md)
6. [Contributing](developer/contributing.md)
7. [Release process](developer/release-process.md)
8. [ADR-001: Swift CLI and Swift wrapper](adr/ADR-001-swift-cli-and-swift-wrapper.md)

Documentation maintenance:

1. [Glossary](glossary.md)
2. [Style guide](style-guide.md)
3. [Deprecated docs](deprecated/)

Machine-readable references:

- [Product spec](machine/product-spec.json)
- [Feature map](machine/feature-map.yaml)
- [Machine glossary](machine/glossary.json)
- [Troubleshooting map](machine/troubleshooting-map.json)

## Active docs audit

| Path | Role |
| --- | --- |
| `README.md` | GitHub front door and quick start. |
| `docs/README.md` | Canonical docs map and reader path. |
| `docs/overview.md` | Product identity, audience, surfaces, and boundaries. |
| `docs/getting-started.md` | First successful install, apply, inspect, and restore path. |
| `docs/installation.md` | Install, update, uninstall, PATH, signing, and trust notes. |
| `docs/interface-tour.md` | App sections, controls, shortcuts, and interface boundaries. |
| `docs/features.md` | User-visible features and limits. |
| `docs/settings-reference.md` | CLI and app settings by control. |
| `docs/workflows.md` | Task-based operating procedures. |
| `docs/troubleshooting.md` | Symptom-driven checks and fixes. |
| `docs/advanced-usage.md` | Scriptable and power-user CLI patterns. |
| `docs/metrics-and-definitions.md` | Dashboard metric definitions and caveats. |
| `docs/alerts-and-thresholds.md` | Display thresholds and posture labels. |
| `docs/privacy-and-permissions.md` | Local data, prompts, bookmarks, and network behavior. |
| `docs/compatibility.md` | Supported macOS, architecture, hardware, and distribution limits. |
| `docs/accessibility.md` | Source-backed accessibility status and manual test gaps. |
| `docs/faq.md` | Short answers for common support questions. |
| `docs/changelog.md` | Guide to the canonical root changelog. |
| `docs/architecture.md` | Source-backed architecture overview for readers and maintainers. |
| `docs/developer/*.md` | Contributor, build, test, data-flow, and release details. |
| `docs/adr/*.md` | Architecture decision history. |
| `docs/machine/*` | Structured product references for tools and agents. |

## Deprecated docs

Historical planning notes live in [deprecated](deprecated/). They are preserved for context, but they are not part of the active reader path.

Current replacements:

- `docs/deprecated/brand-system.md` -> [Style guide](style-guide.md) and [Glossary](glossary.md)
- `docs/deprecated/launch-risks.md` -> [Compatibility](compatibility.md) and [Release process](developer/release-process.md)
- `docs/deprecated/storage-speed-plan.md` -> [Features](features.md), [Metrics and definitions](metrics-and-definitions.md), and [Developer architecture](developer/architecture.md)
- `docs/deprecated/technical-roadmap.md` -> [Architecture](architecture.md), [Developer architecture](developer/architecture.md), and [ADR-001](adr/ADR-001-swift-cli-and-swift-wrapper.md)
- `docs/deprecated/ux-foundation.md` -> [Interface tour](interface-tour.md), [Settings reference](settings-reference.md), and [Style guide](style-guide.md)

## Suspicious docs kept

The following active docs have names that can look like planning or duplicate material, but they serve current roles:

- `docs/changelog.md` is a changelog guide. The canonical release history remains `CHANGELOG.md`.
- `docs/adr/ADR-001-swift-cli-and-swift-wrapper.md` is a historical architecture decision record.
- `docs/machine/product-spec.json` is a structured product reference, not a planning spec.

## Source of truth

When prose and source disagree, verify against the current repo before editing docs:

- CLI help and dry runs from `./dist/buoy`
- `Sources/BuoyCore/` and `Sources/buoy/main.swift`
- `Sources/BuoyApp/`
- `scripts/`
- `.github/workflows/`
- `VERSION`, `CHANGELOG.md`, `VERSIONING.md`, and `CONTRIBUTING.md`

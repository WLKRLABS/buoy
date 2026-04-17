# Contributing

## Audience

Developers contributing code or documentation to Buoy.

## Purpose

Define the working expectations for changes to the public product surface, internal implementation, and documentation system.

## Core Rules

- use the repo scripts, not ad hoc build commands
- treat `VERSION` as the single version source of truth
- do not bump `VERSION` during normal feature work
- update `CHANGELOG.md` for user-visible CLI, app, installer, or public-doc changes
- keep the CLI as the source of truth for power behavior

## Docs Are Part Of The Product

If you change:

- CLI flags or output
- app behavior or labels
- installer behavior
- release behavior
- user-facing docs in `README.md` or `docs/`

You must update the docs in the same change.

## Before You Start

Read:

- [`README.md`](../../README.md)
- [`CHANGELOG.md`](../../CHANGELOG.md)
- [`VERSIONING.md`](../../VERSIONING.md)
- [`CONTRIBUTING.md`](../../CONTRIBUTING.md)

Then review the relevant docs in `docs/` for the area you are changing.

## Typical Change Workflow

1. Identify whether the change touches the public surface.
2. Update the relevant docs while you implement the change.
3. Add or update a short changelog bullet under `Unreleased` if the change is public.
4. Run the local validation commands.
5. Open the PR without touching `VERSION` unless you are doing release prep.

## Local Validation

Run these before opening a PR:

```bash
bash scripts/validate-versioning.sh
./scripts/smoke-test.sh
./scripts/build-cli.sh
./scripts/build-app.sh
./scripts/test-storage-scanner.sh
./scripts/test-storage-cache.sh
```

Also run shell syntax checks when you touch scripts:

```bash
bash -n install.sh scripts/*.sh buoy
```

## Documentation Expectations

Write docs that are:

- specific
- version-aware
- concise
- explicit about uncertainty

Do not:

- invent product behavior
- let docs and UI labels drift apart
- bury important limitations in roadmap-only documents

## Code Expectations

- preserve the CLI contract unless a change is intentional and documented
- keep app power actions routed through the CLI
- preserve restore behavior as a first-class concern
- prefer narrow, local changes over speculative abstractions

## Release Hygiene

- never bump `VERSION` for routine feature PRs
- add user-visible doc changes to the changelog
- use tag format `vX.Y.Z`
- use `./scripts/release.sh prepare X.Y.Z` and `./scripts/release.sh tag` for the release path

For full release steps, see [Release Process](release-process.md).

## Existing Internal Notes

This repo still contains internal product notes such as:

- `docs/technical-roadmap.md`
- `docs/brand-system.md`
- `docs/ux-foundation.md`

Treat them as supporting context, not as substitutes for the main docs suite.

## Related Docs

- [Architecture](architecture.md)
- [Build And Run](build-and-run.md)
- [Testing](testing.md)
- [Release Process](release-process.md)

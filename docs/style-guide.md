# Style guide

## Purpose

Define how Buoy docs should read, link, name things, and retire outdated material.

## Default style

- short sentences
- active voice
- operational wording
- no filler
- present tense for current behavior
- explicit uncertainty instead of guesses
- source-backed claims only

## Voice

Buoy docs should feel calm, exact, and native to a macOS utility project.

Use:

- direct nouns and verbs
- concrete command names
- exact file paths and settings when verified
- short paragraphs and lists

Avoid:

- hype
- decorative copy
- broad "optimize" claims
- future promises without a source-backed plan
- hidden assumptions about signing, architecture support, telemetry, or release status

## Headings

- Use sentence case for headings.
- Keep UI labels exact when the heading names a control or button.
- Keep acronyms and product names as written in source.
- Prefer stable, scannable headings over clever names.

Examples:

- `## Quick start`
- `## Current limits`
- `### Deep Scan`
- `### Buoy.app`

## Filenames

- Use lowercase kebab-case for active prose docs.
- Use clear nouns, for example `settings-reference.md` and `privacy-and-permissions.md`.
- Keep machine-readable docs under `docs/machine/`.
- Keep historical docs under `docs/deprecated/`.
- Do not add new active docs named `plan`, `phase`, `roadmap`, `draft`, `notes`, `PRD`, `SDD`, or `TDD` unless they are explicitly current and justified in `docs/README.md`.

## README rules

- lead with what the tool does
- show the install command immediately
- explain restore behavior early
- keep future ideas out of the primary flow
- link to `docs/README.md` instead of duplicating the entire docs tree

## CLI copy rules

- name the command effect directly
- include exact values when configuration changes
- on failure, say what was missing or invalid
- on success, prefer two short lines over one long paragraph

## App copy rules

- labels must stay under three words when possible
- status text should be scannable in a terminal style block
- avoid decorative copy in the main window
- use glossary terms consistently

## Links

- Use relative links inside docs.
- Link to the canonical home for a topic instead of repeating full explanations.
- After moving or renaming docs, run a relative-link check.
- Do not guess ambiguous targets. Leave a clear unresolved question instead.

## Deprecation rules

Move retired docs to `docs/deprecated/`.

Each deprecated doc must keep its original content and add a short note at the top with:

- original path
- reason
- replacement

Do not delete historical docs unless they are empty, accidental, generated, exact duplicates, or explicitly approved for deletion.

## Machine-readable docs

Machine docs must stay parseable:

- `docs/machine/product-spec.json`
- `docs/machine/feature-map.yaml`
- `docs/machine/glossary.json`
- `docs/machine/troubleshooting-map.json`

When prose changes a product fact, update the related machine doc if the structured reference would otherwise drift.

## Release notes rules

- group by CLI, app, installer, docs
- describe user-facing outcomes first
- avoid internal implementation detail unless it changes behavior

## Verification

Useful docs validation:

```bash
bash scripts/validate-versioning.sh
./scripts/smoke-test.sh
git diff --check
```

For larger docs rewrites, also parse machine docs and check relative Markdown links.

# Changelog Guide

## Audience

Users and maintainers who need to know where release history lives and how to read it.

## Purpose

Point to the canonical release log and explain the structure Buoy uses for version history.

## Canonical Changelog

The canonical release history is:

- [`/CHANGELOG.md`](../CHANGELOG.md)

This file exists to document the structure and entry rules without duplicating the actual release history.

## Version Format

Buoy uses plain semantic versions:

- `MAJOR.MINOR.PATCH`

The single source of truth for the current version is:

- [`/VERSION`](../VERSION)

## Changelog Structure

The root changelog keeps:

- one top-level `Unreleased` section
- one section per released version
- short user-facing bullets under `Added`, `Changed`, `Fixed`, and `Removed` when needed

## What Belongs In The Changelog

Include:

- CLI behavior changes
- app behavior changes
- installer behavior changes
- public documentation changes that materially affect users or contributors

Do not include:

- internal-only refactors with no public effect
- low-signal implementation details that do not change behavior

## Related Policy

See also:

- [Versioning Policy](../VERSIONING.md)
- [Developer Release Process](developer/release-process.md)

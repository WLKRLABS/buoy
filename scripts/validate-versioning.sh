#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$("$ROOT_DIR/scripts/version.sh" version)"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"

if [[ ! -f "$CHANGELOG_FILE" ]]; then
  echo "CHANGELOG.md is missing." >&2
  exit 1
fi

if ! grep -Eq '^## \[Unreleased\]' "$CHANGELOG_FILE"; then
  echo "CHANGELOG.md must contain an [Unreleased] section." >&2
  exit 1
fi

if ! grep -Eq "^## \\[$VERSION\\]" "$CHANGELOG_FILE"; then
  echo "CHANGELOG.md must contain a section for version $VERSION." >&2
  exit 1
fi

echo "Versioning validation passed for $VERSION"

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$("$ROOT_DIR/scripts/version.sh" version)"
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"
OUTPUT_FILE="${1:-$ROOT_DIR/dist/release-notes.md}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

awk -v version="$VERSION" '
  $0 ~ "^## \\[" version "\\]" { printing=1; next }
  printing && $0 ~ "^## \\[" { exit }
  printing { print }
' "$CHANGELOG_FILE" > "$OUTPUT_FILE"

if [[ ! -s "$OUTPUT_FILE" ]]; then
  echo "Could not render release notes for version $VERSION." >&2
  exit 1
fi

echo "Release notes written to $OUTPUT_FILE"

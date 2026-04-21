#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$("$ROOT_DIR/scripts/version.sh" version)"
TAG="v$VERSION"
DEFAULT_REPO="${DEFAULT_REPO:-WLKRLABS/buoy}"
SOURCE_FILE="$ROOT_DIR/install.sh"
OUTPUT_FILE="${1:-$ROOT_DIR/dist/release/install.sh}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

awk -v tag="$TAG" -v repo="$DEFAULT_REPO" '
  BEGIN { repo_written = 0; release_tag_written = 0; ref_written = 0 }
  /^DOWNLOAD_REPO=/ {
    print "DOWNLOAD_REPO=\"${DOWNLOAD_REPO:-" repo "}\""
    repo_written = 1
    next
  }
  /^DOWNLOAD_RELEASE_TAG=/ {
    print "DOWNLOAD_RELEASE_TAG=\"${DOWNLOAD_RELEASE_TAG:-" tag "}\""
    release_tag_written = 1
    next
  }
  /^DOWNLOAD_REF=/ {
    print "DOWNLOAD_REF=\"${DOWNLOAD_REF:-" tag "}\""
    ref_written = 1
    next
  }
  { print }
  END {
    if (!repo_written || !release_tag_written || !ref_written) {
      exit 1
    }
  }
' "$SOURCE_FILE" > "$OUTPUT_FILE"

chmod +x "$OUTPUT_FILE"
echo "Installer written to $OUTPUT_FILE"

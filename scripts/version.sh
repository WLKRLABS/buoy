#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"

usage() {
  cat <<'EOF'
Usage:
  scripts/version.sh version
  scripts/version.sh tag
  scripts/version.sh build-number
EOF
}

read_version() {
  if [[ ! -f "$VERSION_FILE" ]]; then
    echo "VERSION file is missing." >&2
    exit 1
  fi

  local version
  version="$(tr -d '[:space:]' < "$VERSION_FILE")"

  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must be plain SemVer in X.Y.Z form." >&2
    exit 1
  fi

  printf '%s\n' "$version"
}

build_number() {
  if [[ -n "${BUILD_NUMBER:-}" ]]; then
    printf '%s\n' "$BUILD_NUMBER"
    return
  fi

  if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$ROOT_DIR" rev-list --count HEAD
    return
  fi

  printf '1\n'
}

command="${1:-}"

case "$command" in
  version)
    read_version
    ;;
  tag)
    printf 'v%s\n' "$(read_version)"
    ;;
  build-number)
    build_number
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=""
if [[ -n "${BASH_SOURCE[0]-}" && -f "${BASH_SOURCE[0]}" ]]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
DOWNLOAD_REPO="${DOWNLOAD_REPO:-}"
DOWNLOAD_RELEASE_TAG="${DOWNLOAD_RELEASE_TAG:-}"
DOWNLOAD_REF="${DOWNLOAD_REF:-}"
DOWNLOAD_RELEASES="${DOWNLOAD_RELEASES:-1}"
LOCAL_RELEASE_DIR="${LOCAL_RELEASE_DIR:-}"

usage() {
  cat <<EOF
Usage:
  ./install.sh [--bin-dir DIR] [--app-dir DIR]

Environment:
  BIN_DIR       Override the CLI install directory.
  APP_DIR       Override the app install directory.
  DOWNLOAD_REPO Set the GitHub repo used for remote installs, for example owner/repo.
  DOWNLOAD_RELEASE_TAG Override the GitHub release tag used for release-asset installs.
  DOWNLOAD_REF  Override the Git ref used for remote installs.
  DOWNLOAD_RELEASES  Set to 0 to skip release asset downloads.
  LOCAL_RELEASE_DIR Install directly from a local packaged release directory.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bin-dir)
      shift
      BIN_DIR="$1"
      ;;
    --app-dir)
      shift
      APP_DIR="$1"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

mkdir -p "$BIN_DIR" "$APP_DIR"

sanitize_app_bundle() {
  local app_path="$1"
  if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$app_path" || true
  fi
}

install_release_assets() {
  local release_dir="$1"
  local cli_asset="$release_dir/buoy"
  local app_archive="$release_dir/Buoy.app.zip"

  if [[ ! -f "$cli_asset" ]]; then
    echo "Missing release CLI asset at $cli_asset" >&2
    exit 1
  fi

  if [[ ! -f "$app_archive" ]]; then
    echo "Missing release app archive at $app_archive" >&2
    exit 1
  fi

  cp "$cli_asset" "$BIN_DIR/buoy"
  chmod +x "$BIN_DIR/buoy"
  rm -rf "$APP_DIR/Buoy.app"
  ditto -x -k "$app_archive" "$APP_DIR"
  sanitize_app_bundle "$APP_DIR/Buoy.app"
  echo "Installed buoy at $BIN_DIR/buoy"
  echo "Installed Buoy.app at $APP_DIR/Buoy.app"
}

download_release_assets() {
  local tmp_dir="$1"
  local base_url

  if [[ -n "$DOWNLOAD_RELEASE_TAG" ]]; then
    base_url="https://github.com/$DOWNLOAD_REPO/releases/download/$DOWNLOAD_RELEASE_TAG"
  else
    base_url="https://github.com/$DOWNLOAD_REPO/releases/latest/download"
  fi

  curl -fsSL "$base_url/buoy" -o "$tmp_dir/buoy" || return 1
  curl -fsSL "$base_url/Buoy.app.zip" -o "$tmp_dir/Buoy.app.zip" || return 1
  return 0
}

latest_release_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
    awk -F'"' '/"tag_name"[[:space:]]*:/ { print $4; exit }'
}

resolved_source_ref() {
  if [[ -n "$DOWNLOAD_REF" ]]; then
    printf '%s\n' "$DOWNLOAD_REF"
    return
  fi

  if [[ -n "$DOWNLOAD_RELEASE_TAG" ]]; then
    printf '%s\n' "$DOWNLOAD_RELEASE_TAG"
    return
  fi

  if [[ "$DOWNLOAD_RELEASES" == "1" ]]; then
    local latest_tag
    latest_tag="$(latest_release_tag "$DOWNLOAD_REPO" || true)"
    if [[ -n "$latest_tag" ]]; then
      printf '%s\n' "$latest_tag"
      return
    fi
  fi

  printf 'main\n'
}

archive_url_for_ref() {
  local repo="$1"
  local ref="$2"

  if [[ "$ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'https://codeload.github.com/%s/tar.gz/refs/tags/%s\n' "$repo" "$ref"
    return
  fi

  printf 'https://codeload.github.com/%s/tar.gz/refs/heads/%s\n' "$repo" "$ref"
}

require_download_repo() {
  if [[ -z "$DOWNLOAD_REPO" ]]; then
    echo "DOWNLOAD_REPO must be set for remote installs, for example owner/repo." >&2
    exit 1
  fi
}

if [[ -n "$LOCAL_RELEASE_DIR" ]]; then
  install_release_assets "$LOCAL_RELEASE_DIR"
  exit 0
fi

if [[ -n "$ROOT_DIR" && -f "$ROOT_DIR/Sources/BuoyCore/BuoyEngine.swift" ]]; then
  SOURCE_DIR="$ROOT_DIR"
else
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  require_download_repo

  if [[ "$DOWNLOAD_RELEASES" == "1" ]] && download_release_assets "$TMP_DIR"; then
    if [[ -n "$DOWNLOAD_RELEASE_TAG" ]]; then
      echo "Using release assets from $DOWNLOAD_REPO@$DOWNLOAD_RELEASE_TAG"
    else
      echo "Using latest release assets from $DOWNLOAD_REPO"
    fi
    install_release_assets "$TMP_DIR"
    exit 0
  fi

  RESOLVED_REF="$(resolved_source_ref)"
  ARCHIVE_URL="$(archive_url_for_ref "$DOWNLOAD_REPO" "$RESOLVED_REF")"
  echo "Falling back to source build from $ARCHIVE_URL"
  curl -fsSL "$ARCHIVE_URL" | tar -xz -C "$TMP_DIR"
  SOURCE_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d | tail -n +2 | head -n 1)"
fi

OUTPUT_DIR="$SOURCE_DIR/dist"
OUTPUT_DIR="$OUTPUT_DIR" "$SOURCE_DIR/scripts/build-cli.sh"
OUTPUT_DIR="$OUTPUT_DIR" "$SOURCE_DIR/scripts/build-app.sh"

cp "$OUTPUT_DIR/buoy" "$BIN_DIR/buoy"
chmod +x "$BIN_DIR/buoy"

rm -rf "$APP_DIR/Buoy.app"
cp -R "$OUTPUT_DIR/Buoy.app" "$APP_DIR/Buoy.app"
sanitize_app_bundle "$APP_DIR/Buoy.app"

echo "Installed buoy at $BIN_DIR/buoy"
echo "Installed Buoy.app at $APP_DIR/Buoy.app"

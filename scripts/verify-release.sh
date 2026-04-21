#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="${1:-$ROOT_DIR/dist/release}"
VERSION="$("$ROOT_DIR/scripts/version.sh" version)"
TMP_DIR="$(mktemp -d)"
BIN_DIR="$TMP_DIR/bin"
APP_DIR="$TMP_DIR/apps"
INSTALLED_APP="$APP_DIR/Buoy.app"
INSTALLED_CLI="$BIN_DIR/buoy"

cleanup() {
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

fail() {
  echo "$*" >&2
  exit 1
}

[[ -f "$RELEASE_DIR/buoy" ]] || fail "Missing $RELEASE_DIR/buoy"
[[ -f "$RELEASE_DIR/Buoy.app.zip" ]] || fail "Missing $RELEASE_DIR/Buoy.app.zip"
[[ -f "$RELEASE_DIR/install.sh" ]] || fail "Missing $RELEASE_DIR/install.sh"
[[ -f "$RELEASE_DIR/SHA256SUMS.txt" ]] || fail "Missing $RELEASE_DIR/SHA256SUMS.txt"

test "$("$RELEASE_DIR/buoy" version)" = "$VERSION" || fail "Release CLI version mismatch."

app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$RELEASE_DIR/Buoy.app/Contents/Info.plist")"
test "$app_version" = "$VERSION" || fail "Release app version mismatch."

for asset in buoy Buoy.app.zip install.sh; do
  expected_hash="$(awk -v asset="$asset" '$2 == asset { print $1; exit }' "$RELEASE_DIR/SHA256SUMS.txt")"
  actual_hash="$(shasum -a 256 "$RELEASE_DIR/$asset" | awk '{ print $1 }')"
  [[ -n "$expected_hash" ]] || fail "Missing checksum entry for $asset"
  [[ "$actual_hash" == "$expected_hash" ]] || fail "Checksum mismatch for $asset"
done

mkdir -p "$BIN_DIR" "$APP_DIR"
LOCAL_RELEASE_DIR="$RELEASE_DIR" "$RELEASE_DIR/install.sh" --bin-dir "$BIN_DIR" --app-dir "$APP_DIR"

[[ -x "$INSTALLED_CLI" ]] || fail "Installed CLI missing."
[[ -d "$INSTALLED_APP" ]] || fail "Installed app missing."
test "$("$INSTALLED_CLI" version)" = "$VERSION" || fail "Installed CLI version mismatch."

installed_app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INSTALLED_APP/Contents/Info.plist")"
test "$installed_app_version" = "$VERSION" || fail "Installed app version mismatch."

echo "Release verification passed for $VERSION"

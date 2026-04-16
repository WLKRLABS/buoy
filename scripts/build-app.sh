#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APP_NAME="${APP_NAME:-Buoy}"
APP_DIR="$OUTPUT_DIR/$APP_NAME.app"
LOCAL_SIGNING_ENV="${LOCAL_SIGNING_ENV:-$HOME/.config/buoy/local-signing.env}"
SWIFTC_BIN="${SWIFTC_BIN:-$(xcrun --find swiftc)}"
SDK_PATH="${SDK_PATH:-$(xcrun --show-sdk-path)}"
ICON_SOURCE="$ROOT_DIR/buoy-icon.png"
ICON_NAME="BuoyIcon"
APP_VERSION="$("$ROOT_DIR/scripts/version.sh" version)"
APP_BUILD="$("$ROOT_DIR/scripts/version.sh" build-number)"
CODESIGN_BIN="${CODESIGN_BIN:-$(xcrun --find codesign)}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
CODESIGN_KEYCHAIN="${CODESIGN_KEYCHAIN:-}"
CODESIGN_KEYCHAIN_PASSWORD="${CODESIGN_KEYCHAIN_PASSWORD:-}"
TMP_DIR="$(mktemp -d)"
GENERATED_VERSION_FILE="$TMP_DIR/BuoyVersion.generated.swift"
STAGING_APP_DIR="$TMP_DIR/$APP_NAME.app"

trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -f "$LOCAL_SIGNING_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_SIGNING_ENV"
fi

"$ROOT_DIR/scripts/build-cli.sh"

rm -rf "$APP_DIR"
rm -rf "$STAGING_APP_DIR"
mkdir -p "$STAGING_APP_DIR/Contents/MacOS" "$STAGING_APP_DIR/Contents/Resources/bin"

cat > "$GENERATED_VERSION_FILE" <<EOF
import Foundation

public let buoyVersion = "$APP_VERSION"
public let buoyBuildNumber = "$APP_BUILD"
EOF

cat > "$STAGING_APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>Buoy</string>
  <key>CFBundleIdentifier</key>
  <string>com.scwlkr.buoy</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>BuoyIcon</string>
  <key>CFBundleName</key>
  <string>Buoy</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD}</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Building Buoy.app..."
"${SWIFTC_BIN}" \
  -sdk "$SDK_PATH" \
  -parse-as-library \
  -framework AppKit \
  "$GENERATED_VERSION_FILE" \
  "$ROOT_DIR"/Sources/BuoyCore/*.swift \
  "$ROOT_DIR"/Sources/BuoyCore/SystemMetrics/*.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/*.swift \
  "$ROOT_DIR"/Sources/BuoyApp/main.swift \
  -o "$STAGING_APP_DIR/Contents/MacOS/Buoy"

cp "$OUTPUT_DIR/buoy" "$STAGING_APP_DIR/Contents/Resources/bin/buoy"
chmod +x "$STAGING_APP_DIR/Contents/MacOS/Buoy" "$STAGING_APP_DIR/Contents/Resources/bin/buoy"

if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$STAGING_APP_DIR/Contents/Resources/buoy-icon.png"

  ICONSET_DIR="$TMP_DIR/${ICON_NAME}.iconset"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"

  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    sips -z "$retina_size" "$retina_size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done

  iconutil -c icns "$ICONSET_DIR" -o "$STAGING_APP_DIR/Contents/Resources/${ICON_NAME}.icns"
  rm -rf "$ICONSET_DIR"
fi

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$STAGING_APP_DIR"
fi

echo "Signing Buoy.app..."
if [[ -n "$CODESIGN_KEYCHAIN" && -n "$CODESIGN_KEYCHAIN_PASSWORD" ]]; then
  security unlock-keychain -p "$CODESIGN_KEYCHAIN_PASSWORD" "$CODESIGN_KEYCHAIN" >/dev/null 2>&1 || true
fi

codesign_args=(
  --force
  --sign "$CODESIGN_IDENTITY"
  --identifier "com.scwlkr.buoy"
)

if [[ -n "$CODESIGN_KEYCHAIN" ]]; then
  codesign_args+=(--keychain "$CODESIGN_KEYCHAIN")
fi

"${CODESIGN_BIN}" "${codesign_args[@]}" "$STAGING_APP_DIR"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$STAGING_APP_DIR"
fi

mkdir -p "$OUTPUT_DIR"
ditto "$STAGING_APP_DIR" "$APP_DIR"

echo "App built at $APP_DIR"

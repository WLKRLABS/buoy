#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
SWIFTC_BIN="${SWIFTC_BIN:-$(xcrun --find swiftc)}"
SDK_PATH="${SDK_PATH:-$(xcrun --show-sdk-path)}"
APP_VERSION="$("$ROOT_DIR/scripts/version.sh" version)"
APP_BUILD="$("$ROOT_DIR/scripts/version.sh" build-number)"
TMP_DIR="$(mktemp -d)"
GENERATED_VERSION_FILE="$TMP_DIR/BuoyVersion.generated.swift"

trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$OUTPUT_DIR"

cat > "$GENERATED_VERSION_FILE" <<EOF
import Foundation

public let buoyVersion = "$APP_VERSION"
public let buoyBuildNumber = "$APP_BUILD"
EOF

echo "Building buoy CLI..."
"${SWIFTC_BIN}" \
  -sdk "$SDK_PATH" \
  "$GENERATED_VERSION_FILE" \
  "$ROOT_DIR"/Sources/BuoyCore/*.swift \
  "$ROOT_DIR"/Sources/buoy/main.swift \
  -o "$OUTPUT_DIR/buoy"

chmod +x "$OUTPUT_DIR/buoy"
echo "CLI built at $OUTPUT_DIR/buoy"

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFTC_BIN="${SWIFTC_BIN:-$(xcrun --find swiftc)}"
SDK_PATH="${SDK_PATH:-$(xcrun --show-sdk-path)}"
TMP_DIR="$(mktemp -d)"
GENERATED_VERSION_FILE="$TMP_DIR/BuoyVersion.generated.swift"

trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$GENERATED_VERSION_FILE" <<EOF
import Foundation

public let buoyVersion = "test"
public let buoyBuildNumber = "test"
EOF

"${SWIFTC_BIN}" \
  -sdk "$SDK_PATH" \
  -framework AppKit \
  "$GENERATED_VERSION_FILE" \
  "$ROOT_DIR"/Sources/BuoyCore/*.swift \
  "$ROOT_DIR"/Sources/BuoyCore/SystemMetrics/*.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/DashboardUIComponents.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageModels.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageAccessManager.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageScanner.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageCacheStore.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageViewController.swift \
  "$ROOT_DIR"/Tests/StorageLayoutTests.swift \
  -o "$TMP_DIR/storage-layout-tests"

"$TMP_DIR/storage-layout-tests"

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFTC_BIN="${SWIFTC_BIN:-$(xcrun --find swiftc)}"
SDK_PATH="${SDK_PATH:-$(xcrun --show-sdk-path)}"
TMP_DIR="$(mktemp -d)"

trap 'rm -rf "$TMP_DIR"' EXIT

"${SWIFTC_BIN}" \
  -sdk "$SDK_PATH" \
  "$ROOT_DIR"/Sources/BuoyCore/Models.swift \
  "$ROOT_DIR"/Sources/BuoyCore/System.swift \
  "$ROOT_DIR"/Sources/BuoyCore/SystemMetrics/MetricsModels.swift \
  "$ROOT_DIR"/Sources/BuoyCore/SystemMetrics/DiskMetrics.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageModels.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageAccessManager.swift \
  "$ROOT_DIR"/Sources/BuoyApp/Dashboard/StorageScanner.swift \
  "$ROOT_DIR"/Tests/StorageScannerTests.swift \
  -o "$TMP_DIR/storage-scanner-tests"

"$TMP_DIR/storage-scanner-tests"

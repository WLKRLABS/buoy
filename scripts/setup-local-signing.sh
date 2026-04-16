#!/usr/bin/env bash

set -euo pipefail

IDENTITY_NAME="${IDENTITY_NAME:-Buoy Local Code Signing}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/buoy}"
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/local-signing.env}"
KEYCHAIN_PATH="${KEYCHAIN_PATH:-$HOME/Library/Keychains/buoy-local-signing.keychain-db}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-}"
P12_PASSWORD="${P12_PASSWORD:-}"
FORCE="${FORCE:-0}"

usage() {
  cat <<EOF
Usage:
  ./scripts/setup-local-signing.sh [--force]

This creates a dedicated local keychain and a self-signed code-signing
identity for Buoy development builds, then writes a small env file that
scripts/build-app.sh will load automatically on this machine.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
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

mkdir -p "$CONFIG_DIR"

if [[ -f "$CONFIG_FILE" && "$FORCE" != "1" ]]; then
  echo "Local signing is already configured at $CONFIG_FILE"
  exit 0
fi

if ! command -v openssl >/dev/null 2>&1; then
  echo "openssl is required to create a local signing identity." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CERT_PEM="$TMP_DIR/buoy-local-signing-cert.pem"
KEY_PEM="$TMP_DIR/buoy-local-signing-key.pem"
P12_FILE="$TMP_DIR/buoy-local-signing.p12"
OPENSSL_CONFIG="$TMP_DIR/buoy-local-signing.cnf"

if [[ -z "$KEYCHAIN_PASSWORD" ]]; then
  KEYCHAIN_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
fi

if [[ -z "$P12_PASSWORD" ]]; then
  P12_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
fi

cat > "$OPENSSL_CONFIG" <<EOF
[ req ]
default_bits = 2048
distinguished_name = dn
x509_extensions = v3
prompt = no

[ dn ]
CN = ${IDENTITY_NAME}
O = Buoy Local

[ v3 ]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,digitalSignature,keyCertSign,cRLSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -x509 \
  -sha256 \
  -days 3650 \
  -config "$OPENSSL_CONFIG" \
  -keyout "$KEY_PEM" \
  -out "$CERT_PEM" >/dev/null 2>&1

openssl pkcs12 \
  -export \
  -inkey "$KEY_PEM" \
  -in "$CERT_PEM" \
  -name "$IDENTITY_NAME" \
  -out "$P12_FILE" \
  -passout "pass:$P12_PASSWORD" >/dev/null 2>&1

if [[ -f "$KEYCHAIN_PATH" ]]; then
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
fi

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

existing_keychains=()
while IFS= read -r keychain_line; do
  cleaned_keychain="$(printf '%s' "$keychain_line" | sed 's/^[[:space:]]*"//; s/"$//')"
  if [[ -n "$cleaned_keychain" && -f "$cleaned_keychain" ]]; then
    existing_keychains+=("$cleaned_keychain")
  fi
done < <(security list-keychains -d user)

security list-keychains -d user -s "$KEYCHAIN_PATH" "${existing_keychains[@]}"

security import "$P12_FILE" \
  -k "$KEYCHAIN_PATH" \
  -f pkcs12 \
  -P "$P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH" >/dev/null

echo "Registering the local root for code signing trust..."
security add-trusted-cert -r trustRoot -p codeSign "$CERT_PEM"

CERT_SHA1="$(
  openssl x509 -in "$CERT_PEM" -noout -fingerprint -sha1 |
    sed 's/^.*=//' |
    tr -d ':'
)"

cat > "$CONFIG_FILE" <<EOF
export CODESIGN_IDENTITY="$CERT_SHA1"
export CODESIGN_KEYCHAIN="$KEYCHAIN_PATH"
export CODESIGN_KEYCHAIN_PASSWORD="$KEYCHAIN_PASSWORD"
EOF

chmod 600 "$CONFIG_FILE"

echo
echo "Created local signing identity:"
echo "  Name: $IDENTITY_NAME"
echo "  SHA-1: $CERT_SHA1"
echo "  Keychain: $KEYCHAIN_PATH"
echo "  Config: $CONFIG_FILE"

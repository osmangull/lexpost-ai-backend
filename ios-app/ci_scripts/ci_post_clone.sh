#!/bin/sh
set -e

echo "Installing Distribution certificate..."

# Decode .p12
echo "$DIST_P12_BASE64" | base64 --decode > /tmp/dist_cert.p12

# Create temporary keychain
KEYCHAIN_PATH=$RUNNER_TEMP/ci_build.keychain
KEYCHAIN_PASSWORD="ci_temp_keychain_pass"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

# Import certificate into keychain
security import /tmp/dist_cert.p12 \
  -k "$KEYCHAIN_PATH" \
  -P "$DIST_P12_PASSWORD" \
  -T /usr/bin/codesign \
  -T /usr/bin/security

# Add to keychain search list
security list-keychain -d user -s "$KEYCHAIN_PATH" login.keychain

# Allow codesign to access keychain without prompts
security set-key-partition-list \
  -S apple-tool:,apple:,codesign: \
  -s \
  -k "$KEYCHAIN_PASSWORD" \
  "$KEYCHAIN_PATH"

rm /tmp/dist_cert.p12

echo "Distribution certificate installed successfully."

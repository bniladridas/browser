#!/bin/bash
set -e

cleanup() {
  rm -f actionlint actionlint.tar.gz
}
trap cleanup EXIT

echo "Running Flutter analyze..."
flutter analyze

echo "Running Flutter tests..."
flutter test

echo "Building for macOS..."
flutter build macos

echo "Checking GitHub Actions workflows..."
# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  ARCH="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  ARCH="arm64"
else
  echo "Error: Unsupported architecture '$ARCH' for actionlint download." >&2
  exit 1
fi
curl -L -o actionlint.tar.gz "https://github.com/rhysd/actionlint/releases/download/v1.7.1/actionlint_1.7.1_${OS}_${ARCH}.tar.gz"
tar -xzf actionlint.tar.gz
./actionlint .github/workflows/*.yml

echo "All checks passed!"

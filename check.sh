#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.
set -euo pipefail

echo "Generating code..."
flutter pub run build_runner build

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
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64 | arm64) ARCH="arm64" ;;
  *)
    echo "Error: Unsupported architecture '$ARCH' for actionlint download." >&2
    exit 1
    ;;
esac
PROJECT_DIR=$(pwd)
DOWNLOAD_URL="https://github.com/rhysd/actionlint/releases/download/v1.7.1/actionlint_1.7.1_${OS}_${ARCH}.tar.gz"
TMP_DIR=$(mktemp -d)
(
  cd "$TMP_DIR"
  curl -fsSL -o actionlint.tar.gz "$DOWNLOAD_URL"
  tar -xzf actionlint.tar.gz
  ./actionlint "$PROJECT_DIR/.github/workflows"/*.yml
)
EXIT_CODE=$?
rm -rf "$TMP_DIR"
if [ "$EXIT_CODE" -ne 0 ]; then
  exit "$EXIT_CODE"
fi

echo "All checks passed!"

#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.
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
PROJECT_DIR=$(pwd)
TMP_DIR=$(mktemp -d)
(
  cd "$TMP_DIR"
  curl -fsSL -o actionlint.tar.gz "https://github.com/rhysd/actionlint/releases/download/v1.7.1/actionlint_1.7.1_${OS}_${ARCH}.tar.gz"
  tar -xzf actionlint.tar.gz
  ./actionlint "$PROJECT_DIR/.github/workflows"/*.yml
)
EXIT_CODE=$?
rm -rf "$TMP_DIR"
if [ $EXIT_CODE -ne 0 ]; then
  exit $EXIT_CODE
fi

echo "All checks passed!"

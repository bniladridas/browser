#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Development setup script

echo "Setting up development environment..."

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Please install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "Flutter version: $(flutter --version)"

# Install dependencies
flutter pub get

# Run tests
flutter test

echo "Setup complete! Run './scripts/e2e.sh' for e2e tests."
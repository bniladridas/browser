#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Script to update pubspec.yaml version from VERSION file

set -euo pipefail

if [ ! -f VERSION ]; then
  echo "VERSION file not found"
  exit 1
fi

VERSION=$(cat VERSION)

# macOS (BSD sed) requires `-i ''`, while GNU sed (Linux) supports `-i`.
if sed --version >/dev/null 2>&1; then
  sed -i "s/^version: .*/version: $VERSION/" pubspec.yaml
else
  sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
fi

echo "Updated pubspec.yaml version to $VERSION"

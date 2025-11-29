#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Script to bump version in VERSION file
# Usage: ./bump_version.sh <major|minor|patch>

if [ $# -ne 1 ]; then
  echo "Usage: $0 <major|minor|patch>"
  exit 1
fi

BUMP_TYPE=$1

# Get latest tag
LATEST_TAG=$(git describe --tags --abbrev=0 --match "desktop/app-*" 2>/dev/null || echo "desktop/app-1.0.0")
CURRENT_VERSION=$(echo "$LATEST_TAG" | sed 's/desktop\/app-//')
BUILD=$(cat VERSION 2>/dev/null | sed 's/.*+//' || echo "1")

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case $BUMP_TYPE in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
  *)
    echo "Invalid bump type: $BUMP_TYPE"
    exit 1
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH+$BUILD"
echo "$NEW_VERSION" > VERSION

echo "Bumped version to $NEW_VERSION"

# Update pubspec.yaml
./update_version.sh

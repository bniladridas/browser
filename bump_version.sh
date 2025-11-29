#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Script to bump version in VERSION file based on latest git tag
# Usage: ./bump_version.sh <major|minor|patch>
# The script reads the latest tag matching "desktop/app-*", bumps the version,
# and derives the build number from commits since the last tag.

set -e  # Exit on error

if [ $# -ne 1 ]; then
  echo "Usage: $0 <major|minor|patch>"
  exit 1
fi

BUMP_TYPE=$1

# Configurable tag prefix
TAG_PREFIX="desktop/app"

# Ensure tags are fetched
git fetch --unshallow --all --tags --quiet || true

# Get latest tag, default to 1.0.0 if none
if ! LATEST_TAG=$(git describe --tags --abbrev=0 --match "${TAG_PREFIX}-*" 2>/dev/null); then
  echo "No tags found, starting from 1.0.0"
  LATEST_TAG="${TAG_PREFIX}-1.0.0"
fi

# Extract version from tag
CURRENT_VERSION=$(echo "$LATEST_TAG" | sed 's/desktop\/app-//' | sed 's/+.*//')

# Derive build number from commits since last tag
if git describe --tags --exact-match HEAD >/dev/null 2>&1; then
  BUILD=1  # On a tag, start build at 1
else
  BUILD=$(git rev-list --count HEAD ^"$LATEST_TAG" 2>/dev/null || echo "1")
  BUILD=$((BUILD + 1))  # Increment for next build
fi

# Fallback to VERSION file if needed, with robust parsing
if [ "$BUILD" = "1" ] && [ -f VERSION ]; then
  BUILD=$(grep '+' VERSION | sed 's|.*+||' || echo "1")
fi

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

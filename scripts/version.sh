#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Script to bump version in VERSION file based on latest git tag
# Usage: ./bump_version.sh <major|minor|patch>
# The script reads the latest tag matching "desktop/app-*", bumps the version,
# derives the build number from commits since the last tag, and ensures
# assets/whats_new.json has an entry for the new release version.

set -e  # Exit on error

if [ $# -ne 1 ]; then
  echo "Usage: $0 <major|minor|patch>"
  exit 1
fi

BUMP_TYPE=$1

# Configurable tag prefix
TAG_PREFIX=${TAG_PREFIX:-desktop/app}

# Ensure tags are fetched
git fetch origin --tags --quiet || echo "Warning: git fetch failed. Tags may be outdated." >&2

# Get latest tag, default to 1.0.0 if none
if ! LATEST_TAG=$(git describe --tags --abbrev=0 --match "${TAG_PREFIX}*" 2>/dev/null); then
  echo "No tags found, starting from 1.0.0"
  LATEST_TAG="${TAG_PREFIX}-1.0.0"
fi

# Extract version from tag
CURRENT_VERSION=$(echo "$LATEST_TAG" | sed -e "s,^${TAG_PREFIX},," -e 's/^-//' -e 's/\+.*//')
if [ -z "$CURRENT_VERSION" ]; then
  CURRENT_VERSION="1.0.0"
fi

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
./scripts/pubspec.sh

# Ensure "What's New" notes contain an entry for this release version.
RELEASE_VERSION="${NEW_VERSION%%+*}"
WHATS_NEW_FILE="assets/whats_new.json"
WHATS_NEW_TEMPLATE_FILE="assets/whats_new_template.txt"
WHATS_NEW_TMP_FILE="${WHATS_NEW_FILE}.tmp"

if [ ! -f "$WHATS_NEW_TEMPLATE_FILE" ]; then
  echo "Missing template file: $WHATS_NEW_TEMPLATE_FILE"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Missing required dependency: jq"
  echo "Install jq to enable automatic updates for $WHATS_NEW_FILE"
  exit 1
fi

build_whats_new_notes_json() {
  jq -Rsc 'split("\n") | map(gsub("^[[:space:]]+|[[:space:]]+$";"")) | map(select(length > 0))' \
    "$WHATS_NEW_TEMPLATE_FILE"
}

NOTES_JSON=$(build_whats_new_notes_json)
if [ "$NOTES_JSON" = "[]" ]; then
  echo "Template file has no usable lines: $WHATS_NEW_TEMPLATE_FILE"
  exit 1
fi

if [ ! -f "$WHATS_NEW_FILE" ] || [ ! -s "$WHATS_NEW_FILE" ]; then
  echo "{}" > "$WHATS_NEW_FILE"
fi

if jq -e --arg version "$RELEASE_VERSION" 'has($version)' "$WHATS_NEW_FILE" >/dev/null; then
  echo "What's New entry already exists for $RELEASE_VERSION"
else
  jq --arg version "$RELEASE_VERSION" --argjson notes "$NOTES_JSON" \
    '. + {($version): $notes}' "$WHATS_NEW_FILE" > "$WHATS_NEW_TMP_FILE"
  mv "$WHATS_NEW_TMP_FILE" "$WHATS_NEW_FILE"
  echo "Added What's New placeholder entry for $RELEASE_VERSION using jq"
fi

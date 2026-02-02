#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Test script for bump_version.sh
# Run with: ./test_bump_version.sh

set -e

echo "Testing bump_version.sh..."

# Backup original files
cp VERSION VERSION.backup
cp pubspec.yaml pubspec.yaml.backup

cleanup() {
  mv VERSION.backup VERSION
  mv pubspec.yaml.backup pubspec.yaml
}
trap cleanup EXIT

# Test patch bump
echo "1.0.0+1" > VERSION
./scripts/version.sh patch > /dev/null
RESULT=$(cat VERSION)
EXPECTED="1.0.1+2"
if [ "$RESULT" = "$EXPECTED" ]; then
  echo "✓ Patch bump test passed"
else
  echo "✗ Patch bump test failed: expected $EXPECTED, got $RESULT"
  exit 1
fi

# Test minor bump
echo "1.0.0+1" > VERSION
./scripts/version.sh minor > /dev/null
RESULT=$(cat VERSION)
EXPECTED="1.1.0+2"
if [ "$RESULT" = "$EXPECTED" ]; then
  echo "✓ Minor bump test passed"
else
  echo "✗ Minor bump test failed: expected $EXPECTED, got $RESULT"
  exit 1
fi

# Test major bump
echo "1.0.0+1" > VERSION
./scripts/version.sh major > /dev/null
RESULT=$(cat VERSION)
EXPECTED="2.0.0+2"
if [ "$RESULT" = "$EXPECTED" ]; then
  echo "✓ Major bump test passed"
else
  echo "✗ Major bump test failed: expected $EXPECTED, got $RESULT"
  exit 1
fi

echo "All bump_version.sh tests passed!"

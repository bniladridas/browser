#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

set -euo pipefail

PR_TITLE=$(gh pr view "$PR_NUMBER" --json title -q '.title')
printf "PR Title: %s\n" "${PR_TITLE}"

if printf "%s" "${PR_TITLE}" | grep -q -E \
  "^(chore: bump version to|chore\[version\] :: bump version to)"; then
  printf "Skipping bump for version bump PR\n"
  printf "bump-type=skip\n" >> "$GITHUB_OUTPUT"
  exit 0
fi

LABELS=$(gh pr view "$PR_NUMBER" --json labels -q '.labels[].name')
printf "Labels: %s\n" "${LABELS}"

BUMP_COUNT=$(printf "%s" "${LABELS}" | grep -c -E "^(major|minor|patch)$")
if [ "$BUMP_COUNT" -gt 1 ]; then
  printf "Warning: Multiple bump labels found. Using precedence: major > minor > patch.\n"
fi

if printf "%s" "${LABELS}" | grep -q -x "major"; then
  BUMP_TYPE="major"
elif printf "%s" "${LABELS}" | grep -q -x "minor"; then
  BUMP_TYPE="minor"
elif printf "%s" "${LABELS}" | grep -q -x "patch"; then
  BUMP_TYPE="patch"
else
  BUMP_TYPE="patch"
fi

printf "bump-type=%s\n" "${BUMP_TYPE}" >> "$GITHUB_OUTPUT"

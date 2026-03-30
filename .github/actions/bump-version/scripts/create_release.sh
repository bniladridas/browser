#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

set -euo pipefail

VERSION=${VERSION:?}
TAG_PREFIX=${TAG_PREFIX:?}
PR_NUMBER=${PR_NUMBER:?}

TAG="${TAG_PREFIX}-${VERSION}"

if gh release view "${TAG}" &>/dev/null; then
  echo "Release for tag ${TAG} already exists. Skipping release creation."
else
  PR_TITLE=$(gh pr view "$PR_NUMBER" --json title -q '.title')
  PR_BODY=$(gh pr view "$PR_NUMBER" --json body -q '.body')

  extract_section() {
    local heading="$1"
    echo "$PR_BODY" | awk -v heading="$heading" '
      function normalize(line) {
        sub(/^[ \t\r\n]+/, "", line)
        sub(/[ \t\r\n]+$/, "", line)
        gsub(/[ \t]+/, " ", line)
        return line
      }
      BEGIN { h = "## " heading }
      normalize($0) == h { p=1; next }
      /^##[ \t]/ { if(p){ exit } }
      p { print }
    '
  }

  SUMMARY_SECTION="$(extract_section "Summary" | sed '/^[[:space:]]*$/d')"
  SUMMARY_SECTION="${SUMMARY_SECTION:-- ${PR_TITLE}}"

  WHATS_NEW_SECTION="$(extract_section "What's New" | sed '/^[[:space:]]*$/d')"
  WHATS_NEW_CONTENT="${WHATS_NEW_SECTION:-${SUMMARY_SECTION}}"

  BUG_FIX_SECTION="$(extract_section "Bug Fixes" | sed '/^[[:space:]]*$/d')"
  if [[ -z "$BUG_FIX_SECTION" ]]; then
    BUG_FIX_CONTENT="$SUMMARY_SECTION"
  elif [[ "$BUG_FIX_SECTION" == "(none)" || "$BUG_FIX_SECTION" == "- (none)" ]]; then
    BUG_FIX_CONTENT="- (none)"
  else
    BUG_FIX_CONTENT="$BUG_FIX_SECTION"
  fi

  NOTES=$(cat <<EOF
## What's New
${WHATS_NEW_CONTENT}

## Bug Fixes
${BUG_FIX_CONTENT}

## Technical Changes
- Updated version to ${VERSION}

## macOS Install Notes
- Unsigned builds may show Gatekeeper warnings. Users can right-click the app and choose Open, or use
  System Settings → Privacy & Security → Open Anyway.

(auto bump)
EOF
)

  gh release create "${TAG}" --title "Release ${VERSION}" --notes "${NOTES}"
fi

if ! gh api -X POST \
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release.yml/dispatches" \
  -f ref="main" \
  -f inputs[tag]="${TAG}" \
  >/dev/null; then
  echo "Warning: failed to dispatch release workflow for ${TAG}"
fi

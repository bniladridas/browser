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

BRANCH_NAME="version-bump-${VERSION}"

EXISTING_PR=$(gh pr list --head "$BRANCH_NAME" --base main --json number --jq 'length')
if [ "$EXISTING_PR" -gt 0 ]; then
  echo "Version bump PR for $VERSION already exists. Skipping."
  exit 0
fi

git config --local user.email "41898282+github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"
git checkout -B "$BRANCH_NAME"

MERGED_PR_TITLE="$(gh pr view "$PR_NUMBER" --json title -q '.title')"

normalize_whats_new_note() {
  local title="$1"
  title="$(printf '%s' "$title" | sed -E 's/[[:space:]]+\(#[0-9]+\)$//')"
  title="$(printf '%s' "$title" | sed -E 's/^[a-z]+([[][^]]+[]])?[[:space:]]*::[[:space:]]*//')"
  title="$(printf '%s' "$title" | sed -E 's/^[a-z]+:[[:space:]]*//')"
  title="$(printf '%s' "$title" | sed -E 's/[`*_]//g; s/[[:space:]]+/ /g; s/^ +| +$//g')"

  if [ -z "$title" ]; then
    title="Maintenance updates"
  fi

  if [[ ! "$title" =~ [.!?]$ ]]; then
    title="${title}."
  fi

  printf '%s' "$title"
}

WHATS_NEW_FILE="assets/whats_new.json"
if [ ! -f "$WHATS_NEW_FILE" ] || [ ! -s "$WHATS_NEW_FILE" ]; then
  echo "{}" > "$WHATS_NEW_FILE"
fi

WHATS_NEW_NOTE="$(normalize_whats_new_note "${MERGED_PR_TITLE:-}")"
jq --arg version "$VERSION" --arg note "$WHATS_NEW_NOTE" \
  '.[$version] = [$note]' \
  "$WHATS_NEW_FILE" > /tmp/whats_new.json \
  && mv /tmp/whats_new.json "$WHATS_NEW_FILE"

git add VERSION pubspec.yaml assets/whats_new.json
git commit -m "chore: bump version to ${VERSION}"
git push --force-with-lease origin "$BRANCH_NAME"

MERGED_PR_ITEM="- #${PR_NUMBER} - ${MERGED_PR_TITLE}"

WHATS_NEW_CONTENT="- (none)"
BUG_FIX_CONTENT="- (none)"
DOC_CONTENT="- (none)"
MAINT_CONTENT="- (none)"

if [[ "${MERGED_PR_TITLE}" =~ ^feat(\[|:|[[:space:]]) ]]; then
  WHATS_NEW_CONTENT="${MERGED_PR_ITEM}"
elif [[ "${MERGED_PR_TITLE}" =~ ^fix(\[|:|[[:space:]]) ]]; then
  BUG_FIX_CONTENT="${MERGED_PR_ITEM}"
elif [[ "${MERGED_PR_TITLE}" =~ ^docs(\[|:|[[:space:]]) ]]; then
  DOC_CONTENT="${MERGED_PR_ITEM}"
else
  MAINT_CONTENT="${MERGED_PR_ITEM}"
fi

PR_BODY_FILE="$(mktemp)"
cat > "${PR_BODY_FILE}" <<EOF
## Summary
- Automated version bump to ${VERSION} after merging PR #${PR_NUMBER}.

## What's New
${WHATS_NEW_CONTENT}

## Bug Fixes
${BUG_FIX_CONTENT}

## Documentation
${DOC_CONTENT}

## Maintenance
${MAINT_CONTENT}
EOF

gh pr create \
  --title "chore[version] :: bump version to ${VERSION}" \
  --body-file "${PR_BODY_FILE}" \
  --base main \
  --head "$BRANCH_NAME"

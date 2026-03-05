#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2026 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Script to bump version in VERSION file based on latest git tag
# Usage: ./bump_version.sh <major|minor|patch> [--force-whats-new]
# The script reads the latest tag matching "desktop/app-*", bumps the version,
# derives the build number from commits since the last tag, and ensures
# assets/whats_new.json has an entry for the new release version.

set -e  # Exit on error

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <major|minor|patch> [--force-whats-new]"
  exit 1
fi

BUMP_TYPE=$1
FORCE_WHATS_NEW=false
if [ $# -eq 2 ]; then
  if [ "$2" = "--force-whats-new" ]; then
    FORCE_WHATS_NEW=true
  else
    echo "Invalid option: $2"
    echo "Usage: $0 <major|minor|patch> [--force-whats-new]"
    exit 1
  fi
fi

# Configurable tag prefix
TAG_PREFIX=${TAG_PREFIX:-desktop/app}
MAX_WHATS_NEW_NOTES=${MAX_WHATS_NEW_NOTES:-2}

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

if ! command -v jq >/dev/null 2>&1; then
  echo "Missing required dependency: jq"
  echo "Install jq to enable automatic updates for $WHATS_NEW_FILE"
  exit 1
fi

ensure_trailing_period() {
  local text="$1"
  if [[ "$text" =~ [.!?]$ ]]; then
    printf '%s' "$text"
  else
    printf '%s.' "$text"
  fi
}

to_minimal_note() {
  local text="$1"
  text="$(echo "$text" | sed -E 's/[`*_]//g; s/[[:space:]]+/ /g; s/^ +| +$//g')"
  # Keep primary clause only.
  text="$(echo "$text" | sed -E 's/(,|;| and | but ).*$//')"
  # Trim long purpose clauses.
  text="$(echo "$text" | sed -E 's/[[:space:]]+to[[:space:]].*$//')"
  # Drop leading imperative verbs to keep release notes terse.
  text="$(echo "$text" | sed -E 's/^(Add|Improve|Fix|Harden|Run|Make|Update|Refactor|Combine|Stabilize|Suppress)[[:space:]]+//')"
  text="$(echo "$text" | sed -E 's/^ +| +$//g')"
  # Keep notes compact.
  text="$(echo "$text" | awk '{for (i=1; i<=NF && i<=10; i++) printf "%s%s", $i, (i<10 && i<NF ? " " : ""); if (NF>10) printf ""}')"
  [ -z "$text" ] && return 1
  text="$(tr '[:upper:]' '[:lower:]' <<< "${text:0:1}")${text:1}"
  text="$(tr '[:lower:]' '[:upper:]' <<< "${text:0:1}")${text:1}"
  ensure_trailing_period "$text"
}

build_whats_new_notes_from_git_json() {
  local subjects note type desc
  local -a notes=()
  subjects="$(git log --pretty=%s "${LATEST_TAG}..HEAD" 2>/dev/null || true)"
  while IFS= read -r subject; do
    [ -z "$subject" ] && continue
    # Drop PR number suffix and skip noise.
    subject="$(echo "$subject" | sed -E 's/[[:space:]]+\(#[0-9]+\)$//')"
    [[ "$subject" =~ ^Merge[[:space:]] ]] && continue
    [[ "$subject" =~ ^chore(\[[^]]+\])?[[:space:]]*::[[:space:]]*bump[[:space:]]+version ]] && continue
    [[ "$subject" =~ ^chore:[[:space:]]*bump[[:space:]]+version ]] && continue

    type=""
    desc="$subject"
    if [[ "$subject" =~ ^([a-z]+)(\[[^]]+\])?[[:space:]]*::[[:space:]]*(.+)$ ]]; then
      type="${BASH_REMATCH[1]}"
      desc="${BASH_REMATCH[3]}"
    elif [[ "$subject" =~ ^([a-z]+):[[:space:]]*(.+)$ ]]; then
      type="${BASH_REMATCH[1]}"
      desc="${BASH_REMATCH[2]}"
    fi

    case "$type" in
      feat) note="New: $(ensure_trailing_period "$desc")" ;;
      fix) note="Fix: $(ensure_trailing_period "$desc")" ;;
      perf) note="Performance: $(ensure_trailing_period "$desc")" ;;
      security) note="Security: $(ensure_trailing_period "$desc")" ;;
      *) note="Update: $(ensure_trailing_period "$desc")" ;;
    esac

    note="$(to_minimal_note "$note" || true)"
    [ -z "$note" ] && continue

    # Keep first N unique notes for concise release cards.
    if [[ ! " ${notes[*]} " =~ " ${note} " ]]; then
      notes+=("$note")
    fi
    [ "${#notes[@]}" -ge "$MAX_WHATS_NEW_NOTES" ] && break
  done <<< "$subjects"

  if [ "${#notes[@]}" -eq 0 ]; then
    return 1
  fi
  printf '%s\n' "${notes[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))'
}

build_whats_new_notes_from_pr_json() {
  local last_tag_date prs_json pr body title summary_lines note
  local -a notes=()

  if ! command -v gh >/dev/null 2>&1; then
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    return 1
  fi

  last_tag_date="$(git log -1 --format=%cI "$LATEST_TAG" 2>/dev/null || true)"
  if [ -z "$last_tag_date" ]; then
    return 1
  fi

  prs_json="$(gh pr list \
    --state merged \
    --base main \
    --search "merged:>${last_tag_date}" \
    --limit 30 \
    --json number,title,body,mergedAt 2>/dev/null || true)"
  if [ -z "$prs_json" ] || [ "$prs_json" = "[]" ]; then
    return 1
  fi

  while IFS= read -r pr; do
    body="$(echo "$pr" | jq -r '.body // ""')"
    title="$(echo "$pr" | jq -r '.title // ""')"
    summary_lines="$(printf '%s\n' "$body" | awk '
      BEGIN { in_summary=0 }
      /^##[[:space:]]+Summary/ { in_summary=1; next }
      in_summary && /^##[[:space:]]+/ { exit }
      in_summary && /^-[[:space:]]+/ { print }
    ')"

    if [ -n "$summary_lines" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        note="${line#- }"
        note="$(to_minimal_note "$note" || true)"
        [ -z "$note" ] && continue
        if [[ ! " ${notes[*]} " =~ " ${note} " ]]; then
          notes+=("$note")
        fi
        [ "${#notes[@]}" -ge "$MAX_WHATS_NEW_NOTES" ] && break 2
      done <<< "$summary_lines"
    fi

    if [ -n "$title" ] && [ "${#notes[@]}" -lt "$MAX_WHATS_NEW_NOTES" ]; then
      note="$(echo "$title" | sed -E 's/[[:space:]]+\(#[0-9]+\)$//')"
      note="$(to_minimal_note "$note" || true)"
      [ -z "$note" ] && continue
      if [[ ! " ${notes[*]} " =~ " ${note} " ]]; then
        notes+=("$note")
      fi
      [ "${#notes[@]}" -ge "$MAX_WHATS_NEW_NOTES" ] && break
    fi
  done < <(echo "$prs_json" | jq -c 'sort_by(.mergedAt) | reverse[]')

  if [ "${#notes[@]}" -eq 0 ]; then
    return 1
  fi
  printf '%s\n' "${notes[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))'
}

build_whats_new_notes_json() {
  jq -Rsc 'split("\n") | map(gsub("^[[:space:]]+|[[:space:]]+$";"")) | map(select(length > 0))' \
    "$WHATS_NEW_TEMPLATE_FILE"
}

if NOTES_JSON=$(build_whats_new_notes_from_pr_json); then
  echo "Generated What's New notes from merged PR descriptions since ${LATEST_TAG}."
elif NOTES_JSON=$(build_whats_new_notes_from_git_json); then
  echo "Generated What's New notes from commits since ${LATEST_TAG}."
else
  if [ ! -f "$WHATS_NEW_TEMPLATE_FILE" ]; then
    echo "Missing template file: $WHATS_NEW_TEMPLATE_FILE"
    exit 1
  fi
  NOTES_JSON=$(build_whats_new_notes_json)
  if [ "$NOTES_JSON" = "[]" ]; then
    echo "Template file has no usable lines: $WHATS_NEW_TEMPLATE_FILE"
    exit 1
  fi
  echo "Falling back to template notes for $RELEASE_VERSION."
fi

if [ ! -f "$WHATS_NEW_FILE" ] || [ ! -s "$WHATS_NEW_FILE" ]; then
  echo "{}" > "$WHATS_NEW_FILE"
fi

if jq -e --arg version "$RELEASE_VERSION" 'has($version)' "$WHATS_NEW_FILE" >/dev/null; then
  if [ "$FORCE_WHATS_NEW" = "true" ]; then
    jq --arg version "$RELEASE_VERSION" --argjson notes "$NOTES_JSON" \
      '.[$version] = $notes' "$WHATS_NEW_FILE" > "$WHATS_NEW_TMP_FILE"
    mv "$WHATS_NEW_TMP_FILE" "$WHATS_NEW_FILE"
    echo "Overwrote What's New entry for $RELEASE_VERSION (--force-whats-new)."
  else
    echo "What's New entry already exists for $RELEASE_VERSION"
  fi
else
  jq --arg version "$RELEASE_VERSION" --argjson notes "$NOTES_JSON" \
    '. + {($version): $notes}' "$WHATS_NEW_FILE" > "$WHATS_NEW_TMP_FILE"
  mv "$WHATS_NEW_TMP_FILE" "$WHATS_NEW_FILE"
  echo "Added What's New entry for $RELEASE_VERSION using jq"
fi

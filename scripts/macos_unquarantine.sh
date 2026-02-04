#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-/Applications/browser.app}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

echo "Removing quarantine attribute from ${APP_PATH}..."
xattr -rd com.apple.quarantine "${APP_PATH}"
echo "Done. You can now open the app."

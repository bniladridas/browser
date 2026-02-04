#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${APP_PATH:-build/macos/Build/Products/Release/browser.app}"
DMG_PATH="${DMG_PATH:-build/macos/Build/Products/Release/browser.dmg}"
VOLUME_NAME="${VOLUME_NAME:-Browser}"
TMP_ROOT="${TMP_ROOT:-}"
ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-}"

unsigned_release=false
if [[ -z "${MACOS_CODE_SIGN_IDENTITY:-}" ]]; then
  if [[ "${ALLOW_UNSIGNED}" == "1" ]]; then
    unsigned_release=true
    echo "Warning: MACOS_CODE_SIGN_IDENTITY not set. Proceeding with unsigned DMG." >&2
  else
    echo "Missing MACOS_CODE_SIGN_IDENTITY (Developer ID Application identity)." >&2
    echo "Set ALLOW_UNSIGNED=1 to create an unsigned DMG for testing." >&2
    exit 1
  fi
fi

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  if [[ "${ALLOW_UNSIGNED}" == "1" ]]; then
    unsigned_release=true
    echo "Warning: notarization credentials not set. Skipping notarization." >&2
  else
    echo "Missing APPLE_ID, APPLE_TEAM_ID, or APPLE_APP_SPECIFIC_PASSWORD." >&2
    echo "Set ALLOW_UNSIGNED=1 to create an unsigned DMG for testing." >&2
    exit 1
  fi
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

if [[ "${unsigned_release}" == "false" ]]; then
  echo "Signing app frameworks and bundles..."
  while IFS= read -r -d '' item; do
    codesign --force --options runtime --timestamp --sign "${MACOS_CODE_SIGN_IDENTITY}" "${item}"
  done < <(find "${APP_PATH}/Contents" \
    \( -name "*.framework" -o -name "*.dylib" -o -name "*.plugin" -o -name "*.bundle" -o -name "*.app" \) \
    -print0)

  echo "Signing main app..."
  codesign --force --options runtime --timestamp --sign "${MACOS_CODE_SIGN_IDENTITY}" "${APP_PATH}"
  codesign --verify --strict --deep --verbose=2 "${APP_PATH}"
else
  echo "Skipping code signing for unsigned release."
fi

echo "Creating DMG..."
if [[ -n "${TMP_ROOT}" ]]; then
  dmg_root="${TMP_ROOT}"
  if [[ -z "${dmg_root}" || "${dmg_root}" == "/" ]]; then
    echo "Aborting: unsafe TMP_ROOT specified: '${dmg_root}'" >&2
    exit 1
  fi
  rm -rf "${dmg_root}"
  mkdir -p "${dmg_root}"
else
  dmg_root="$(mktemp -d)"
fi

cp -R "${APP_PATH}" "${dmg_root}/"
ln -s /Applications "${dmg_root}/Applications"

hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${dmg_root}" -ov -format UDZO "${DMG_PATH}"

if [[ "${unsigned_release}" == "false" ]]; then
  echo "Signing DMG..."
  codesign --force --timestamp --sign "${MACOS_CODE_SIGN_IDENTITY}" "${DMG_PATH}"
else
  echo "Skipping DMG signing for unsigned release."
fi

if [[ "${unsigned_release}" == "false" ]]; then
  echo "Notarizing DMG..."
  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --wait

  echo "Stapling notarization..."
  xcrun stapler staple "${DMG_PATH}"
else
  echo "Skipping notarization for unsigned release."
fi

echo "Release DMG ready: ${DMG_PATH}"

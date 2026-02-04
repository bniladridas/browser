#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${APP_PATH:-build/macos/Build/Products/Release/browser.app}"
DMG_PATH="${DMG_PATH:-build/macos/Build/Products/Release/browser.dmg}"
VOLUME_NAME="${VOLUME_NAME:-Browser}"
TMP_ROOT="${TMP_ROOT:-}"

if [[ -z "${MACOS_CODE_SIGN_IDENTITY:-}" ]]; then
  echo "Missing MACOS_CODE_SIGN_IDENTITY (Developer ID Application identity)." >&2
  exit 1
fi

if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "Missing APPLE_ID, APPLE_TEAM_ID, or APPLE_APP_SPECIFIC_PASSWORD." >&2
  exit 1
fi

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

echo "Signing app frameworks and bundles..."
while IFS= read -r -d '' item; do
  codesign --force --options runtime --timestamp --sign "${MACOS_CODE_SIGN_IDENTITY}" "${item}"
done < <(find "${APP_PATH}/Contents" \
  \( -name "*.framework" -o -name "*.dylib" -o -name "*.plugin" -o -name "*.bundle" -o -name "*.app" \) \
  -print0)

echo "Signing main app..."
codesign --force --options runtime --timestamp --sign "${MACOS_CODE_SIGN_IDENTITY}" "${APP_PATH}"
codesign --verify --strict --deep --verbose=2 "${APP_PATH}"

echo "Creating DMG..."
if [[ -n "${TMP_ROOT}" ]]; then
  dmg_root="${TMP_ROOT}"
  rm -rf "${dmg_root}"
  mkdir -p "${dmg_root}"
else
  dmg_root="$(mktemp -d)"
fi

cp -R "${APP_PATH}" "${dmg_root}/"
ln -s /Applications "${dmg_root}/Applications"

hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${dmg_root}" -ov -format UDZO "${DMG_PATH}"

echo "Signing DMG..."
codesign --force --timestamp --sign "${MACOS_CODE_SIGN_IDENTITY}" "${DMG_PATH}"

echo "Notarizing DMG..."
xcrun notarytool submit "${DMG_PATH}" \
  --apple-id "${APPLE_ID}" \
  --team-id "${APPLE_TEAM_ID}" \
  --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
  --wait

echo "Stapling notarization..."
xcrun stapler staple "${DMG_PATH}"

echo "Release DMG ready: ${DMG_PATH}"

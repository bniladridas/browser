#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${APP_PATH:-build/macos/Build/Products/Release/browser.app}"
DMG_PATH="${DMG_PATH:-build/macos/Build/Products/Release/browser.dmg}"
VOLUME_NAME="${VOLUME_NAME:-Browser}"
TMP_ROOT="${TMP_ROOT:-}"
ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-}"
DMG_WINDOW_BOUNDS="${DMG_WINDOW_BOUNDS:-100,100,640,420}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-128}"
DMG_BACKGROUND_IMAGE="${DMG_BACKGROUND_IMAGE:-assets/dmg/background.png}"
DMG_HEADROOM_MB="${DMG_HEADROOM_MB:-50}"

unsigned_release=false

if [[ "${ALLOW_UNSIGNED}" == "1" ]]; then
  if [[ -z "${MACOS_CODE_SIGN_IDENTITY:-}" ]]; then
    unsigned_release=true
    echo "Warning: MACOS_CODE_SIGN_IDENTITY not set. Proceeding with unsigned DMG." >&2
  fi

  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    unsigned_release=true
    echo "Warning: notarization credentials not set. Skipping notarization." >&2
  fi
else
  if [[ -z "${MACOS_CODE_SIGN_IDENTITY:-}" ]]; then
    echo "Missing MACOS_CODE_SIGN_IDENTITY (Developer ID Application identity)." >&2
    echo "Set ALLOW_UNSIGNED=1 to create an unsigned DMG for testing." >&2
    exit 1
  fi

  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
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
app_name="$(basename "${APP_PATH}")"
app_name="${app_name%.app}"
rw_dmg_path="${DMG_PATH%.dmg}-rw.dmg"

if [[ -n "${DMG_BACKGROUND_IMAGE}" && -f "${DMG_BACKGROUND_IMAGE}" ]]; then
  mkdir -p "${dmg_root}/.background"
  cp "${DMG_BACKGROUND_IMAGE}" "${dmg_root}/.background/background.png"
fi

# Include extra headroom for metadata, icon layout and optional background.
size_mb="$(du -sm "${dmg_root}" | awk '{print $1}')"
if [[ ! "${DMG_HEADROOM_MB}" =~ ^[0-9]+$ ]]; then
  echo "Invalid DMG_HEADROOM_MB: ${DMG_HEADROOM_MB} (expected integer)." >&2
  exit 1
fi
size_mb="$((size_mb + DMG_HEADROOM_MB))"

hdiutil create \
  -volname "${VOLUME_NAME}" \
  -srcfolder "${dmg_root}" \
  -ov \
  -fs HFS+ \
  -format UDRW \
  -size "${size_mb}m" \
  "${rw_dmg_path}"

attach_out="$(hdiutil attach -readwrite -noverify -noautoopen "${rw_dmg_path}")"
hfs_line="$(echo "${attach_out}" | grep 'Apple_HFS' | head -n1)"
device="$(echo "${hfs_line}" | awk '{print $1}')"
mount_point="$(echo "${hfs_line}" | grep -o '/Volumes/.*')"

if [[ -z "${device}" || -z "${mount_point}" ]]; then
  echo "Failed to mount temporary DMG for customization." >&2
  exit 1
fi

volume_icon_path="${APP_PATH}/Contents/Resources/AppIcon.icns"
if [[ -f "${volume_icon_path}" ]]; then
  cp "${volume_icon_path}" "${mount_point}/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "${mount_point}" || true
  fi
fi

# Prefer a native macOS alias for Applications so Finder shows the expected icon.
app_link_path="${mount_point}/Applications"
if command -v osascript >/dev/null 2>&1 && [[ -L "${app_link_path}" ]]; then
  mv "${app_link_path}" "${app_link_path}.symlink"
  if osascript - "${mount_point}" >/dev/null 2>&1 <<'EOF'
on run argv
  set targetFolderPath to item 1 of argv
  tell application "Finder"
    set targetFolder to POSIX file targetFolderPath as alias
    set appAlias to make new alias file at targetFolder to POSIX file "/Applications"
    set name of appAlias to "Applications"
  end tell
end run
EOF
  then
    rm -f "${app_link_path}.symlink"
  else
    mv "${app_link_path}.symlink" "${app_link_path}"
    echo "Warning: failed to create Applications alias. Using symlink fallback." >&2
  fi
fi

if command -v osascript >/dev/null 2>&1; then
  osascript - "${VOLUME_NAME}" "${DMG_WINDOW_BOUNDS}" "${DMG_ICON_SIZE}" "${app_name}" <<'EOF' \
    || echo "Warning: Finder layout customization skipped." >&2
on run argv
  set volumeName to item 1 of argv
  set windowBounds to item 2 of argv
  set iconSize to (item 3 of argv) as integer
  set appName to item 4 of argv
  set oldDelimiters to AppleScript's text item delimiters
  set AppleScript's text item delimiters to ","
  set boundsList to text items of windowBounds
  set AppleScript's text item delimiters to oldDelimiters

  tell application "Finder"
    tell disk volumeName
      open
      tell container window
        set current view to icon view
        set toolbar visible to false
        set statusbar visible to false
        set bounds to {item 1 of boundsList as integer, item 2 of boundsList as integer, item 3 of boundsList as integer, item 4 of boundsList as integer}
      end tell
      tell icon view options of container window
        set arrangement to not arranged
        set icon size to iconSize
        if exists file ".background:background.png" then
          set background picture to file ".background:background.png"
        end if
      end tell
      set position of item appName to {160, 200}
      set position of item "Applications" to {460, 200}
      close
      open
      update without registering applications
      delay 1
    end tell
  end tell
end run
EOF
fi

hdiutil detach "${device}" -quiet || {
  sleep 2
  hdiutil detach "${device}" -force -quiet
}

hdiutil convert "${rw_dmg_path}" -ov -format UDZO -o "${DMG_PATH}"
rm -f "${rw_dmg_path}"

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

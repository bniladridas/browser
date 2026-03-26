#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${APP_PATH:-build/macos/Build/Products/Release/browser.app}"
DMG_PATH="${DMG_PATH:-build/macos/Build/Products/Release/browser.dmg}"
VOLUME_NAME="${VOLUME_NAME:-browser}"
TMP_ROOT="${TMP_ROOT:-}"
ALLOW_UNSIGNED="${ALLOW_UNSIGNED:-}"
DMG_WINDOW_BOUNDS="${DMG_WINDOW_BOUNDS:-100,100,900,650}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-128}"
DMG_BACKGROUND_IMAGE="${DMG_BACKGROUND_IMAGE:-}"
DMG_BACKGROUND_COLOR="${DMG_BACKGROUND_COLOR:-#6b6d70}" # e.g. "#6b6d70" (generates a solid PNG)
DMG_HEADROOM_MB="${DMG_HEADROOM_MB:-50}"
DMG_APPLICATIONS_LINK_TYPE="${DMG_APPLICATIONS_LINK_TYPE:-symlink}" # symlink|alias
DMG_LABEL_INDEX="${DMG_LABEL_INDEX:-4}" # Finder label index 0-7; affects filename color (0 = none)

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

background_filename=""
if [[ -n "${DMG_BACKGROUND_COLOR}" ]]; then
  IFS=',' read -r bounds_left bounds_top bounds_right bounds_bottom <<<"${DMG_WINDOW_BOUNDS}"
  width="$((bounds_right - bounds_left))"
  height="$((bounds_bottom - bounds_top))"
  if [[ "${width}" -le 0 || "${height}" -le 0 ]]; then
    width=800
    height=520
  fi

  background_filename="background.png"
  mkdir -p "${dmg_root}/.background"
  python3 - "${dmg_root}/.background/${background_filename}" "${width}" "${height}" "${DMG_BACKGROUND_COLOR}" <<'PY'
import re
import struct
import zlib
import sys

out_path, width_s, height_s, color = sys.argv[1:5]
width = int(width_s)
height = int(height_s)

m = re.fullmatch(r'#?([0-9a-fA-F]{6})', color.strip())
if not m:
  raise SystemExit(f"Invalid DMG_BACKGROUND_COLOR: {color} (expected #RRGGBB)")
rgb = bytes.fromhex(m.group(1))
r, g, b = rgb[0], rgb[1], rgb[2]

def chunk(tag: bytes, data: bytes) -> bytes:
  return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

signature = b"\x89PNG\r\n\x1a\n"
ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit, truecolor RGB

# Raw scanlines: each row starts with filter byte 0, then RGB triplets.
row = bytes([0]) + bytes([r, g, b]) * width
raw = row * height
compressed = zlib.compress(raw, level=9)

png = signature + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
with open(out_path, "wb") as f:
  f.write(png)
PY
elif [[ -n "${DMG_BACKGROUND_IMAGE}" && -f "${DMG_BACKGROUND_IMAGE}" ]]; then
  bg_ext="${DMG_BACKGROUND_IMAGE##*.}"
  bg_ext="$(printf '%s' "${bg_ext}" | tr '[:upper:]' '[:lower:]')"
  case "${bg_ext}" in
    png|jpg|jpeg) ;;
    *) bg_ext="png" ;;
  esac

  background_filename="background.${bg_ext}"
  mkdir -p "${dmg_root}/.background"
  cp "${DMG_BACKGROUND_IMAGE}" "${dmg_root}/.background/${background_filename}"
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

mounted_volume_name="$(basename "${mount_point}")"

volume_icon_path="${APP_PATH}/Contents/Resources/AppIcon.icns"
if [[ -f "${volume_icon_path}" ]]; then
  cp "${volume_icon_path}" "${mount_point}/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -a C "${mount_point}" || true
  fi
fi

if [[ "${DMG_APPLICATIONS_LINK_TYPE}" == "alias" ]]; then
  # Optional: create a native macOS alias for Applications.
  # Note: on some systems Finder may render alias icons inconsistently inside DMGs; symlink is the default.
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
fi

if command -v osascript >/dev/null 2>&1; then
  # hdiutil may mount the image as "Browser 1" etc. when the base volume name is already in use.
  # Always target the actual mounted volume name to ensure Finder customization persists to this DMG.
  osascript - "${mounted_volume_name}" "${DMG_WINDOW_BOUNDS}" "${DMG_ICON_SIZE}" "${app_name}" "${background_filename}" "${mount_point}" "${DMG_LABEL_INDEX}" <<'EOF' \
    || echo "Warning: Finder layout customization skipped for '${mounted_volume_name}'." >&2
on run argv
	  set volumeName to item 1 of argv
	  set windowBounds to item 2 of argv
	  set iconSize to (item 3 of argv) as integer
	  set appName to item 4 of argv
	  set backgroundName to item 5 of argv
	  set mountPoint to item 6 of argv
	  set labelIndex to (item 7 of argv) as integer
	  set oldDelimiters to AppleScript's text item delimiters
	  set AppleScript's text item delimiters to ","
	  set boundsList to text items of windowBounds
	  set AppleScript's text item delimiters to oldDelimiters

		  tell application "Finder"
		    tell disk volumeName
		      open
		      delay 0.8
		      tell container window
		        set current view to icon view
		        set toolbar visible to false
		        set statusbar visible to false
		        set bounds to {item 1 of boundsList as integer, item 2 of boundsList as integer, item 3 of boundsList as integer, item 4 of boundsList as integer}
		      end tell
		      delay 0.8
		      set bgAlias to missing value
		      try
		        if backgroundName is not "" then
		          set bgAlias to (POSIX file (mountPoint & "/.background/" & backgroundName)) as alias
		        end if
		      end try
		      tell icon view options of container window
		        set arrangement to not arranged
		        set icon size to iconSize
		        if bgAlias is not missing value then
		          set background picture to bgAlias
		        end if
		      end tell
		      delay 0.8
		      set appItemName to appName
		      if not (exists item appItemName) then
		        if exists item (appName & ".app") then
		          set appItemName to (appName & ".app")
		        end if
		      end if
		      if labelIndex is not 0 then
		        try
		          set label index of item appItemName to labelIndex
		        end try
		        try
		          set label index of item "Applications" to labelIndex
		        end try
		      end if
		      try
		        set position of item appItemName to {220, 300}
		      end try
		      try
		        set position of item "Applications" to {620, 300}
	      end try
	      close
	      open
	      update without registering applications
	      delay 1
	    end tell
	  end tell
	end run
EOF

  if [[ ! -f "${mount_point}/.DS_Store" ]]; then
    echo "Warning: Finder customization did not write .DS_Store for '${mounted_volume_name}' (${mount_point})." >&2
  fi
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

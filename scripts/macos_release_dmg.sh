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
DMG_BACKGROUND_MIN_WIDTH="${DMG_BACKGROUND_MIN_WIDTH:-4096}"   # Ensure background covers fullscreen Finder windows.
DMG_BACKGROUND_MIN_HEIGHT="${DMG_BACKGROUND_MIN_HEIGHT:-2560}" # Finder doesn't scale background pictures.
DMG_BACKGROUND_MAX_WIDTH="${DMG_BACKGROUND_MAX_WIDTH:-8192}"
DMG_BACKGROUND_MAX_HEIGHT="${DMG_BACKGROUND_MAX_HEIGHT:-8192}"
DMG_INSTALL_NOTES_MODE="${DMG_INSTALL_NOTES_MODE:-off}" # off|background
DMG_INSTALL_NOTES_TEXT="${DMG_INSTALL_NOTES_TEXT:-}"
# Overlay box for background notes: "x,y,w,h" in background image pixels (top-left origin).
DMG_INSTALL_NOTES_BOX="${DMG_INSTALL_NOTES_BOX:-120,380,560,150}"
DMG_INSTALL_NOTES_TITLE_SIZE="${DMG_INSTALL_NOTES_TITLE_SIZE:-22}"
DMG_INSTALL_NOTES_BODY_SIZE="${DMG_INSTALL_NOTES_BODY_SIZE:-16}"
DMG_INSTALL_NOTES_TEXT_COLOR="${DMG_INSTALL_NOTES_TEXT_COLOR:-#ffffff}"
DMG_INSTALL_NOTES_BOX_ALPHA="${DMG_INSTALL_NOTES_BOX_ALPHA:-0.20}"
DMG_HEADROOM_MB="${DMG_HEADROOM_MB:-50}"
DMG_APPLICATIONS_LINK_TYPE="${DMG_APPLICATIONS_LINK_TYPE:-alias}" # alias|symlink
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
  if [[ "${DMG_BACKGROUND_MIN_WIDTH}" =~ ^[0-9]+$ && "${DMG_BACKGROUND_MIN_HEIGHT}" =~ ^[0-9]+$ ]]; then
    if [[ "${width}" -lt "${DMG_BACKGROUND_MIN_WIDTH}" ]]; then width="${DMG_BACKGROUND_MIN_WIDTH}"; fi
    if [[ "${height}" -lt "${DMG_BACKGROUND_MIN_HEIGHT}" ]]; then height="${DMG_BACKGROUND_MIN_HEIGHT}"; fi
  fi
  if [[ "${DMG_BACKGROUND_MAX_WIDTH}" =~ ^[0-9]+$ && "${DMG_BACKGROUND_MAX_HEIGHT}" =~ ^[0-9]+$ ]]; then
    if [[ "${width}" -gt "${DMG_BACKGROUND_MAX_WIDTH}" ]]; then width="${DMG_BACKGROUND_MAX_WIDTH}"; fi
    if [[ "${height}" -gt "${DMG_BACKGROUND_MAX_HEIGHT}" ]]; then height="${DMG_BACKGROUND_MAX_HEIGHT}"; fi
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
# Stream through zlib to avoid allocating width*height raw bytes for large backgrounds.
row = bytes([0]) + bytes([r, g, b]) * width
compressor = zlib.compressobj(level=9)
parts = []
for _ in range(height):
  parts.append(compressor.compress(row))
parts.append(compressor.flush())
compressed = b"".join(parts)

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

if [[ "${DMG_INSTALL_NOTES_MODE}" == "background" && -n "${background_filename}" && -n "${DMG_INSTALL_NOTES_TEXT}" ]] && command -v swift >/dev/null 2>&1; then
  notes_bg_path="${dmg_root}/.background/${background_filename}"
  if [[ -f "${notes_bg_path}" ]]; then
    swift_script="$(mktemp -t dmg-bg-notes.XXXXXX.swift)"
    cat >"${swift_script}" <<'SWIFT'
import AppKit
import Foundation

func parseHex(_ hex: String) throws -> NSColor {
  var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
  if s.hasPrefix("#") { s.removeFirst() }
  guard s.count == 6 else { throw NSError(domain: "hex", code: 1) }
  let r = CGFloat(Int(s.prefix(2), radix: 16) ?? 0) / 255.0
  let g = CGFloat(Int(s.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
  let b = CGFloat(Int(s.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255.0
  return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
}

func parseBox(_ s: String) throws -> (Int, Int, Int, Int) {
  let parts = s.split(separator: ",").map { Int($0.trimmingCharacters(in: .whitespaces)) ?? -1 }
  guard parts.count == 4, parts.allSatisfy({ $0 >= 0 }) else { throw NSError(domain: "box", code: 1) }
  return (parts[0], parts[1], parts[2], parts[3])
}

func splitTitleBody(_ text: String) -> (String, String) {
  let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
  if let range = normalized.range(of: "\n\n") {
    let title = String(normalized[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    let body = String(normalized[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    return (title, body)
  }
  return ("", normalized.trimmingCharacters(in: .whitespacesAndNewlines))
}

let args = CommandLine.arguments.dropFirst()
guard args.count == 7 else { exit(2) }

let imagePath = String(args[args.startIndex])
let notesText = String(args[args.index(args.startIndex, offsetBy: 1)])
let boxText = String(args[args.index(args.startIndex, offsetBy: 2)])
let titleSize = CGFloat(Double(args[args.index(args.startIndex, offsetBy: 3)]) ?? 22.0)
let bodySize = CGFloat(Double(args[args.index(args.startIndex, offsetBy: 4)]) ?? 16.0)
let textHex = String(args[args.index(args.startIndex, offsetBy: 5)])
let boxAlpha = CGFloat(Double(args[args.index(args.startIndex, offsetBy: 6)]) ?? 0.2)

guard let base = NSImage(contentsOfFile: imagePath) else { exit(3) }
let size = base.size
guard size.width > 0, size.height > 0 else { exit(4) }

let (boxX, boxYTop, boxW, boxH) = try parseBox(boxText)
let (title, body) = splitTitleBody(notesText)
let textColor = try parseHex(textHex)

let out = NSImage(size: size)
out.lockFocus()
defer { out.unlockFocus() }

base.draw(in: NSRect(origin: .zero, size: size))

// Convert from top-left origin (env var) to AppKit bottom-left origin.
let rectY = CGFloat(size.height) - CGFloat(boxYTop) - CGFloat(boxH)
let rect = NSRect(x: CGFloat(boxX), y: rectY, width: CGFloat(boxW), height: CGFloat(boxH))

NSColor(calibratedWhite: 0.0, alpha: max(0, min(1, boxAlpha))).setFill()
NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.lineBreakMode = .byWordWrapping

let padding: CGFloat = 14
let textRect = rect.insetBy(dx: padding, dy: padding)
var cursorY = textRect.maxY

func draw(_ string: String, font: NSFont, in rect: NSRect) -> CGFloat {
  let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor,
    .paragraphStyle: paragraph,
  ]
  let ns = string as NSString
  let bounding = ns.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin], attributes: attrs)
  ns.draw(in: rect, withAttributes: attrs)
  return bounding.height
}

if !title.isEmpty {
  let font = NSFont.boldSystemFont(ofSize: titleSize)
  let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor,
    .paragraphStyle: paragraph,
  ]
  let ns = title as NSString
  let bounding = ns.boundingRect(with: NSSize(width: textRect.width, height: 99999), options: [.usesLineFragmentOrigin], attributes: attrs)
  cursorY -= bounding.height
  ns.draw(in: NSRect(x: textRect.minX, y: cursorY, width: textRect.width, height: bounding.height), withAttributes: attrs)
  cursorY -= 10
}

if !body.isEmpty {
  let font = NSFont.systemFont(ofSize: bodySize)
  _ = draw(body, font: font, in: NSRect(x: textRect.minX, y: textRect.minY, width: textRect.width, height: cursorY - textRect.minY))
}

guard let tiff = out.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(5) }

try png.write(to: URL(fileURLWithPath: imagePath), options: .atomic)
SWIFT

    swift "${swift_script}" \
      "${notes_bg_path}" \
      "${DMG_INSTALL_NOTES_TEXT}" \
      "${DMG_INSTALL_NOTES_BOX}" \
      "${DMG_INSTALL_NOTES_TITLE_SIZE}" \
      "${DMG_INSTALL_NOTES_BODY_SIZE}" \
      "${DMG_INSTALL_NOTES_TEXT_COLOR}" \
      "${DMG_INSTALL_NOTES_BOX_ALPHA}"
    rm -f "${swift_script}"
  fi
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
  # Create a native macOS alias for Applications (default).
  # If alias creation fails, fall back to the existing symlink.
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
		    set appsIcon to missing value
		    try
		      set appsIcon to icon of folder "Applications" of startup disk
		    end try
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
		        try
		          set shows icon preview to false
		        end try
		        try
		          set shows item info to false
		        end try
		        set icon size to iconSize
		        if bgAlias is not missing value then
		          set background picture to bgAlias
		        end if
		      end tell
		      if appsIcon is not missing value then
		        try
		          set icon of item "Applications" to appsIcon
		        end try
		      end if
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

if command -v SetFile >/dev/null 2>&1; then
  # If the Applications link is an alias, set the custom icon bit so Finder renders the icon reliably.
  # Ignore errors (SetFile may fail depending on the mounted filesystem state).
  if [[ -f "${mount_point}/Applications" && ! -L "${mount_point}/Applications" ]]; then
    SetFile -a C "${mount_point}/Applications" || true
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

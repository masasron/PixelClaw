#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="${APP_NAME:-PixelClaw}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/Dist}"
APP_BUNDLE="${APP_BUNDLE:-$DIST_DIR/$APP_NAME.app}"
DMG_PATH="${DMG_PATH:-$DIST_DIR/$APP_NAME.dmg}"
VOLUME_NAME="${VOLUME_NAME:-$APP_NAME}"

WINDOW_LEFT=120
WINDOW_TOP=120
WINDOW_WIDTH=760
WINDOW_HEIGHT=460
APP_ICON_X=210
APP_ICON_Y=215
APPLICATIONS_ICON_X=550
APPLICATIONS_ICON_Y=215
ICON_SIZE=160
TEXT_SIZE=10
LABEL_BOX_WIDTH=170
LABEL_BOX_HEIGHT=34
LABEL_BOX_RADIUS=8
LABEL_BOX_Y=318

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing app bundle at $APP_BUNDLE" >&2
  echo "Build it first with: make app" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${APP_NAME}.dmg.XXXXXX")"
STAGING_DIR="$TMP_DIR/staging"
RW_DMG="$TMP_DIR/$APP_NAME-temp.dmg"
BACKGROUND_DIR="$TMP_DIR/background"
BACKGROUND_PNG="$BACKGROUND_DIR/background.png"
MOUNT_DIR=""

cleanup() {
  if [[ -n "$MOUNT_DIR" ]] && mount | grep -q "on $MOUNT_DIR "; then
    hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet || true
  fi
  rm -rf "$TMP_DIR"
}

trap cleanup EXIT

mkdir -p "$STAGING_DIR" "$BACKGROUND_DIR" "$(dirname "$DMG_PATH")"
ditto "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

WINDOW_WIDTH="$WINDOW_WIDTH" \
WINDOW_HEIGHT="$WINDOW_HEIGHT" \
BACKGROUND_PNG="$BACKGROUND_PNG" \
APP_ICON_X="$APP_ICON_X" \
APPLICATIONS_ICON_X="$APPLICATIONS_ICON_X" \
LABEL_BOX_WIDTH="$LABEL_BOX_WIDTH" \
LABEL_BOX_HEIGHT="$LABEL_BOX_HEIGHT" \
LABEL_BOX_RADIUS="$LABEL_BOX_RADIUS" \
LABEL_BOX_Y="$LABEL_BOX_Y" \
/usr/bin/swift -e '
import AppKit
import Foundation

func envInt(_ key: String) -> CGFloat {
    CGFloat(Int(ProcessInfo.processInfo.environment[key]!)!)
}

let width = envInt("WINDOW_WIDTH")
let height = envInt("WINDOW_HEIGHT")
let output = URL(fileURLWithPath: ProcessInfo.processInfo.environment["BACKGROUND_PNG"]!)

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

NSColor(
    calibratedRed: 0x26 as CGFloat / 255.0,
    green: 0x26 as CGFloat / 255.0,
    blue: 0x24 as CGFloat / 255.0,
    alpha: 1.0
).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

let boxWidth = envInt("LABEL_BOX_WIDTH")
let boxHeight = envInt("LABEL_BOX_HEIGHT")
let radius = envInt("LABEL_BOX_RADIUS")
let boxY = envInt("LABEL_BOX_Y")

for iconX in [envInt("APP_ICON_X"), envInt("APPLICATIONS_ICON_X")] {
    let rect = NSRect(
        x: iconX - (boxWidth / 2.0),
        y: height - boxY - boxHeight,
        width: boxWidth,
        height: boxHeight
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.96).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("Failed to create DMG background image\n", stderr)
    exit(1)
}

try png.write(to: output)
'

hdiutil create \
  -quiet \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -size 160m \
  "$RW_DMG"

MOUNT_DIR="$(
  hdiutil attach \
    -readwrite \
    -noverify \
    -noautoopen \
    "$RW_DMG" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/"))}'
)"

if [[ -z "$MOUNT_DIR" ]]; then
  echo "Failed to determine mounted DMG path" >&2
  exit 1
fi

sleep 1

mkdir -p "$MOUNT_DIR/.background"
cp "$BACKGROUND_PNG" "$MOUNT_DIR/.background/background.png"
SetFile -a V "$MOUNT_DIR/.background"
SetFile -a V "$MOUNT_DIR/.background/background.png"

/usr/bin/osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {$WINDOW_LEFT, $WINDOW_TOP, $(($WINDOW_LEFT + $WINDOW_WIDTH)), $(($WINDOW_TOP + $WINDOW_HEIGHT))}
        tell the icon view options of container window
            set arrangement to not arranged
            set icon size to $ICON_SIZE
            set text size to $TEXT_SIZE
            try
                set background picture to file ".background:background.png"
            on error errMsg number errNum
                if errNum is not -10006 then error errMsg number errNum
            end try
        end tell
        set position of item "$APP_NAME.app" of container window to {$APP_ICON_X, $APP_ICON_Y}
        set position of item "Applications" of container window to {$APPLICATIONS_ICON_X, $APPLICATIONS_ICON_Y}
        close
        open
        update without registering applications
        delay 3
        close
    end tell
end tell
EOF

for _ in {1..20}; do
  if [[ -f "$MOUNT_DIR/.DS_Store" ]]; then
    break
  fi
  sleep 1
done

if [[ ! -f "$MOUNT_DIR/.DS_Store" ]]; then
  echo "Finder did not persist DMG layout metadata (.DS_Store)." >&2
  exit 1
fi

sync
sleep 1
hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""

rm -f "$DMG_PATH"
hdiutil convert \
  -quiet \
  "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH"

echo "Created $DMG_PATH"

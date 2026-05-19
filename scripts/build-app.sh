#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CommandGathering"
EXECUTABLE_NAME="CommandGatheringApp"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DATA_DIR="$APP_DIR/CommandGatheringData"
ICON_SOURCE="$ROOT_DIR/Sources/jpg.png"
ICON_NAME="AppIcon"
PRESERVED_DATA_DIR=""

cd "$ROOT_DIR"

swift build -c release

if [[ -d "$DATA_DIR" ]]; then
  PRESERVED_DATA_DIR="$(mktemp -d)/CommandGatheringData"
  cp -R "$DATA_DIR" "$PRESERVED_DATA_DIR"
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/$EXECUTABLE_NAME" "$MACOS_DIR/$APP_NAME"

if [[ -f "$ICON_SOURCE" ]]; then
  ICONSET_DIR="$(mktemp -d)/${ICON_NAME}.iconset"
  mkdir -p "$ICONSET_DIR"

  while read -r size filename; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
  done <<'ICONSET'
16 icon_16x16.png
32 icon_16x16@2x.png
32 icon_32x32.png
64 icon_32x32@2x.png
128 icon_128x128.png
256 icon_128x128@2x.png
256 icon_256x256.png
512 icon_256x256@2x.png
512 icon_512x512.png
1024 icon_512x512@2x.png
ICONSET

  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/${ICON_NAME}.icns"
  rm -rf "$ICONSET_DIR"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CommandGathering</string>
  <key>CFBundleIdentifier</key>
  <string>local.command-gathering</string>
  <key>CFBundleName</key>
  <string>CommandGathering</string>
  <key>CFBundleDisplayName</key>
  <string>Command Gathering</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -n "$PRESERVED_DATA_DIR" && -d "$PRESERVED_DATA_DIR" ]]; then
  cp -R "$PRESERVED_DATA_DIR" "$DATA_DIR"
fi

echo "$APP_DIR"

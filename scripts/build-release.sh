#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/dist/release"
APP_NAME="CommandGathering"
RELEASE_APP_NAME="CommandGathering-Clean"
EXECUTABLE_NAME="CommandGatheringApp"
APP_DIR="$RELEASE_DIR/$RELEASE_APP_NAME.app"
ARCHIVE_APP_NAME="$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$ROOT_DIR/Sources/jpg.png"
ICON_NAME="AppIcon"
DEFAULT_BUNDLE_IDENTIFIER="local.command-gathering.clean-release"
BUNDLE_IDENTIFIER="${CG_BUNDLE_IDENTIFIER:-$DEFAULT_BUNDLE_IDENTIFIER}"
SIGN_IDENTITY="${CG_SIGN_IDENTITY:-}"
NOTARY_PROFILE="${CG_NOTARY_PROFILE:-}"
NOTARY_KEYCHAIN="${CG_NOTARY_KEYCHAIN:-}"
REQUIRE_DEVELOPER_ID="${CG_REQUIRE_DEVELOPER_ID:-0}"
TMP_DIR="$(mktemp -d)"
ARCHIVE_STAGING_DIR="$TMP_DIR/archive"
ARCHIVE_APP_DIR="$ARCHIVE_STAGING_DIR/$ARCHIVE_APP_NAME.app"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

find_developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null | \
    sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1
}

create_archive() {
  local archive_path="$1"

  rm -f "$archive_path"
  rm -rf "$ARCHIVE_STAGING_DIR"
  mkdir -p "$ARCHIVE_STAGING_DIR"
  cp -R "$APP_DIR" "$ARCHIVE_APP_DIR"

  (
    cd "$ARCHIVE_STAGING_DIR"
    ditto -c -k --sequesterRsrc --keepParent "$ARCHIVE_APP_NAME.app" "$archive_path"
  )
}

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(find_developer_id_identity)"
fi

if [[ -z "$SIGN_IDENTITY" && "$REQUIRE_DEVELOPER_ID" == "1" ]]; then
  echo "未找到 Developer ID Application 证书，无法执行正式分发打包。" >&2
  exit 1
fi

if [[ -n "$NOTARY_PROFILE" && -z "$SIGN_IDENTITY" ]]; then
  echo "配置了 CG_NOTARY_PROFILE，但当前没有可用的 Developer ID Application 证书。" >&2
  exit 1
fi

cd "$ROOT_DIR"
swift build -c release

mkdir -p "$RELEASE_DIR"
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

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>CommandGathering</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_IDENTIFIER}</string>
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

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "使用 Developer ID 证书签名: $SIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP_DIR"
else
  echo "未找到 Developer ID 证书，回退为 ad-hoc 签名。"
  codesign --force --deep --sign - --timestamp=none "$APP_DIR"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

PLIST_PATH="$APP_DIR/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST_PATH")"

ARCHIVE_PATH="$RELEASE_DIR/CommandGathering-v${VERSION}-macOS.zip"
create_archive "$ARCHIVE_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "提交公证: profile=$NOTARY_PROFILE"
  NOTARY_ARGS=(submit "$ARCHIVE_PATH" --keychain-profile "$NOTARY_PROFILE" --wait)
  if [[ -n "$NOTARY_KEYCHAIN" ]]; then
    NOTARY_ARGS+=(--keychain "$NOTARY_KEYCHAIN")
  fi
  xcrun notarytool "${NOTARY_ARGS[@]}"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"
  create_archive "$ARCHIVE_PATH"
fi

echo "本地干净版 App: $APP_DIR"
echo "发布压缩包: $ARCHIVE_PATH"

echo "$ARCHIVE_PATH"

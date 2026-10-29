#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Bitz"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
DMG_PATH="$BUILD_DIR/${APP_NAME}.dmg"
DMG_STAGING="$BUILD_DIR/dmg_staging"

echo "==> Packaging ${APP_NAME}.app for release..."

# Ensure build/Bitz.app is present
if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "==> Compiling application..."
    /usr/bin/swift build -c release --product "$APP_NAME"
    BIN_PATH="$(/usr/bin/swift build -c release --show-bin-path)/${APP_NAME}"
    CONTENTS_DIR="$APP_BUNDLE/Contents"
    MACOS_DIR="$CONTENTS_DIR/MacOS"
    RESOURCES_DIR="$CONTENTS_DIR/Resources"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
    cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
    chmod +x "$MACOS_DIR/$APP_NAME"
    if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
        cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    fi
    cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.bitz.cybercat</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Bitz the Cyber Cat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>3</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "==> Staging disk image layout..."
rm -rf "$DMG_STAGING" "$DMG_PATH"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Creating compressed disk image: ${DMG_PATH}..."
hdiutil create -volname "${APP_NAME}" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"

echo "=========================================================="
echo "✨ Distribution Disk Image Ready!"
echo "📦 DMG: ${DMG_PATH}"
echo "File size: $(du -h "$DMG_PATH" | cut -f1)"
echo "=========================================================="

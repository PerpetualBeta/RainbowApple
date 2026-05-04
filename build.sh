#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="RainbowApple"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
SIGN_ID="${SIGN_ID:-Developer ID Application: Jonthan Hollin (EG86BCGUE7)}"

echo "Building $APP_NAME..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"

swiftc -O -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "$SCRIPT_DIR/main.swift" \
    "$SCRIPT_DIR/AboutView.swift" \
    "$SCRIPT_DIR/RainbowAppleSettingsContent.swift" \
    "$SCRIPT_DIR"/JorvikKit/*.swift \
    -F "$SCRIPT_DIR" \
    -framework Cocoa \
    -framework SwiftUI \
    -framework ServiceManagement \
    -framework Sparkle \
    -Xlinker -rpath -Xlinker '@executable_path/../Frameworks'

cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$SCRIPT_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> Embedding Sparkle.framework..."
cp -R "$SCRIPT_DIR/Sparkle.framework" "$APP_BUNDLE/Contents/Frameworks/"

echo "==> Signing nested Sparkle code (leaves first)..."
SP="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$SP/XPCServices/Downloader.xpc"
codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$SP/XPCServices/Installer.xpc"
codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$SP/Updater.app"
codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$SP/Autoupdate"
codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

echo "==> Signing $APP_NAME.app..."
codesign --force --sign "$SIGN_ID" \
    --entitlements "$SCRIPT_DIR/$APP_NAME.entitlements" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE"

echo "Built: $APP_BUNDLE"

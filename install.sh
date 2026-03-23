#!/bin/bash
set -e

APP_NAME="SunScreen"
APP_BUNDLE="$APP_NAME.app"
INSTALL_DIR="/Applications"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp .build/release/$APP_NAME "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"

echo "Code signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Installing to $INSTALL_DIR..."
if [ -d "$INSTALL_DIR/$APP_BUNDLE" ]; then
    rm -rf "$INSTALL_DIR/$APP_BUNDLE"
fi
cp -R "$APP_BUNDLE" "$INSTALL_DIR/$APP_BUNDLE"

echo ""
echo "✓ $APP_NAME installed to $INSTALL_DIR/$APP_BUNDLE"
echo ""
echo "To launch: open $INSTALL_DIR/$APP_BUNDLE"
echo ""

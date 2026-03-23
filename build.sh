#!/bin/bash
set -e

echo "=== Building SunScreen ==="

if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools are required."
    echo "Install with:  xcode-select --install"
    exit 1
fi

APP_NAME="SunScreen"
APP_BUNDLE="build/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

echo "Compiling with Swift Package Manager..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp .build/release/$APP_NAME "$CONTENTS/MacOS/$APP_NAME"
cp Resources/Info.plist "$CONTENTS/"
cp Resources/AppIcon.icns "$CONTENTS/Resources/"

echo "Signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""
echo "  Run now:      open $APP_BUNDLE"
echo "  Install:      cp -r $APP_BUNDLE /Applications/"
echo ""

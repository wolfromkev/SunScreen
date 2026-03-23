#!/bin/bash
set -e

echo "=== Building SunScreen ==="

if ! xcode-select -p &>/dev/null; then
    echo "Error: Xcode Command Line Tools are required."
    echo "Install with:  xcode-select --install"
    exit 1
fi

SDK_PATH=$(xcrun --show-sdk-path)
APP_NAME="SunScreen"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

echo "Compiling C helper..."
cc -c Sources/brightness_helper.c \
   -o "$BUILD_DIR/brightness_helper.o" \
   -isysroot "$SDK_PATH"

echo "Compiling Swift sources..."
swiftc \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/BrightnessManager.swift \
    Sources/BlueLightManager.swift \
    Sources/ScheduleManager.swift \
    Sources/ContentView.swift \
    "$BUILD_DIR/brightness_helper.o" \
    -import-objc-header Sources/brightness_helper.h \
    -o "$CONTENTS/MacOS/$APP_NAME" \
    -sdk "$SDK_PATH" \
    -framework AppKit \
    -framework SwiftUI \
    -framework IOKit \
    -framework CoreGraphics \
    -O

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

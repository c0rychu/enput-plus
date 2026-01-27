#!/bin/bash

# EnputPlus DMG Builder Script
# Creates a production-ready DMG with drag-and-drop installation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="EnputPlus.app"
DMG_NAME="EnputPlus"
VOLUME_NAME="EnputPlus"

# Extract version from Xcode project
VERSION=$(xcodebuild -project "$PROJECT_DIR/EnputPlus.xcodeproj" -showBuildSettings 2>/dev/null | grep MARKETING_VERSION | head -1 | awk '{print $3}')
if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from Xcode project"
    exit 1
fi
echo "Version: $VERSION"
DMG_TEMP="$PROJECT_DIR/${DMG_NAME}-temp.dmg"
DMG_PATH="$PROJECT_DIR/${DMG_NAME}-${VERSION}.dmg"

echo "=== EnputPlus DMG Builder ==="
echo ""

# Check if Xcode command line tools are available
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode Command Line Tools."
    exit 1
fi

# Clean previous builds
echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"
rm -rf "$DIST_DIR"
rm -f "$DMG_TEMP"
rm -f "$DMG_PATH"
mkdir -p "$DIST_DIR"

# Build for Release
echo "Building EnputPlus (Release)..."
cd "$PROJECT_DIR"
xcodebuild -project EnputPlus.xcodeproj \
    -scheme EnputPlus \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build

# Find the built app
BUILT_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Built app not found at $BUILT_APP"
    exit 1
fi

# Copy app to dist
cp -R "$BUILT_APP" "$DIST_DIR/"

# Copy Quit script (for updating)
cp "$SCRIPT_DIR/QuitBeforeUpdate.command" "$DIST_DIR/"
chmod +x "$DIST_DIR/QuitBeforeUpdate.command"

# Ensure Input Methods folder exists for the user
mkdir -p "$HOME/Library/Input Methods"

# Create symbolic link to Input Methods folder
ln -s "$HOME/Library/Input Methods" "$DIST_DIR/Input Methods"

# Copy background image if it exists
if [ -f "$SCRIPT_DIR/dmg-background.png" ]; then
    echo "Using custom background image..."
    mkdir -p "$DIST_DIR/.background"
    cp "$SCRIPT_DIR/dmg-background.png" "$DIST_DIR/.background/background.png"
else
    echo "Note: No background image found. Create Scripts/dmg-background.png (540x370) to add one."
fi

# Code signing configuration
SIGNING_IDENTITY="Developer ID Application: Yu-Kuang Chu (G3F7QCP2GS)"
NOTARIZE_PROFILE="EnputPlus-notarize"

# Sign the app with hardened runtime
echo "Signing app with Developer ID..."
codesign --deep --force --verify --verbose \
    --sign "$SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    "$DIST_DIR/$APP_NAME"

# Verify signature
echo "Verifying signature..."
codesign --verify --verbose=2 "$DIST_DIR/$APP_NAME"

# Create temporary read-write DMG
echo "Creating DMG..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DIST_DIR" \
    -ov \
    -format UDRW \
    "$DMG_TEMP"

# Mount the DMG
echo "Configuring DMG appearance..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$DMG_TEMP" | grep "/Volumes/$VOLUME_NAME" | awk '{print $3}')

if [ -z "$MOUNT_DIR" ]; then
    echo "Error: Failed to mount DMG"
    exit 1
fi

# Configure DMG window appearance using AppleScript
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 150, 940, 580}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 72

        -- Set background image if it exists
        try
            set background picture of theViewOptions to file ".background:background.png"
        end try

        -- Position items: App on left, destination on right, quit script bottom-left
        set position of item "$APP_NAME" of container window to {130, 110}
        set position of item "Input Methods" of container window to {410, 110}
        set position of item "QuitBeforeUpdate.command" of container window to {80, 290}

        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

# Ensure changes are written
sync

# Unmount
hdiutil detach "$MOUNT_DIR" -quiet

# Convert to compressed read-only DMG
echo "Compressing DMG..."
hdiutil convert "$DMG_TEMP" -format UDZO -o "$DMG_PATH"

# Clean up temp DMG
rm -f "$DMG_TEMP"

# Sign the DMG
echo "Signing DMG..."
codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"

# Notarize
echo "Submitting for notarization..."
xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait

# Staple the notarization ticket
echo "Stapling notarization ticket..."
xcrun stapler staple "$DMG_PATH"

echo ""
echo "=== DMG Created and Notarized ==="
echo "Location: $DMG_PATH"
echo ""
echo "Installation: Drag EnputPlus.app to 'Input Methods' folder, then log out/in."

#!/bin/bash

# EnputPlus DMG Builder Script
# Creates a distributable DMG for EnputPlus

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
DIST_DIR="$PROJECT_DIR/dist"
APP_NAME="EnputPlus.app"
DMG_NAME="EnputPlus"
VERSION="1.0"

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

# Create README for DMG
cat > "$DIST_DIR/README.txt" << 'EOF'
EnputPlus - English Input Method for macOS

INSTALLATION:
1. Drag EnputPlus.app to ~/Library/Input Methods/
   (or copy it manually to /Users/[YourUsername]/Library/Input Methods/)

2. Log out and log back in

3. Open System Settings → Keyboard → Input Sources

4. Click the + button and find "EnputPlus" under English

5. Add it and switch to EnputPlus to start using it

USAGE:
- Type normally - suggestions will appear for partial words
- Use arrow keys or number keys (1-9) to select suggestions
- Press Tab to select the first suggestion
- Press Space or Return to commit your typed text
- Press Escape to cancel

UNINSTALLATION:
1. Remove EnputPlus from Input Sources in System Settings
2. Delete EnputPlus.app from ~/Library/Input Methods/
3. Log out and log back in
EOF

# Check if we should sign (optional)
if [ -n "$DEVELOPER_ID" ]; then
    echo "Signing with Developer ID: $DEVELOPER_ID"
    codesign --deep --force --verify --verbose \
        --sign "Developer ID Application: $DEVELOPER_ID" \
        --options runtime \
        "$DIST_DIR/$APP_NAME"
else
    echo "Note: Skipping code signing. Set DEVELOPER_ID environment variable to sign."
fi

# Create DMG
echo "Creating DMG..."
DMG_PATH="$PROJECT_DIR/${DMG_NAME}-${VERSION}.dmg"

# Remove old DMG if exists
rm -f "$DMG_PATH"

hdiutil create \
    -volname "$DMG_NAME" \
    -srcfolder "$DIST_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

echo ""
echo "=== DMG Created ==="
echo "Location: $DMG_PATH"
echo ""

# Notarization instructions
echo "To notarize (requires Apple Developer account):"
echo ""
echo "  xcrun notarytool submit \"$DMG_PATH\" \\"
echo "    --apple-id \"your@email.com\" \\"
echo "    --team-id \"TEAMID\" \\"
echo "    --password \"app-specific-password\" \\"
echo "    --wait"
echo ""
echo "  xcrun stapler staple \"$DMG_PATH\""

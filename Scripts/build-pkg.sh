#!/bin/bash

# EnputPlus PKG Installer Builder
# Creates a signed and notarized installer package

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/tmp/enputplus-build"
PAYLOAD_DIR="/tmp/enputplus-payload"
APP_NAME="EnputPlus.app"

# Signing identities
APP_SIGNING_IDENTITY="Developer ID Application: Yu-Kuang Chu (G3F7QCP2GS)"
PKG_SIGNING_IDENTITY="Developer ID Installer: Yu-Kuang Chu (G3F7QCP2GS)"
NOTARIZE_PROFILE="EnputPlus-notarize"

# Cleanup temp files on exit
cleanup() {
    rm -rf "/tmp/enputplus-build" 2>/dev/null || true
    rm -rf "/tmp/enputplus-payload" 2>/dev/null || true
    rm -f "/tmp/enputplus-component.pkg" 2>/dev/null || true
    rm -f "/tmp/distribution.xml" 2>/dev/null || true
    rm -f "$PROJECT_DIR/component.plist" 2>/dev/null || true
}
trap cleanup EXIT

# Extract version from Xcode project
VERSION=$(xcodebuild -project "$PROJECT_DIR/EnputPlus.xcodeproj" -showBuildSettings 2>/dev/null | grep MARKETING_VERSION | head -1 | awk '{print $3}')
if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from Xcode project"
    exit 1
fi

PKG_PATH="$PROJECT_DIR/EnputPlus-${VERSION}.pkg"

echo "=== EnputPlus PKG Builder ==="
echo "Version: $VERSION"
echo ""

# Check for installer certificate
if ! security find-identity -v | grep -q "Developer ID Installer"; then
    echo "Error: 'Developer ID Installer' certificate not found."
    echo "You need this certificate to sign .pkg files."
    echo "Download it from: https://developer.apple.com/account/resources/certificates"
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
rm -rf "$PAYLOAD_DIR"
rm -f "$PKG_PATH"

# Build for Release
echo "Building EnputPlus (Release)..."
xcodebuild -project "$PROJECT_DIR/EnputPlus.xcodeproj" \
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

# Sign the app with hardened runtime
echo "Signing app..."
codesign --deep --force --verify --verbose \
    --sign "$APP_SIGNING_IDENTITY" \
    --options runtime \
    --timestamp \
    "$BUILT_APP"

# Create clean payload directory with just the app
echo "Preparing payload..."
mkdir -p "$PAYLOAD_DIR"
# Strip extended attributes to prevent ._* files
xattr -cr "$BUILT_APP"
cp -R "$BUILT_APP" "$PAYLOAD_DIR/"
# Remove any remaining resource fork files
find "$PAYLOAD_DIR" -name '._*' -delete 2>/dev/null || true
find "$PAYLOAD_DIR" -name '.DS_Store' -delete 2>/dev/null || true

# Create component plist to disable relocation
COMPONENT_PLIST="$PROJECT_DIR/component.plist"
cat > "$COMPONENT_PLIST" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>BundleIsRelocatable</key>
        <false/>
        <key>BundleIsVersionChecked</key>
        <false/>
        <key>BundleOverwriteAction</key>
        <string>upgrade</string>
        <key>RootRelativeBundlePath</key>
        <string>EnputPlus.app</string>
    </dict>
</array>
</plist>
PLIST

# Create component package (unsigned, will sign the final product)
echo "Creating component package..."
COMPONENT_PKG="/tmp/enputplus-component.pkg"
pkgbuild \
    --root "$PAYLOAD_DIR" \
    --filter '.DS_Store' \
    --component-plist "$COMPONENT_PLIST" \
    --scripts "$SCRIPT_DIR/pkg-scripts" \
    --identifier "com.enputplus.inputmethod.EnputPlus" \
    --version "$VERSION" \
    --install-location "/Library/Input Methods" \
    "$COMPONENT_PKG"

# Create distribution file for user-domain installation
DISTRIBUTION_FILE="/tmp/distribution.xml"
cat > "$DISTRIBUTION_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="1">
    <title>EnputPlus</title>
    <options customize="never" require-scripts="false" hostArchitectures="arm64,x86_64"/>
    <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="true"/>
    <choices-outline>
        <line choice="default"/>
    </choices-outline>
    <choice id="default" title="EnputPlus">
        <pkg-ref id="com.enputplus.inputmethod.EnputPlus"/>
    </choice>
    <pkg-ref id="com.enputplus.inputmethod.EnputPlus" version="$VERSION" onConclusion="none">enputplus-component.pkg</pkg-ref>
</installer-gui-script>
EOF

# Create final product archive with distribution
echo "Creating installer package..."
productbuild \
    --distribution "$DISTRIBUTION_FILE" \
    --package-path "/tmp" \
    --sign "$PKG_SIGNING_IDENTITY" \
    "$PKG_PATH"

echo "Verifying package signature..."
pkgutil --check-signature "$PKG_PATH"

# Notarize
echo "Submitting for notarization..."
xcrun notarytool submit "$PKG_PATH" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait

# Staple
echo "Stapling notarization ticket..."
xcrun stapler staple "$PKG_PATH"

echo ""
echo "=== PKG Created and Notarized ==="
echo "Location: $PKG_PATH"
echo ""
echo "Users will see a post-install dialog prompting them to log out/in."

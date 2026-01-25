#!/bin/bash

# EnputPlus Installation Script
# This script builds and installs EnputPlus to ~/Library/Input Methods/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
INPUT_METHODS_DIR="$HOME/Library/Input Methods"
APP_NAME="EnputPlus.app"

echo "=== EnputPlus Installation Script ==="
echo ""

# Check if Xcode command line tools are available
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode Command Line Tools."
    echo "Run: xcode-select --install"
    exit 1
fi

# Clean previous build
echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"

# Build the project
echo "Building EnputPlus..."
cd "$PROJECT_DIR"
xcodebuild -project EnputPlus.xcodeproj \
    -scheme EnputPlus \
    -configuration Debug \
    -derivedDataPath "$BUILD_DIR" \
    build

# Find the built app
BUILT_APP="$BUILD_DIR/Build/Products/Debug/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo "Error: Built app not found at $BUILT_APP"
    exit 1
fi

# Create Input Methods directory if it doesn't exist
mkdir -p "$INPUT_METHODS_DIR"

# Kill running instance if any
killall EnputPlus 2>/dev/null && echo "Stopped running EnputPlus instance" || true

# Remove existing installation
if [ -d "$INPUT_METHODS_DIR/$APP_NAME" ]; then
    echo "Removing existing installation..."
    rm -rf "$INPUT_METHODS_DIR/$APP_NAME"
fi

# Copy to Input Methods
echo "Installing to $INPUT_METHODS_DIR..."
cp -R "$BUILT_APP" "$INPUT_METHODS_DIR/"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "1. Open System Settings → Keyboard → Input Sources"
echo "2. Click + and find 'EnputPlus' under English"
echo "3. Add and switch to EnputPlus"
echo ""
echo "If EnputPlus doesn't appear, log out and log back in."
echo ""
echo "To view logs:"
echo "  log stream --predicate 'subsystem == \"com.enputplus.inputmethod.EnputPlus\"'"

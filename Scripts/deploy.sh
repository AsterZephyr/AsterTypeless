#!/bin/bash
# Deploy AsterTypeless to /Applications without breaking permissions.
# Uses rsync to only update changed files, preserving the code signature
# that macOS TCC database tracks.

set -e

APP_NAME="AsterTypeless"
BUILD_DIR="$HOME/Library/Developer/Xcode/DerivedData/AsterTypeless-gaticzxoqlfpvbdcrmttpqvacwll/Build/Products/Debug"
DEST="/Applications/$APP_NAME.app"
SIGNING_ID="Apple Development: asterzephyr@icloud.com (4SC7PZ2826)"

echo "Building..."
xcodebuild -project "$(dirname "$0")/../AsterTypeless.xcodeproj" \
  -scheme AsterTypeless build -quiet 2>&1 | tail -3

if [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
  echo "ERROR: Build output not found at $BUILD_DIR/$APP_NAME.app"
  exit 1
fi

# Quit app if running
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 1

# First deployment: full copy
if [ ! -d "$DEST" ]; then
  echo "First install: copying to /Applications..."
  cp -R "$BUILD_DIR/$APP_NAME.app" "$DEST"
  codesign --force --sign "$SIGNING_ID" --deep "$DEST"
  echo "IMPORTANT: Add $DEST to Accessibility and Input Monitoring in System Settings"
else
  echo "Updating existing installation..."
  # Use rsync to only update changed files
  rsync -a --delete "$BUILD_DIR/$APP_NAME.app/" "$DEST/"
  # Re-sign (binary changed)
  codesign --force --sign "$SIGNING_ID" --deep "$DEST"
fi

echo "Launching..."
open "$DEST"
sleep 2

# Show diagnostics
if [ -f /tmp/aster_diag.txt ]; then
  echo ""
  echo "=== Diagnostics ==="
  cat /tmp/aster_diag.txt
fi

#!/bin/bash
# Build and deploy AsterTypeless to /Applications.
# Preserves Xcode's code signature to avoid breaking TCC permissions.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="AsterTypeless"
DEST="/Applications/$APP_NAME.app"

# Find DerivedData build output
BUILD_DIR=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "AsterTypeless-*" -type d 2>/dev/null | head -1)
if [ -z "$BUILD_DIR" ]; then
  echo "ERROR: No DerivedData found. Build in Xcode first."
  exit 1
fi
BUILD_APP="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"

echo "==> Building..."
xcodebuild -project "$PROJECT_DIR/AsterTypeless.xcodeproj" \
  -scheme AsterTypeless build -quiet 2>&1

if [ ! -d "$BUILD_APP" ]; then
  echo "ERROR: Build output not found at $BUILD_APP"
  exit 1
fi

echo "==> Verifying Xcode signature..."
codesign -dvv "$BUILD_APP" 2>&1 | grep -E "Signature|Authority|TeamIdentifier"

# Quit app if running
osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 1

if [ ! -d "$DEST" ]; then
  echo "==> First install: copying to /Applications..."
  cp -R "$BUILD_APP" "$DEST"
  echo ""
  echo "IMPORTANT: First deployment. You must add $DEST to:"
  echo "  1. System Settings > Privacy & Security > Accessibility"
  echo "  2. System Settings > Privacy & Security > Input Monitoring"
  echo ""
else
  echo "==> Updating existing install (rsync, no re-sign)..."
  # rsync preserves the Xcode signature since we don't re-codesign
  rsync -a --delete "$BUILD_APP/" "$DEST/"
fi

echo "==> Launching..."
open "$DEST"

sleep 3
if [ -f /tmp/aster_diag.txt ]; then
  echo ""
  echo "=== Diagnostics ==="
  grep -E "Accessibility|Input|Microphone|AXIs|canUse|Execution" /tmp/aster_diag.txt
fi
echo ""
echo "Done."

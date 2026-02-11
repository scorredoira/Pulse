#!/bin/bash
set -e

echo "Building Pulse..."
xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=macOS' clean build 2>&1 | tail -5

echo "Stopping old instance..."
killall Pulse 2>/dev/null || true
sleep 1

APP_PATH=$(xcodebuild -project Pulse.xcodeproj -scheme Pulse -destination 'platform=macOS' -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')
echo "Launching Pulse from $APP_PATH..."
open "$APP_PATH/Pulse.app"

echo "Done!"

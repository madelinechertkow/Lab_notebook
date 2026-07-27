#!/usr/bin/env bash
# Builds Cazzy from source and assembles Cazzy.app from scratch.
#
# Cazzy.app is gitignored (Box sync metadata breaks codesign on a tracked
# copy), so a fresh clone has no app bundle at all — this script creates the
# whole thing (Contents/MacOS, Contents/Resources, Info.plist, icon) rather
# than assuming one already exists to copy the built binary into.
#
# Usage: scripts/build_app.sh [debug|release]   (default: debug)
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
APP="Cazzy.app"

echo "Building Cazzy ($CONFIG)…"
swift build -c "$CONFIG"

echo "Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/$CONFIG/Cazzy" "$APP/Contents/MacOS/Cazzy"
cp "AppIcon/Cazzy.icns" "$APP/Contents/Resources/Cazzy.icns"
cp "Packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Box sync adds extended attributes that break codesign; strip them first.
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

echo "Built $APP ($CONFIG). Run: open $APP"

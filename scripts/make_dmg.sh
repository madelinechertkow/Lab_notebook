#!/usr/bin/env bash
# Builds a release Cazzy.app and packages it into a drag-to-Applications .dmg,
# for sharing with people who don't want to build from source themselves.
#
# The result is ad-hoc signed, not notarized (that needs a paid Apple
# Developer account), so macOS Gatekeeper will flag it as being from an
# "unidentified developer" the first time someone opens it. That's expected —
# they just need to right-click (or Control-click) Cazzy.app and choose Open
# once, instead of double-clicking. See README.md for the exact wording to
# pass along.
#
# Usage: scripts/make_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)"
DMG_NAME="Cazzy-${VERSION}.dmg"

./scripts/build_app.sh release

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R Cazzy.app "$STAGING/Cazzy.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG_NAME"
hdiutil create -volname Cazzy -srcfolder "$STAGING" -ov -format UDZO "$DMG_NAME"

echo "Created $DMG_NAME — send this to whoever wants to install Cazzy."

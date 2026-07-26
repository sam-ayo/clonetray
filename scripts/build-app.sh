#!/usr/bin/env bash
# Builds build/CloneTray.app from the SwiftPM executable.
#
#   VERSION=0.2.0            version written into Info.plist
#   SIGN_IDENTITY="-"        codesign identity; "-" is ad-hoc (fine for local installs).
#                            Use a "Developer ID Application: …" identity to distribute.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.2.0}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
APP="build/CloneTray.app"

echo "==> Compiling (release)"
if swift build -c release --arch arm64 --arch x86_64 >/dev/null 2>&1; then
	BIN_PATH="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
	echo "    universal (arm64 + x86_64)"
else
	echo "    universal build unavailable, falling back to this machine's architecture"
	swift build -c release
	BIN_PATH="$(swift build -c release --show-bin-path)"
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH/CloneTray" "$APP/Contents/MacOS/CloneTray"
sed "s|__VERSION__|$VERSION|g" Resources/Info.plist >"$APP/Contents/Info.plist"
printf 'APPL????' >"$APP/Contents/PkgInfo"

if [ ! -f Resources/AppIcon.icns ]; then
	echo "==> Generating app icon"
	scripts/make-icon.sh >/dev/null || echo "    icon generation failed; continuing without one"
fi
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "==> Signing with identity: $SIGN_IDENTITY"
CODESIGN_ARGS=(--force --entitlements Resources/CloneTray.entitlements --sign "$SIGN_IDENTITY")
if [ "$SIGN_IDENTITY" = "-" ]; then
	# Ad-hoc signatures can't carry a secure timestamp, and don't need one.
	CODESIGN_ARGS+=(--timestamp=none)
else
	# Notarization requires both a secure timestamp and the hardened runtime.
	CODESIGN_ARGS+=(--timestamp --options runtime)
fi
codesign "${CODESIGN_ARGS[@]}" "$APP"
codesign --verify --verbose=1 "$APP"

echo "==> Built $APP (version $VERSION)"

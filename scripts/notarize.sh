#!/usr/bin/env bash
# Notarizes and staples a disk image.
#
# Credentials are taken from whichever of these is present, in order:
#   1. APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD  — app-specific password (used by CI)
#   2. NOTARY_PROFILE                                 — `notarytool store-credentials` profile
set -euo pipefail

DMG="${1:?usage: notarize.sh path/to/CloneTray-<version>.dmg}"
[ -f "$DMG" ] || { echo "Error: $DMG does not exist"; exit 1; }

if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ]; then
	echo "==> Notarizing as $APPLE_ID (team $APPLE_TEAM_ID)"
	CREDENTIALS=(--apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD")
elif [ -n "${NOTARY_PROFILE:-}" ]; then
	echo "==> Notarizing with keychain profile: $NOTARY_PROFILE"
	CREDENTIALS=(--keychain-profile "$NOTARY_PROFILE")
else
	cat >&2 <<-'EOS'
		Error: no notarization credentials.

		Locally, store them once:
		  xcrun notarytool store-credentials clonetray \
		    --apple-id you@example.com --team-id TEAMID --password <app-specific-password>

		In CI, set APPLE_ID, APPLE_TEAM_ID and APPLE_APP_PASSWORD.
	EOS
	exit 1
fi

xcrun notarytool submit "$DMG" "${CREDENTIALS[@]}" --wait

echo "==> Stapling the ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Verifying Gatekeeper acceptance"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "==> $DMG is notarized and stapled"

VERSION ?= 0.2.0
SIGN_IDENTITY ?= -
NOTARY_PROFILE ?= clonetray
APP := build/CloneTray.app
DMG := build/CloneTray-$(VERSION).dmg
INSTALL_DIR ?= /Applications

.PHONY: all app run install uninstall dmg notarize icon clean

all: app

## Build build/CloneTray.app
app:
	VERSION=$(VERSION) SIGN_IDENTITY="$(SIGN_IDENTITY)" scripts/build-app.sh

## Build and launch the app without installing it
run: app
	-pkill -x CloneTray || true
	open $(APP)

## Copy the app into /Applications and launch it
install: app
	@echo "==> Installing to $(INSTALL_DIR)"
	-pkill -x CloneTray || true
	rm -rf "$(INSTALL_DIR)/CloneTray.app"
	cp -R $(APP) "$(INSTALL_DIR)/CloneTray.app"
	open "$(INSTALL_DIR)/CloneTray.app"
	@echo "==> Installed. Look for the box icon in your menu bar."

## Remove the installed app (settings are left alone)
uninstall:
	-pkill -x CloneTray || true
	rm -rf "$(INSTALL_DIR)/CloneTray.app"
	@echo "==> Removed $(INSTALL_DIR)/CloneTray.app"

## Build a distributable disk image
dmg: app
	rm -f $(DMG)
	rm -rf build/dmg
	mkdir -p build/dmg
	cp -R $(APP) build/dmg/
	ln -s /Applications build/dmg/Applications
	hdiutil create -volname "CloneTray $(VERSION)" -srcfolder build/dmg -ov -format UDZO $(DMG)
	rm -rf build/dmg
	@if [ "$(SIGN_IDENTITY)" != "-" ]; then \
		echo "==> Signing $(DMG)"; \
		codesign --force --timestamp --sign "$(SIGN_IDENTITY)" $(DMG); \
	fi
	@echo "==> Built $(DMG)"
	@shasum -a 256 $(DMG)

## Notarize and staple the disk image so it opens without Gatekeeper warnings.
## Needs a Developer ID Application identity and stored notarytool credentials:
##   xcrun notarytool store-credentials $(NOTARY_PROFILE) \
##     --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
notarize: dmg
	@if [ "$(SIGN_IDENTITY)" = "-" ]; then \
		echo "Error: notarization needs a real identity, e.g."; \
		echo '  SIGN_IDENTITY="Developer ID Application: Name (TEAMID)" make notarize'; \
		exit 1; \
	fi
	NOTARY_PROFILE=$(NOTARY_PROFILE) scripts/notarize.sh $(DMG)

## Regenerate Resources/AppIcon.icns
icon:
	rm -f Resources/AppIcon.icns
	scripts/make-icon.sh

clean:
	rm -rf build .build

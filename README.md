# CloneTray

A macOS menu bar app that clones a Git repository and opens it in your editor. It
pre-fills the URL from the tab you were just looking at, so cloning what's on
screen is two clicks.

Native Swift/AppKit, no runtime dependencies beyond `git`.

## Install

**Disk image**

Download `CloneTray-<version>.dmg` from the releases page, drag CloneTray to
Applications, and launch it. The icon appears in the menu bar — the app has no
Dock icon or window.

Until the build is notarized, Gatekeeper blocks the first launch: open System
Settings → Privacy & Security and click **Open Anyway**.

**Homebrew**

```bash
brew install --cask sam-ayo/tap/clonetray
```

**From source**

```bash
make install        # builds and copies to /Applications, then launches it
```

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

## Usage

Click the menu bar icon → **Clone Repo…**. The dialog is pre-filled with the
GitHub repo from your browser's active tab, falling back to your clipboard. Deep
links are normalised, so `github.com/owner/repo/pull/12` clones
`github.com/owner/repo`. Any git URL works if you'd rather type your own.

The repo is cloned into your clone location and opened in your editor. If the
target directory already exists, `-1`, `-2`, … is appended rather than
overwriting anything.

## Settings

All under **Settings** in the menu:

| Setting | Default | Notes |
| --- | --- | --- |
| Default IDE | Cursor | Pick a preset or **Custom…** for any app name |
| Default Browser | Auto-detect | Auto-detect uses the last browser you had in front |
| Clone Location | `~/Developer` | Folder picker |

**Launch at Login** registers the app with macOS (`SMAppService`), so it starts
with your session.

Settings live in `UserDefaults` (`com.sam-ayo.clonetray`) and survive reinstalls.
A `config.yml` from the Python version is imported automatically the first time
the app runs.

## Permissions

- **Automation** — macOS asks once per browser the first time CloneTray reads its
  URL. Deny it and CloneTray falls back to the clipboard.
- **Accessibility** — only for Firefox and Zen, which expose no scripting
  dictionary for tabs; their URL is read from the address bar via the
  accessibility API. Grant it in System Settings → Privacy & Security →
  Accessibility.

Supported browsers: Chrome, Safari, Arc, Firefox, Brave, Edge, Helium, Zen.

## Development

```bash
swift build             # compile
make run                # build the .app and launch it without installing
make app                # build build/CloneTray.app (universal, ad-hoc signed)
make dmg                # build a distributable disk image (prints its sha256)
make uninstall          # remove /Applications/CloneTray.app
```

### Releasing a disk image

`make dmg` alone produces an installable image, but it is ad-hoc signed:
recipients see "Apple could not verify CloneTray is free of malware" and have to
allow it in System Settings → Privacy & Security. Fine for a teammate, not for
strangers.

For a DMG that opens on any Mac with no warning you need a **Developer ID
Application** certificate — not Apple Development (local only) or Apple
Distribution (App Store only). Create one in the Apple Developer portal
(Certificates → `+` → Developer ID Application), download it, and double-click
to add it to your keychain. Then store notarization credentials once:

```bash
xcrun notarytool store-credentials clonetray \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

The password is an app-specific password from appleid.apple.com, not your Apple
ID password. After that, each release is one command:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make notarize
```

That signs the app with the hardened runtime and a secure timestamp, builds and
signs the DMG, submits it to Apple, waits for the result, staples the ticket, and
verifies the result with `spctl`. Upload the stapled `build/CloneTray-<version>.dmg`
to a GitHub release, then update `Casks/clonetray.rb` with the version and the
`sha256` printed for that exact file — `hdiutil` output is not reproducible, so
re-running `make dmg` changes the checksum.

Layout:

| Path | Contents |
| --- | --- |
| `Sources/CloneTray` | App source: menu, settings, git, URL detection |
| `Resources` | `Info.plist`, entitlements, generated app icon |
| `scripts` | Bundle assembly (`build-app.sh`) and icon generation |
| `Casks` | Homebrew cask |
| `legacy` | The original Python/rumps implementation, kept for reference |

`CloneTray --dump-menu` prints the menu tree and exits — a quick smoke test that
the app launches and reads its settings.

## License

MIT

# Building and releasing CloneTray

## Development

```bash
swift build             # compile
make run                # build the .app and launch it without installing
make app                # build build/CloneTray.app (universal, ad-hoc signed)
make install            # copy to /Applications and launch
make dmg                # build a disk image (prints its sha256)
make uninstall          # remove /Applications/CloneTray.app
```

Requires macOS 13+ and the Xcode Command Line Tools.

For the tightest loop, run the bundle's binary directly — `open` swallows stderr,
where the `[CloneTray]` log lines go:

```bash
build/CloneTray.app/Contents/MacOS/CloneTray             # ^C to quit
build/CloneTray.app/Contents/MacOS/CloneTray --dump-menu # smoke test: print menu, exit
```

Run it from inside the bundle so it picks up `Contents/Info.plist` — that's what
provides `LSUIElement` (no Dock icon) and the bundle identifier that
`UserDefaults`, notifications, and `SMAppService` key off. Xcode's Run button
launches the bare executable instead, so behaviour diverges from a real install.

Note that ad-hoc signing produces a new code signature on every build, and macOS
ties Automation/Accessibility grants to the signature — so those prompts
reappear while iterating.

## Signing

`make app` signs ad-hoc, which is enough to run locally. Distributing to other
people needs a **Developer ID Application** certificate — not Apple Development
(local only) or Apple Distribution (App Store only). Create one in Xcode →
Settings → Accounts → Manage Certificates → `+`, or in the Apple Developer
portal. Only the Account Holder can issue them.

```bash
security find-identity -v -p codesigning   # confirm it's in the keychain
```

Given a real identity the build switches to a secure timestamp and the hardened
runtime, both required for notarization.

## Releasing by hand

Store notarization credentials once:

```bash
xcrun notarytool store-credentials clonetray \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

That password is an app-specific password from appleid.apple.com, not your Apple
ID password. Then:

```bash
VERSION=0.2.0 SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make notarize
```

This signs the app, builds and signs the DMG, submits it to Apple, waits,
staples the ticket, and verifies with `spctl`. Stapling matters: without it
Gatekeeper has to reach Apple's servers on first launch. If Apple rejects the
submission, `xcrun notarytool log <submission-id> --keychain-profile clonetray`
says exactly why.

Verify the result the way someone else's Mac will see it — ideally on a machine
that never built the app, since Gatekeeper caches per-user:

```bash
xcrun stapler validate build/CloneTray-0.2.0.dmg
spctl -a -t open --context context:primary-signature -vv build/CloneTray-0.2.0.dmg
```

## Releasing from CI

`.github/workflows/release.yml` does all of the above on a tag:

```bash
git tag v0.3.0 && git push origin v0.3.0
```

It imports the certificate into a throwaway keychain, runs the same
`make notarize` used locally, publishes a GitHub release with both
`CloneTray-<version>.dmg` and a stable-named `CloneTray.dmg`, then opens a PR
against [samayo.me](https://github.com/sam-ayo/me) bumping the version shown on
the projects page. It can also be run from the Actions tab with an explicit
version.

Required repository secrets:

| Secret | What it is |
| --- | --- |
| `MACOS_CERTIFICATE` | Developer ID Application cert + key as base64 `.p12` |
| `MACOS_CERTIFICATE_PWD` | Password set when exporting the `.p12` |
| `MACOS_SIGN_IDENTITY` | `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_TEAM_ID` | Your 10-character team ID |
| `APPLE_APP_PASSWORD` | App-specific password from appleid.apple.com |
| `SITE_REPO_TOKEN` | PAT with contents + pull-request write on `sam-ayo/me` |

Export the certificate from Keychain Access (right-click the *Developer ID
Application* entry → Export, as `.p12`), then:

```bash
base64 -i Certificates.p12 | pbcopy   # paste as MACOS_CERTIFICATE
```

`SITE_REPO_TOKEN` is optional — without it the release still publishes and the
website job is skipped.

The website job edits `src/data/releases.json` in `sam-ayo/me`, so that file has
to exist on `main` there before the first tagged release.

## Homebrew

`Casks/clonetray.rb` is ready but has no tap yet. To publish one:

```bash
gh repo create sam-ayo/homebrew-tap --public --clone
# copy Casks/clonetray.rb in, set sha256 from the stapled DMG, push
brew install --cask sam-ayo/tap/clonetray
```

Take the checksum from the stapled DMG — stapling rewrites the file, and
`hdiutil` output isn't reproducible, so any earlier checksum is stale.

## What users need to know

CloneTray asks for two permissions, both only when first needed:

- **Automation** — to read the URL of the frontmost tab. Denying it falls back to
  the clipboard.
- **Accessibility** — only for Firefox and Zen, which expose no scripting
  dictionary for tabs; their URL is read from the address bar.

Supported browsers: Chrome, Safari, Arc, Firefox, Brave, Edge, Helium, Zen.

Settings live in `UserDefaults` (`com.sam-ayo.clonetray`) and survive
reinstalls; a `config.yml` from the old Python version is imported once on first
launch.

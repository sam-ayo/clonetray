import AppKit

/// A browser we know how to read the frontmost URL from.
struct Browser {
    let name: String
    let bundleIdentifiers: [String]
    /// AppleScript that returns the URL of the active tab as text.
    let script: String
}

enum Browsers {
    static let all: [Browser] = [
        Browser(
            name: "Google Chrome",
            bundleIdentifiers: ["com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary"],
            script: #"tell application "Google Chrome" to get URL of active tab of front window"#
        ),
        Browser(
            name: "Safari",
            bundleIdentifiers: ["com.apple.Safari", "com.apple.SafariTechnologyPreview"],
            script: #"tell application "Safari" to get URL of front document"#
        ),
        Browser(
            name: "Arc",
            bundleIdentifiers: ["company.thebrowser.Browser"],
            script: #"tell application "Arc" to get URL of active tab of front window"#
        ),
        Browser(
            name: "Firefox",
            bundleIdentifiers: ["org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition"],
            script: Browsers.firefoxLikeScript(processName: "firefox")
        ),
        Browser(
            name: "Brave Browser",
            bundleIdentifiers: ["com.brave.Browser", "com.brave.Browser.beta"],
            script: #"tell application "Brave Browser" to get URL of active tab of front window"#
        ),
        Browser(
            name: "Microsoft Edge",
            bundleIdentifiers: ["com.microsoft.edgemac", "com.microsoft.edgemac.Beta"],
            script: #"tell application "Microsoft Edge" to get URL of active tab of front window"#
        ),
        Browser(
            name: "Helium",
            bundleIdentifiers: ["net.imput.helium", "com.helium.helium"],
            script: #"tell application "Helium" to get URL of active tab of front window"#
        ),
        Browser(
            name: "zen",
            bundleIdentifiers: ["app.zen-browser.zen"],
            script: Browsers.firefoxLikeScript(processName: "zen")
        ),
    ]

    static func named(_ name: String) -> Browser? {
        all.first { $0.name == name }
    }

    static func matching(_ app: NSRunningApplication) -> Browser? {
        if let bundleID = app.bundleIdentifier,
           let match = all.first(where: { $0.bundleIdentifiers.contains(bundleID) }) {
            return match
        }
        guard let localizedName = app.localizedName else { return nil }
        return all.first { $0.name.caseInsensitiveCompare(localizedName) == .orderedSame }
    }

    /// Firefox-derived browsers expose no scripting dictionary for tabs, so read the
    /// address bar over the accessibility API and fall back to ⌘L / ⌘C + clipboard.
    private static func firefoxLikeScript(processName: String) -> String {
        """
        tell application "System Events"
          tell process "\(processName)"
            set frontmost to true
            try
              return value of attribute "AXValue" of text field 1 of combo box 1 of toolbar "Navigation" of UI element 1 of front window
            on error
              try
                return value of attribute "AXValue" of text field 1 of combo box 1 of toolbar 1 of front window
              on error
                keystroke "l" using {command down}
                keystroke "c" using {command down}
                key code 53
                delay 0.05
                return the clipboard
              end try
            end try
          end tell
        end tell
        """
    }
}

enum IDEs {
    static let presets = [
        "Cursor",
        "Visual Studio Code",
        "Zed",
        "Zed Preview",
        "Zed Nightly",
        "Sublime Text",
        "Xcode",
        "PyCharm",
        "IntelliJ IDEA",
        "WebStorm",
    ]
}

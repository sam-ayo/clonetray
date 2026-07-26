import AppKit

/// Remembers the last browser that was frontmost. Clicking a status-bar menu can make
/// CloneTray the active app, so asking "who is frontmost?" at click time is unreliable.
final class FrontmostBrowserTracker {
    private(set) var lastBrowser: Browser?

    func start() {
        if let current = NSWorkspace.shared.frontmostApplication, let browser = Browsers.matching(current) {
            lastBrowser = browser
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func applicationActivated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let browser = Browsers.matching(app)
        else { return }
        lastBrowser = browser
    }
}

enum URLDetector {
    /// Best guess at the repo the user is looking at: configured browser, else the last
    /// active browser, else the clipboard.
    static func detectGitHubRepo(settings: Settings, tracker: FrontmostBrowserTracker) -> String? {
        let browser = settings.defaultBrowser.flatMap(Browsers.named) ?? tracker.lastBrowser
        if let browser {
            Log.info("Reading URL from \(browser.name)")
            if let raw = runAppleScript(browser.script) {
                if let repo = RepoURL.gitHubRepo(in: raw) {
                    Log.info("Detected \(repo) in \(browser.name)")
                    return repo
                }
                Log.info("URL from \(browser.name) is not a GitHub repo: \(raw)")
            }
        }

        if let clipboard = NSPasteboard.general.string(forType: .string),
           let repo = RepoURL.gitHubRepo(in: clipboard) {
            Log.info("Detected \(repo) in the clipboard")
            return repo
        }

        Log.info("No GitHub URL detected")
        return nil
    }

    @discardableResult
    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            Log.info("AppleScript failed: \(error)")
            return nil
        }
        return result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum IDELauncher {
    /// Opens `directory` in the configured editor, resolving the app by name.
    static func open(directory: URL, appName: String, completion: @escaping (Error?) -> Void) {
        guard let appURL = applicationURL(named: appName) else {
            completion(NSError(
                domain: "CloneTray",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Could not find an application named “\(appName)”."]
            ))
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([directory], withApplicationAt: appURL, configuration: configuration) { _, error in
            completion(error)
        }
    }

    private static func applicationURL(named appName: String) -> URL? {
        let name = appName.hasSuffix(".app") ? appName : "\(appName).app"
        let searchPaths = [
            "/Applications",
            "\(NSHomeDirectory())/Applications",
            "/System/Applications",
            "/Applications/Utilities",
        ]
        for path in searchPaths {
            let candidate = URL(fileURLWithPath: path).appending(path: name)
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        // Fall back to Launch Services, which also finds apps in unusual locations.
        return NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: appName
        )
    }
}

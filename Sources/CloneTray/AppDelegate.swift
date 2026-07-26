import AppKit
import ServiceManagement
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let browserTracker = FrontmostBrowserTracker()
    private var statusItem: NSStatusItem!
    private var isCloning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "shippingbox", accessibilityDescription: "CloneTray")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        browserTracker.start()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // Smoke test hook: build the menu, print it, and exit.
        if CommandLine.arguments.contains("--dump-menu") {
            menuNeedsUpdate(menu)
            print(describe(menu: menu))
            NSApp.terminate(nil)
        }
    }

    private func describe(menu: NSMenu, indent: String = "") -> String {
        menu.items.map { item -> String in
            let mark = item.state == .on ? "• " : ""
            let line = item.isSeparatorItem ? "\(indent)---" : "\(indent)\(mark)\(item.title)"
            guard let submenu = item.submenu else { return line }
            return line + "\n" + describe(menu: submenu, indent: indent + "  ")
        }
        .joined(separator: "\n")
    }

    // MARK: - Menu

    // Rebuilt on every open so checkmarks and paths always reflect current settings.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let clone = NSMenuItem(
            title: isCloning ? "Cloning…" : "Clone Repo…",
            action: isCloning ? nil : #selector(cloneRepo),
            keyEquivalent: ""
        )
        clone.target = self
        menu.addItem(clone)

        menu.addItem(.separator())
        menu.addItem(settingsItem())

        let launchAtLogin = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLogin.target = self
        launchAtLogin.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLogin)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit CloneTray", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func settingsItem() -> NSMenuItem {
        let settingsMenu = NSMenu()

        let ideItem = NSMenuItem(title: "Default IDE", action: nil, keyEquivalent: "")
        ideItem.submenu = ideMenu()
        settingsMenu.addItem(ideItem)

        let browserItem = NSMenuItem(title: "Default Browser", action: nil, keyEquivalent: "")
        browserItem.submenu = browserMenu()
        settingsMenu.addItem(browserItem)

        settingsMenu.addItem(.separator())
        let location = NSMenuItem(
            title: "Clone Location: \(abbreviatedCloneLocation())",
            action: #selector(chooseCloneLocation),
            keyEquivalent: ""
        )
        location.target = self
        settingsMenu.addItem(location)

        let item = NSMenuItem(title: "Settings", action: nil, keyEquivalent: "")
        item.submenu = settingsMenu
        return item
    }

    private func ideMenu() -> NSMenu {
        let menu = NSMenu()
        var names = IDEs.presets
        if !names.contains(settings.ideAppName) {
            names.append(settings.ideAppName)
        }
        for name in names {
            let item = NSMenuItem(title: name, action: #selector(selectIDE(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = name
            item.state = name == settings.ideAppName ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let custom = NSMenuItem(title: "Custom…", action: #selector(setCustomIDE), keyEquivalent: "")
        custom.target = self
        menu.addItem(custom)
        return menu
    }

    private func browserMenu() -> NSMenu {
        let menu = NSMenu()
        let auto = NSMenuItem(title: "Auto-detect", action: #selector(selectBrowser(_:)), keyEquivalent: "")
        auto.target = self
        auto.representedObject = nil
        auto.state = settings.defaultBrowser == nil ? .on : .off
        menu.addItem(auto)
        menu.addItem(.separator())
        for browser in Browsers.all {
            let item = NSMenuItem(title: browser.name, action: #selector(selectBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser.name
            item.state = browser.name == settings.defaultBrowser ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func abbreviatedCloneLocation() -> String {
        let path = settings.cloneBaseDirectory.path
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    // MARK: - Actions

    @objc private func selectIDE(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        settings.ideAppName = name
        Log.info("Default IDE set to \(name)")
    }

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        let name = sender.representedObject as? String
        settings.defaultBrowser = name
        Log.info("Default browser set to \(name ?? "Auto-detect")")
    }

    @objc private func setCustomIDE() {
        guard let name = promptForText(
            title: "Set Default IDE",
            message: "Enter the application name as it appears in /Applications:",
            prefill: settings.ideAppName,
            okTitle: "Save"
        ) else { return }
        settings.ideAppName = name
        Log.info("Default IDE set to \(name)")
    }

    @objc private func chooseCloneLocation() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message = "Where should repositories be cloned?"
        panel.directoryURL = settings.cloneBaseDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.cloneBaseDirectory = url
        Log.info("Clone location set to \(url.path)")
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                Log.info("Launch at login disabled")
            } else {
                try SMAppService.mainApp.register()
                Log.info("Launch at login enabled")
            }
        } catch {
            presentError("Could not change the Launch at Login setting.", detail: error.localizedDescription)
        }
    }

    @objc private func cloneRepo() {
        let detected = URLDetector.detectGitHubRepo(settings: settings, tracker: browserTracker)
        guard let repoURL = promptForText(
            title: "Clone Git Repository",
            message: "Enter git repository URL:",
            prefill: detected ?? "",
            okTitle: "Clone"
        ) else { return }

        let destination = RepoURL.destination(for: repoURL, in: settings.cloneBaseDirectory)
        let ideAppName = settings.ideAppName
        isCloning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try Git.clone(repoURL: repoURL, into: destination)
                DispatchQueue.main.async {
                    self?.isCloning = false
                    self?.notify(title: "Clone Success", body: destination.path)
                    IDELauncher.open(directory: destination, appName: ideAppName) { error in
                        if let error {
                            self?.presentError("Could not open \(ideAppName).", detail: error.localizedDescription)
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.isCloning = false
                    self?.presentError("Clone failed.", detail: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - UI helpers

    /// Returns the trimmed text, or nil if the user cancelled or left it empty.
    private func promptForText(title: String, message: String, prefill: String, okTitle: String) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: okTitle)
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.stringValue = prefill
        field.placeholderString = "https://github.com/owner/repo"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func presentError(_ message: String, detail: String) {
        Log.info("\(message) \(detail)")
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

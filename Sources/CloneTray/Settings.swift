import Foundation

/// User preferences, stored in the app's `UserDefaults`. Settings changed from the
/// menu persist there, so reinstalling the app never wipes them.
final class Settings {
    static let shared = Settings()

    private enum Key {
        static let cloneBaseDir = "cloneBaseDir"
        static let ideAppName = "ideAppName"
        static let defaultBrowser = "defaultBrowser"
        static let didMigrateLegacyConfig = "didMigrateLegacyConfig"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacyConfigIfNeeded()
    }

    var cloneBaseDirectory: URL {
        get {
            if let path = defaults.string(forKey: Key.cloneBaseDir), !path.isEmpty {
                return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appending(path: "Developer")
        }
        set { defaults.set(newValue.path, forKey: Key.cloneBaseDir) }
    }

    var ideAppName: String {
        get { defaults.string(forKey: Key.ideAppName) ?? "Cursor" }
        set { defaults.set(newValue, forKey: Key.ideAppName) }
    }

    /// `nil` means auto-detect the frontmost browser.
    var defaultBrowser: String? {
        get {
            guard let name = defaults.string(forKey: Key.defaultBrowser), !name.isEmpty else { return nil }
            return name
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.defaultBrowser)
            } else {
                defaults.removeObject(forKey: Key.defaultBrowser)
            }
        }
    }

    /// One-time import of the config.yml written by the previous Python version.
    private func migrateLegacyConfigIfNeeded() {
        guard !defaults.bool(forKey: Key.didMigrateLegacyConfig) else { return }
        defer { defaults.set(true, forKey: Key.didMigrateLegacyConfig) }

        let configDir = ProcessInfo.processInfo.environment["CLONETRAY_CONFIG_DIR"]
            .map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support/CloneTray")
        let legacyFile = configDir.appending(path: "config.yml")
        guard let contents = try? String(contentsOf: legacyFile, encoding: .utf8) else { return }

        for line in contents.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[trimmed.startIndex..<separator]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
            value = value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            guard !value.isEmpty else { continue }

            switch key {
            case "default_clone_base_dir":
                cloneBaseDirectory = URL(fileURLWithPath: (value as NSString).expandingTildeInPath)
            case "ide_app_name":
                ideAppName = value
            case "default_browser":
                defaultBrowser = value
            default:
                break
            }
        }
        Log.info("Imported settings from legacy config at \(legacyFile.path)")
    }
}

enum Log {
    static func info(_ message: String) {
        FileHandle.standardError.write(Data("[CloneTray] \(message)\n".utf8))
    }
}

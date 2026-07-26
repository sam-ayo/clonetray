import Foundation

enum GitError: LocalizedError {
    case gitNotFound
    case cloneFailed(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return "Could not find git. Install the Xcode Command Line Tools with `xcode-select --install`."
        case let .cloneFailed(status, output):
            let detail = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "git clone failed (exit code \(status))." : detail
        }
    }
}

enum Git {
    /// Launched from Finder we inherit almost no PATH, so resolve git ourselves.
    private static let candidatePaths = [
        "/usr/bin/git",
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git",
    ]

    private static var executable: URL? {
        candidatePaths
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(fileURLWithPath: $0) }
    }

    /// Clones `repoURL` into `destination`. Blocking — call off the main thread.
    static func clone(repoURL: String, into destination: URL) throws {
        guard let executable else { throw GitError.gitNotFound }

        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let process = Process()
        process.executableURL = executable
        process.arguments = ["clone", "--progress", repoURL, destination.path]
        // Never let git stop for credentials: there is no terminal to answer in.
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_ASKPASS"] = environment["GIT_ASKPASS"] ?? "/usr/bin/true"
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        Log.info("git clone \(repoURL) -> \(destination.path)\n\(output)")

        guard process.terminationStatus == 0 else {
            throw GitError.cloneFailed(status: process.terminationStatus, output: output)
        }
    }
}

import Foundation

enum RepoURL {
    /// Matches a GitHub repo URL anywhere in a blob of text, e.g. the deep link
    /// `https://github.com/owner/repo/pull/12` yields `https://github.com/owner/repo`.
    private static let gitHubPattern = try! NSRegularExpression(
        pattern: #"https?://(?:www\.)?github\.com/([\w.-]+)/([\w.-]+)"#,
        options: .caseInsensitive
    )

    /// Extracts a clonable GitHub URL from arbitrary text (a browser URL or the clipboard).
    static func gitHubRepo(in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = gitHubPattern.firstMatch(in: text, range: range),
              let ownerRange = Range(match.range(at: 1), in: text),
              let repoRange = Range(match.range(at: 2), in: text)
        else { return nil }

        var repo = String(text[repoRange])
        if repo.hasSuffix(".git") { repo.removeLast(4) }
        guard !repo.isEmpty else { return nil }
        return "https://github.com/\(text[ownerRange])/\(repo)"
    }

    /// Repo name for both `https://host/owner/repo.git` and `git@host:owner/repo.git`.
    static func directoryName(for repoURL: String) -> String {
        var trimmed = repoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        var name = trimmed
            .split(whereSeparator: { $0 == "/" || $0 == ":" })
            .last
            .map(String.init) ?? trimmed
        if name.hasSuffix(".git") { name.removeLast(4) }
        return name.isEmpty ? "repository" : name
    }

    /// First unused path under `baseDirectory`: `repo`, then `repo-1`, `repo-2`, ...
    static func destination(for repoURL: String, in baseDirectory: URL) -> URL {
        let name = directoryName(for: repoURL)
        var candidate = baseDirectory.appending(path: name)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = baseDirectory.appending(path: "\(name)-\(counter)")
            counter += 1
        }
        return candidate
    }
}

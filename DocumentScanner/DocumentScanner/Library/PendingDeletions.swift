import Foundation

/// Documents and folders the user has just deleted, which the iCloud store keeps out
/// of `summaries` until its `NSMetadataQuery` catches up (about 5 seconds).
///
/// Without it, a deleted row lingers until the query notices; and a query update that
/// was already in flight when the user deleted would put the row back for a moment.
///
/// Two things stop an entry from hiding something it shouldn't:
/// - A row is hidden only while no file exists at its path. The delete removes the
///   file at once (only the query is slow), so a document re-created under the same
///   name, say the same PDF imported again, shows up immediately.
/// - An entry is dropped once the query no longer lists anything at or under it, or
///   after `lifetime`, whichever comes first.
struct PendingDeletions {
    static let lifetime: TimeInterval = 60

    private var deletedAt: [String: Date] = [:]

    mutating func add(_ url: URL, at date: Date = Date()) {
        deletedAt[Self.path(of: url)] = date
    }

    /// True when `url` is a deleted document, or anything inside a deleted folder.
    func covers(_ url: URL) -> Bool {
        let candidate = Self.path(of: url)
        return deletedAt.keys.contains { Self.isAtOrInside(candidate, $0) }
    }

    func filter(_ summaries: [DocumentSummary],
                exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> [DocumentSummary] {
        guard !deletedAt.isEmpty else { return summaries }
        return summaries.filter { !covers($0.url) || exists($0.url) }
    }

    mutating func prune(keepingThoseStillIn queryURLs: [URL], now: Date = Date()) {
        guard !deletedAt.isEmpty else { return }
        let listed = queryURLs.map(Self.path(of:))
        deletedAt = deletedAt.filter { deleted, date in
            now.timeIntervalSince(date) < Self.lifetime
                && listed.contains { Self.isAtOrInside($0, deleted) }
        }
    }

    /// `child` is `parent` itself or lies under it. "Receipts 2" is not inside "Receipts".
    static func isAtOrInside(_ child: String, _ parent: String) -> Bool {
        child == parent || child.hasPrefix(parent + "/")
    }

    /// Comparable form of a file URL: symlinks resolved (iCloud paths can arrive as
    /// /var or /private/var), no trailing slash on folders.
    static func path(of url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}

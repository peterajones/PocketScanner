import Foundation

/// A place a document can be moved to: either the root library or a folder.
struct MoveDestination: Identifiable, Hashable {
    /// The destination *directory* URL (root documents dir or a folder).
    let url: URL
    /// Display label ("Main Library" for root, folder name otherwise).
    let name: String
    var id: URL { url }
}

/// Pure logic for building the "Move to…" destination list. Kept free of
/// SwiftUI so it can be unit-tested directly.
enum MoveDestinations {
    /// Destinations for a document currently living in `currentParent`.
    ///
    /// - "Main Library" (the root) is included only when the doc isn't already
    ///   at root.
    /// - Every folder is included except the one the doc is already in.
    /// - Comparison uses `standardizedFileURL.path`, matching how folder paths
    ///   are compared elsewhere in the library views (and tolerant of trailing-
    ///   slash / `isDirectory` differences).
    static func list(currentParent: URL, root: URL, folders: [URL]) -> [MoveDestination] {
        let currentPath = currentParent.standardizedFileURL.path
        var result: [MoveDestination] = []
        if root.standardizedFileURL.path != currentPath {
            result.append(MoveDestination(url: root, name: "Main Library"))
        }
        for folder in folders where folder.standardizedFileURL.path != currentPath {
            result.append(MoveDestination(url: folder, name: folder.lastPathComponent))
        }
        return result
    }
}

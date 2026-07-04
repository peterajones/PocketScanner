import Foundation

/// Pure helpers for reasoning about a folder's position under the documents root.
/// Levels are array indices from the root: root = 0, top-level folder = 1,
/// sub-folder = 2. The app caps folder creation at level 2 in the UI.
enum FolderPaths {
    /// Number of path components between `root` and `url` (0 when they're equal).
    static func level(of url: URL, root: URL) -> Int {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        return max(0, urlComponents.count - rootComponents.count)
    }

    /// Display label: "Main Library" for root, the folder name for a top-level
    /// folder, and "Parent ▸ Name" for a sub-folder.
    static func label(for url: URL, root: URL) -> String {
        switch level(of: url, root: root) {
        case 0:
            return "Main Library"
        case 1:
            return url.lastPathComponent
        default:
            let parent = url.deletingLastPathComponent().lastPathComponent
            return "\(parent) ▸ \(url.lastPathComponent)"
        }
    }
}

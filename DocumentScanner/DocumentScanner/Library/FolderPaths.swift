import Foundation

/// Pure helpers for reasoning about a folder's position under the documents root.
/// Levels are array indices from the root: root = 0, top-level folder = 1,
/// sub-folder = 2, and so on.
enum FolderPaths {

    /// Deepest folder level the UI allows, e.g. `Tax Slips/2006/T4` at 3.
    ///
    /// This is the single source of truth for the cap. It used to be a bare `< 2` in
    /// the create-folder gate, with the same depth separately hardcoded into two
    /// folder-walk loops — so a folder could be created that the Move menu would never
    /// list. Anything that enumerates or gates folders reads this.
    ///
    /// Raise it if a deeper level is wanted; if it needs raising again, that is the
    /// signal to make folder walking properly recursive and delete this constant.
    static let maxDepth = 3

    /// Number of path components between `root` and `url` (0 when they're equal).
    static func level(of url: URL, root: URL) -> Int {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        return max(0, urlComponents.count - rootComponents.count)
    }

    /// Display label: "Main Library" for root, otherwise every component below the
    /// root joined with " ▸ " — `Tax Slips`, `Tax Slips ▸ 2006`, `Tax Slips ▸ 2006 ▸ T4`.
    ///
    /// This produces output identical to the previous "Parent ▸ Name" form at levels 1
    /// and 2, so nothing shallower changes. It matters from level 3, where showing only
    /// the parent would render `Tax Slips/2006/T4` and `Receipts/2006/T4` identically as
    /// "2006 ▸ T4" — two different destinations, indistinguishable in the Move menu.
    ///
    /// Passing a non-root `root` yields a label relative to it, which is how the Save-to
    /// menu names entries within a folder's own submenu.
    static func label(for url: URL, root: URL) -> String {
        let rootCount = root.standardizedFileURL.pathComponents.count
        let components = url.standardizedFileURL.pathComponents.dropFirst(rootCount)
        guard !components.isEmpty else { return "Main Library" }
        return components.joined(separator: " ▸ ")
    }
}

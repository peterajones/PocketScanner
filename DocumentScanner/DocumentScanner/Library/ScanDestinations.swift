import Foundation

/// One selectable place a scan can be saved (root, a folder, or a sub-folder).
struct ScanDestination: Identifiable, Hashable {
    let url: URL
    let name: String
    var id: URL { url }
}

/// A top-level folder plus its sub-folders, for the nested "Save to" menu.
struct ScanDestinationGroup: Identifiable {
    let folder: ScanDestination
    let subfolders: [ScanDestination]
    var id: URL { folder.url }
}

/// Pure builder for the Save-sheet destination menu. SwiftUI-free so it's unit-tested.
enum ScanDestinations {
    static func build(
        root: URL,
        folders: [URL],
        subfoldersByFolder: [URL: [URL]]
    ) -> (main: ScanDestination, groups: [ScanDestinationGroup]) {
        let main = ScanDestination(url: root, name: FolderPaths.label(for: root, root: root))
        let groups = folders.map { folder -> ScanDestinationGroup in
            // Name each entry RELATIVE to its group folder, so a level-3 folder reads
            // "2006 ▸ T4" inside the "Tax Slips" submenu rather than a bare "T4" that
            // could belong to any year. For direct children this is just the folder
            // name, matching the previous behaviour exactly.
            let subs = (subfoldersByFolder[folder] ?? []).map {
                ScanDestination(url: $0, name: FolderPaths.label(for: $0, root: folder))
            }
            return ScanDestinationGroup(
                folder: ScanDestination(url: folder, name: folder.lastPathComponent),
                subfolders: subs
            )
        }
        return (main, groups)
    }
}

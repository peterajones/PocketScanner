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
            let subs = (subfoldersByFolder[folder] ?? []).map {
                ScanDestination(url: $0, name: $0.lastPathComponent)
            }
            return ScanDestinationGroup(
                folder: ScanDestination(url: folder, name: folder.lastPathComponent),
                subfolders: subs
            )
        }
        return (main, groups)
    }
}

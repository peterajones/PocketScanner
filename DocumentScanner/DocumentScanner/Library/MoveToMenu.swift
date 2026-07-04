import SwiftUI

/// A "Move to…" submenu for a document's context menu. Lists the valid
/// destinations (root + folders, current location excluded) and calls `move`
/// with the chosen destination directory URL. Renders nothing when there are
/// no destinations, so callers can place it unconditionally.
struct MoveToMenu: View {
    /// The document's current containing directory.
    let currentParent: URL
    /// The root documents directory (`storage.documentsURL`).
    let root: URL
    /// All move-destination folders (top-level and sub-folders).
    let folders: [URL]
    /// Invoked with the chosen destination directory URL.
    let move: (URL) -> Void

    var body: some View {
        let destinations = MoveDestinations.list(
            currentParent: currentParent, root: root, folders: folders
        )
        if !destinations.isEmpty {
            Menu {
                ForEach(destinations) { dest in
                    Button(dest.name) { move(dest.url) }
                }
            } label: {
                Label("Move to…", systemImage: "folder")
            }
        }
    }
}

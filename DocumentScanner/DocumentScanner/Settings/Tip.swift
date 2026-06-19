import Foundation

/// A single in-app tip shown on the Tips screen. Pure content (no UI), so the
/// copy is unit-testable and new tips are added by appending to `all`.
struct Tip: Identifiable {
    let id: String
    let title: String
    let body: String
}

extension Tip {
    /// Tips in display order: everyday tricks first, the highlights caveat last.
    static let all: [Tip] = [
        Tip(id: "search",
            title: "Search inside your scans",
            body: "Search reads the text inside every scan, even ones filed in folders. Tap a result to jump straight to the highlighted match."),
        Tip(id: "swipe-delete",
            title: "Swipe to delete",
            body: "Swipe left on any document or folder to remove it."),
        Tip(id: "grid",
            title: "See your scans as thumbnails",
            body: "Tap the layout button in the toolbar to switch between a list and a thumbnail grid of your library."),
        Tip(id: "extract",
            title: "Split out pages",
            body: "In a document’s edit mode, select pages and tap Save as New to pull them into their own scan."),
        Tip(id: "flat-list",
            title: "One big list",
            body: "Prefer everything in one place? Turn off Show Folders in Settings and every scan lives in a single list."),
        Tip(id: "highlights",
            title: "Highlights & handwriting",
            body: "Highlights snap to the text Pocket Scanner detects in your scan. On printed pages that’s precise; on handwriting or rough scans, text detection is looser — so a highlight may sit a bit tall or not line up exactly. Your scan itself is never altered."),
    ]
}

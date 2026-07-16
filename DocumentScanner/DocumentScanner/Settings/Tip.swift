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
            title: String(localized: "Search inside your scans", comment: "Tip title"),
            body: String(localized: "Search reads the text inside every scan, even ones filed in folders. Tap a result to jump straight to the highlighted match.", comment: "Tip body")),
        Tip(id: "swipe-delete",
            title: String(localized: "Swipe to delete", comment: "Tip title"),
            body: String(localized: "Swipe left on any document or folder to remove it.", comment: "Tip body")),
        Tip(id: "grid",
            title: String(localized: "See your scans as thumbnails", comment: "Tip title"),
            body: String(localized: "Tap the layout button in the toolbar to switch between a list and a thumbnail grid of your library.", comment: "Tip body")),
        Tip(id: "extract",
            title: String(localized: "Split out pages", comment: "Tip title"),
            body: String(localized: "In a document’s edit mode, select pages and tap Save as New to pull them into their own scan.", comment: "Tip body")),
        Tip(id: "signature",
            title: String(localized: "Sign with your signature", comment: "Tip title"),
            body: String(localized: "Scan your signature once in Settings, then tap Sign to drop it on any page — move or resize it to fit. For the cleanest cut-out, sign a plain sheet with a bold pen; if the camera can’t find the page edges up close, take a photo instead and crop it.", comment: "Tip body")),
        Tip(id: "flat-list",
            title: String(localized: "One big list", comment: "Tip title"),
            body: String(localized: "Prefer everything in one place? Turn off Show Folders in Settings and every scan lives in a single list.", comment: "Tip body")),
        Tip(id: "highlights",
            title: String(localized: "Highlights & handwriting", comment: "Tip title"),
            body: String(localized: "Highlights snap to the text Pocket Scanner detects in your scan. On printed pages that’s precise; on handwriting or rough scans, text detection is looser — so a highlight may sit a bit tall or not line up exactly. Your scan itself is never altered.", comment: "Tip body")),
    ]
}

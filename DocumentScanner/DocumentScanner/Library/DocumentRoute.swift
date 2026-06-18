import Foundation

/// Navigation value pushed when a document is tapped. Carries the originating
/// screen's active search term and scope so the viewer's `SearchContext` is
/// built correctly regardless of which screen pushed it. Lives in the in-memory
/// `NavigationPath`, so `Hashable` is sufficient (no Codable/state restoration).
struct DocumentRoute: Hashable {
    let summary: DocumentSummary
    let term: String
    let scope: SearchScope
}

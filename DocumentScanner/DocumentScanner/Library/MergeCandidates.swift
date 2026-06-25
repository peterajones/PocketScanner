import Foundation

/// Pure logic for the "Merge into…" target list: every document a given source
/// may be merged into. Kept free of SwiftUI so it can be unit-tested directly
/// (like `MoveDestinations`).
enum MergeCandidates {
    /// Targets for `source` drawn from `all` (the full library list): every
    /// document except the source itself and any corrupt document. Order is
    /// preserved from `all` so the menu matches the library's current order.
    static func list(source: DocumentSummary, all: [DocumentSummary]) -> [DocumentSummary] {
        all.filter { $0.url != source.url && !$0.isCorrupt }
    }
}

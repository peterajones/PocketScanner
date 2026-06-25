import SwiftUI

/// A "Merge into…" submenu for a document's context menu. Lists the documents
/// the source may be merged into and calls `merge` with the chosen target.
/// Renders nothing when there are no candidates, so callers can place it
/// unconditionally. Mirrors `MoveToMenu`.
struct MergeIntoMenu: View {
    /// The document being merged (the one that will be absorbed and deleted).
    let source: DocumentSummary
    /// Eligible targets (from `MergeCandidates.list`).
    let candidates: [DocumentSummary]
    /// Invoked with the chosen target document.
    let merge: (DocumentSummary) -> Void

    var body: some View {
        if !candidates.isEmpty {
            Menu {
                ForEach(candidates) { target in
                    Button(target.displayName) { merge(target) }
                }
            } label: {
                Label("Merge into…", systemImage: "arrow.triangle.merge")
            }
        }
    }
}

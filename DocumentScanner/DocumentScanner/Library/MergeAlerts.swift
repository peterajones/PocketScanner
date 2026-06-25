import SwiftUI

/// A pending merge awaiting confirmation: `source` will be absorbed into
/// `target`, then deleted. Shared by `LibraryView` and `FolderContentsView`.
struct MergePlan {
    let source: DocumentSummary
    let target: DocumentSummary
}

/// The merge confirmation + error alerts, factored into a `ViewModifier` so the
/// library and folder views attach them identically (and to keep each view's
/// `body` under the SwiftUI type-checker's complexity limit).
struct MergeAlerts: ViewModifier {
    @Binding var mergePlan: MergePlan?
    @Binding var mergeError: String?
    let mergeAction: (DocumentSummary, DocumentSummary) -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                "Merge \"\(mergePlan?.source.displayName ?? "")\" into \"\(mergePlan?.target.displayName ?? "")\"?",
                isPresented: Binding(
                    get: { mergePlan != nil },
                    set: { if !$0 { mergePlan = nil } }
                ),
                presenting: mergePlan
            ) { plan in
                Button("Merge") { mergeAction(plan.source, plan.target) }
                Button("Cancel", role: .cancel) {}
            } message: { plan in
                Text("\"\(plan.source.displayName)\"'s pages will be added to the end of \"\(plan.target.displayName)\", and \"\(plan.source.displayName)\" will be deleted.")
            }
            .alert(
                "Couldn't merge",
                isPresented: Binding(
                    get: { mergeError != nil },
                    set: { if !$0 { mergeError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(mergeError ?? "")
            }
    }
}

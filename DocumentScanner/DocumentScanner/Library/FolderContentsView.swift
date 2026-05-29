import SwiftUI

/// Shows the documents inside a single folder. Pushed onto the root
/// LibraryView's NavigationStack when the user taps a folder row.
/// Inherits the navigationDestination handlers from the root, so
/// tapping a document still pushes the existing DocumentViewerView.
struct FolderContentsView<Store: LibraryStoring & Observable>: View {
    let folderURL: URL
    @Bindable var store: Store
    let storage: DocumentStorage

    @State private var searchText = ""

    var body: some View {
        Group {
            if docsInFolder.isEmpty {
                ContentUnavailableView(
                    "Empty folder",
                    systemImage: "folder",
                    description: Text("Move documents into this folder from the main library.")
                )
            } else {
                List(filtered) { summary in
                    if summary.isCorrupt {
                        DocumentRow(summary: summary)
                            .contextMenu {
                                Button(role: .destructive) {
                                    try? storage.delete(at: summary.url)
                                    store.refresh()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    } else {
                        NavigationLink(value: summary) {
                            DocumentRow(summary: summary)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search this folder")
                .refreshable { store.refresh() }
            }
        }
        .navigationTitle(folderURL.lastPathComponent)
    }

    private var docsInFolder: [DocumentSummary] {
        store.summaries.filter { $0.url.deletingLastPathComponent() == folderURL }
    }

    private var filtered: [DocumentSummary] {
        guard !searchText.isEmpty else { return docsInFolder }
        let needle = searchText.lowercased()
        return docsInFolder.filter {
            $0.displayName.lowercased().contains(needle)
            || $0.ocrSnippet.lowercased().contains(needle)
        }
    }
}

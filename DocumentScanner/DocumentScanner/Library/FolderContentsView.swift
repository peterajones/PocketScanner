import SwiftUI

/// Shows the documents inside a single folder. Pushed onto the root
/// LibraryView's NavigationStack when the user taps a folder row.
/// Inherits the navigationDestination handlers from the root, so
/// tapping a document still pushes the existing DocumentViewerView.
///
/// Has its own scan flow that writes new documents into this folder
/// rather than into the root — a folder-scoped DocumentStorage is
/// constructed from `folderURL` and passed to NameDocumentSheet.
struct FolderContentsView<Store: LibraryStoring & Observable>: View {
    let folderURL: URL
    @Bindable var store: Store
    let storage: DocumentStorage
    let scannerPresenter: DocumentScannerPresenting
    let pipeline: ScanPipeline

    @State private var searchText = ""
    @State private var showingCapture = false
    @State private var showingCameraDenied = false
    @State private var nameSheet: NameSheetContext?

    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let task: Task<ScanResult, Error>
    }

    /// Storage scoped to this folder so write() puts new scans here.
    private var folderStorage: DocumentStorage {
        DocumentStorage(documentsURL: folderURL)
    }

    var body: some View {
        Group {
            if docsInFolder.isEmpty {
                ContentUnavailableView(
                    "Empty folder",
                    systemImage: "folder",
                    description: Text("Tap + to scan a document into this folder, or move existing ones in from the main library.")
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    triggerScan()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("Folder.AddButton")
            }
        }
        .fullScreenCover(isPresented: $showingCapture) {
            CaptureSheet(
                presenter: scannerPresenter,
                onFinish: { images in
                    showingCapture = false
                    let task = Task { try await pipeline.process(images: images) }
                    nameSheet = NameSheetContext(task: task)
                },
                onCancel: { showingCapture = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingCameraDenied) {
            CameraDeniedView(onDismiss: { showingCameraDenied = false })
        }
        .sheet(item: $nameSheet) { ctx in
            NameDocumentSheet(
                pipelineTask: ctx.task,
                storage: folderStorage,
                onSaved: {
                    nameSheet = nil
                    store.refresh()
                },
                onCancel: { nameSheet = nil }
            )
        }
    }

    private var docsInFolder: [DocumentSummary] {
        let folderPath = folderURL.standardizedFileURL.path
        return store.summaries.filter {
            $0.url.deletingLastPathComponent().standardizedFileURL.path == folderPath
        }
    }

    private var filtered: [DocumentSummary] {
        guard !searchText.isEmpty else { return docsInFolder }
        let needle = searchText.lowercased()
        return docsInFolder.filter {
            $0.displayName.lowercased().contains(needle)
            || $0.ocrSnippet.lowercased().contains(needle)
        }
    }

    private func triggerScan() {
        Task {
            switch await CameraPermission.request() {
            case .authorized: showingCapture = true
            case .denied: showingCameraDenied = true
            case .notDetermined: break  // unreachable after request()
            }
        }
    }
}

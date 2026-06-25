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
    @State private var folders: [URL] = []
    @State private var folderActionError: String?
    @State private var docBeingDeleted: DocumentSummary?
    @State private var mergePlan: MergePlan?
    @State private var mergeError: String?
    @AppStorage("sortKey") private var sortKeyRaw = SortKey.date.rawValue
    @AppStorage("sortAscending") private var sortAscending = false
    @AppStorage("libraryUsesGrid") private var usesGrid = false

    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let images: [UIImage]
        let recognizeTask: Task<[ScannedPage], Never>
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
            } else if usesGrid {
                gridBody
            } else {
                listBody
            }
        }
        .navigationTitle(folderURL.lastPathComponent)
        .task { refreshFolders() }
        .alert("Couldn't move document",
               isPresented: Binding(
                get: { folderActionError != nil },
                set: { _ in folderActionError = nil }
               )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(folderActionError ?? "")
        }
        .alert(
            "Delete this document?",
            isPresented: Binding(
                get: { docBeingDeleted != nil },
                set: { if !$0 { docBeingDeleted = nil } }
            ),
            presenting: docBeingDeleted
        ) { summary in
            Button("Delete", role: .destructive) {
                try? storage.delete(at: summary.url)
                store.refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: { summary in
            Text("This will permanently remove \"\(summary.displayName).pdf\".")
        }
        .modifier(MergeAlerts(mergePlan: $mergePlan, mergeError: $mergeError,
                              mergeAction: mergeDocument))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SortMenu(sort: sort, onSelect: selectSort)
            }
            ToolbarItem(placement: .topBarTrailing) {
                LayoutToggle(usesGrid: usesGrid, onToggle: { usesGrid.toggle() })
            }
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
                    let captured = images
                    let recognizeTask = Task { await pipeline.recognize(images: captured) }
                    nameSheet = NameSheetContext(images: captured, recognizeTask: recognizeTask)
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
                images: ctx.images,
                recognizeTask: ctx.recognizeTask,
                pipeline: pipeline,
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
        let matched = searchText.isEmpty
            ? docsInFolder
            : SearchMatcher.matches(term: searchText, in: store.summaries, scope: .folder(folderURL))
        return sort.sorted(matched)
    }

    private func refreshFolders() {
        folders = (try? storage.listFolders())?
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) ?? []
    }

    private func moveDocument(_ summary: DocumentSummary, to destination: URL) {
        do {
            _ = try storage.moveDocument(at: summary.url, toFolder: destination)
            store.refresh()
        } catch {
            folderActionError = error.localizedDescription
        }
    }

    private func mergeDocument(_ source: DocumentSummary, into target: DocumentSummary) {
        do {
            try DocumentMerge.merge(source: source.url, into: target.url,
                                    targetName: target.displayName)
            store.refresh()
        } catch {
            mergeError = "Couldn't merge \"\(source.displayName)\" into \"\(target.displayName)\". Please try again."
        }
    }

    private var sort: DocumentSort {
        DocumentSort(key: SortKey(rawValue: sortKeyRaw) ?? .date, ascending: sortAscending)
    }

    private func selectSort(_ key: SortKey) {
        if key == sort.key {
            sortAscending.toggle()
        } else {
            sortKeyRaw = key.rawValue
            sortAscending = DocumentSort.defaultAscending(for: key)
        }
    }

    @ViewBuilder
    private func docContextMenu(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            Button(role: .destructive) {
                docBeingDeleted = summary
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } else {
            MoveToMenu(
                currentParent: folderURL,
                root: storage.documentsURL,
                folders: folders,
                move: { moveDocument(summary, to: $0) }
            )
            MergeIntoMenu(
                source: summary,
                candidates: MergeCandidates.list(source: summary, all: store.summaries),
                merge: { target in mergePlan = MergePlan(source: summary, target: target) }
            )
            Button(role: .destructive) {
                docBeingDeleted = summary
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 12)]
    }

    @ViewBuilder
    private func docRow(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            DocumentRow(summary: summary)
                .contextMenu { docContextMenu(summary) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        docBeingDeleted = summary
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        } else {
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .folder(folderURL))) {
                DocumentRow(summary: summary)
            }
            .contextMenu { docContextMenu(summary) }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    docBeingDeleted = summary
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func docTile(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            DocumentTile(summary: summary)
                .contextMenu { docContextMenu(summary) }
        } else {
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .folder(folderURL))) {
                DocumentTile(summary: summary)
            }
            .buttonStyle(.plain)
            .contextMenu { docContextMenu(summary) }
        }
    }

    @ViewBuilder
    private var listBody: some View {
        List(filtered) { summary in
            docRow(summary)
        }
        .searchable(text: $searchText, prompt: "Search this folder")
        .overlay {
            if !searchText.isEmpty && filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .refreshable {
            store.refresh()
            refreshFolders()
        }
    }

    @ViewBuilder
    private var gridBody: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(filtered) { summary in
                    docTile(summary)
                }
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Search this folder")
        .overlay {
            if !searchText.isEmpty && filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .refreshable {
            store.refresh()
            refreshFolders()
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

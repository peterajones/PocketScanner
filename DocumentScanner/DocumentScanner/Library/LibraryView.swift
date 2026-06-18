import SwiftUI
import PDFKit

struct LibraryView<Store: LibraryStoring & Observable>: View {
    @Bindable var store: Store

    let scannerPresenter: DocumentScannerPresenting
    let storage: DocumentStorage
    let pipeline: ScanPipeline
    let lockSettings: AppLockSettings

    @State private var searchText = ""
    @State private var showingCapture = false
    @State private var showingCameraDenied = false
    @State private var nameSheet: NameSheetContext?
    @State private var path = NavigationPath()
    @State private var folders: [URL] = []
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var folderActionError: String?
    @State private var folderBeingRenamed: URL?
    @State private var renameFolderName = ""
    @State private var folderBeingDeleted: URL?
    @State private var docBeingDeleted: DocumentSummary?
    @AppStorage("showFolders") private var showFolders = true
    @AppStorage("sortKey") private var sortKeyRaw = SortKey.date.rawValue
    @AppStorage("sortAscending") private var sortAscending = false
    @AppStorage("libraryUsesGrid") private var usesGrid = false

    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let images: [UIImage]
        let recognizeTask: Task<[ScannedPage], Never>
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if visibleDocs.isEmpty && (!showFolders || folders.isEmpty) {
                    ContentUnavailableView(
                        "No documents yet",
                        systemImage: "doc.viewfinder",
                        description: Text(showFolders
                            ? "Tap + to scan a document or create a folder."
                            : "Tap + to scan a document.")
                    )
                } else if usesGrid {
                    gridBody
                } else {
                    listBody
                }
            }
            .navigationTitle("Scanned Documents")
            .navigationDestination(for: DocumentRoute.self) { route in
                DocumentViewerView(
                    summary: route.summary,
                    storage: storage,
                    scannerPresenter: scannerPresenter,
                    pipeline: pipeline,
                    searchContext: searchContext(for: route),
                    onDeleted: {
                        store.refresh()
                        path.removeLast()
                    },
                    onDocumentCreated: { store.refresh() }
                )
            }
            .navigationDestination(for: URL.self) { folderURL in
                FolderContentsView(
                    folderURL: folderURL,
                    store: store,
                    storage: storage,
                    scannerPresenter: scannerPresenter,
                    pipeline: pipeline
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView(lockSettings: lockSettings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("Library.SettingsButton")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SortMenu(sort: sort, onSelect: selectSort)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    LayoutToggle(usesGrid: usesGrid, onToggle: { usesGrid.toggle() })
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if showFolders {
                        Menu {
                            Button {
                                triggerScan()
                            } label: {
                                Label("Scan Document", systemImage: "doc.viewfinder")
                            }
                            Button {
                                newFolderName = ""
                                showingNewFolderAlert = true
                            } label: {
                                Label("New Folder", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("Library.AddButton")
                    } else {
                        Button {
                            triggerScan()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityIdentifier("Library.AddButton")
                    }
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
                    storage: storage,
                    onSaved: {
                        nameSheet = nil
                        store.refresh()
                    },
                    onCancel: { nameSheet = nil }
                )
            }
            .alert("New Folder", isPresented: $showingNewFolderAlert) {
                TextField("Folder name", text: $newFolderName)
                    .autocorrectionDisabled()
                Button("Create") { createFolder() }
                    .accessibilityIdentifier("Library.NewFolder.Create")
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter a name for the new folder.")
            }
            .alert("Rename Folder",
                   isPresented: Binding(
                    get: { folderBeingRenamed != nil },
                    set: { if !$0 { folderBeingRenamed = nil } }
                   )) {
                TextField("Folder name", text: $renameFolderName)
                    .autocorrectionDisabled()
                Button("Rename") { renameFolder() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Choose a new name for this folder.")
            }
            .alert("Delete Folder?",
                   isPresented: Binding(
                    get: { folderBeingDeleted != nil },
                    set: { if !$0 { folderBeingDeleted = nil } }
                   )) {
                Button("Delete", role: .destructive) { deleteFolder() }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let folder = folderBeingDeleted, !isFolderEmpty(folder) {
                    Text("This folder and all documents inside it will be deleted.")
                } else {
                    Text("This folder will be deleted.")
                }
            }
            .alert("Couldn't update folder",
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
            .task { refreshFolders() }
            .onChange(of: path.count) { oldCount, newCount in
                // Re-scan when navigation pops back toward the library. The
                // local-mode InMemoryLibraryStore doesn't auto-detect files
                // created deeper in the stack (e.g. page extraction in the
                // viewer); refreshing the store while the library is buried
                // behind a pushed view doesn't reliably re-render it, so we
                // refresh on return — the same foreground moment that manual
                // pull-to-refresh and the delete-then-pop path already use.
                // (iCloud's NSMetadataQuery store updates itself.)
                guard newCount < oldCount else { return }
                store.refresh()
                refreshFolders()
            }
        }
    }

    private func folderRow(_ url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            Text(url.lastPathComponent)
                .font(.body)
            Spacer()
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ url: URL) -> some View {
        Button {
            renameFolderName = url.lastPathComponent
            folderBeingRenamed = url
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button(role: .destructive) {
            folderBeingDeleted = url
        } label: {
            Label("Delete", systemImage: "trash")
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
            if showFolders {
                MoveToMenu(
                    currentParent: summary.url.deletingLastPathComponent(),
                    root: storage.documentsURL,
                    folders: folders,
                    move: { moveDocument(summary, to: $0) }
                )
            }
            Button(role: .destructive) {
                docBeingDeleted = summary
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func docRow(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            DocumentRow(summary: summary, folderName: folderLabel(for: summary))
                .contextMenu { docContextMenu(summary) }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        docBeingDeleted = summary
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        } else {
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .library)) {
                DocumentRow(summary: summary, folderName: folderLabel(for: summary))
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
    private var listBody: some View {
        List {
            if showFolders && !folders.isEmpty && searchText.isEmpty {
                Section {
                    ForEach(folders, id: \.self) { folderURL in
                        NavigationLink(value: folderURL) {
                            folderRow(folderURL)
                        }
                        .accessibilityIdentifier("Library.Folder.\(folderURL.lastPathComponent)")
                        .contextMenu { folderContextMenu(folderURL) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                folderBeingDeleted = folderURL
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            if !filteredDocs.isEmpty {
                Section {
                    ForEach(filteredDocs) { summary in
                        docRow(summary)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search documents")
        .overlay {
            if !searchText.isEmpty && filteredDocs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .refreshable {
            store.refresh()
            refreshFolders()
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 110), spacing: 12)]
    }

    @ViewBuilder
    private var gridBody: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                if showFolders && !folders.isEmpty && searchText.isEmpty {
                    ForEach(folders, id: \.self) { folderURL in
                        NavigationLink(value: folderURL) {
                            FolderTile(url: folderURL)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { folderContextMenu(folderURL) }
                    }
                }
                ForEach(filteredDocs) { summary in
                    docTile(summary)
                }
            }
            .padding()
        }
        .searchable(text: $searchText, prompt: "Search documents")
        .overlay {
            if !searchText.isEmpty && filteredDocs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .refreshable {
            store.refresh()
            refreshFolders()
        }
    }

    @ViewBuilder
    private func docTile(_ summary: DocumentSummary) -> some View {
        if summary.isCorrupt {
            DocumentTile(summary: summary, folderName: folderLabel(for: summary))
                .contextMenu { docContextMenu(summary) }
        } else {
            NavigationLink(value: DocumentRoute(summary: summary, term: searchText, scope: .library)) {
                DocumentTile(summary: summary, folderName: folderLabel(for: summary))
            }
            .buttonStyle(.plain)
            .contextMenu { docContextMenu(summary) }
        }
    }

    /// The containing folder's name for a search result that lives in a folder,
    /// or nil when the doc is at the library root. Used to label flattened
    /// Main Library search results ("in Receipts").
    private func folderLabel(for summary: DocumentSummary) -> String? {
        let parent = summary.url.deletingLastPathComponent().standardizedFileURL
        guard parent.path != storage.documentsURL.standardizedFileURL.path else { return nil }
        return parent.lastPathComponent
    }

    private var docsAtRoot: [DocumentSummary] {
        let rootPath = storage.documentsURL.standardizedFileURL.path
        return store.summaries.filter {
            $0.url.deletingLastPathComponent().standardizedFileURL.path == rootPath
        }
    }

    /// Docs shown in the main list, before search filter. When the user has
    /// disabled "Show Folders" in Settings, we ignore the root-only filter
    /// and show every PDF in storage as a single flat list.
    private var visibleDocs: [DocumentSummary] {
        showFolders ? docsAtRoot : store.summaries
    }

    private var filteredDocs: [DocumentSummary] {
        let matched = searchText.isEmpty
            ? visibleDocs
            : SearchMatcher.matches(term: searchText, in: store.summaries, scope: .library)
        return sort.sorted(matched)
    }

    /// Builds the cross-doc search context for a tapped route: matches the term
    /// within the route's scope (the same `SearchMatcher` the list uses), runs
    /// `findString` for per-doc counts, and points `startDocIndex` at the tapped
    /// doc. Nil when the term is empty, no doc has `findString` matches, or the
    /// tapped doc isn't among them (so the viewer opens plainly rather than on
    /// the wrong document).
    private func searchContext(for route: DocumentRoute) -> SearchContext? {
        guard !route.term.isEmpty else { return nil }
        let candidates = SearchMatcher.matches(
            term: route.term, in: store.summaries, scope: route.scope
        )
        let entries: [SearchContext.DocEntry] = candidates.compactMap { summary in
            guard let pdf = PDFDocument(url: summary.url) else { return nil }
            let count = pdf.findString(route.term, withOptions: .caseInsensitive).count
            return count > 0 ? .init(summary: summary, matchCount: count) : nil
        }
        guard let idx = entries.firstIndex(where: { $0.summary.id == route.summary.id })
        else { return nil }
        return SearchContext(term: route.term, docs: entries, startDocIndex: idx)
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

    private func triggerScan() {
        Task {
            switch await CameraPermission.request() {
            case .authorized: showingCapture = true
            case .denied: showingCameraDenied = true
            case .notDetermined: break  // unreachable after request()
            }
        }
    }

    private func refreshFolders() {
        folders = (try? storage.listFolders())?.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) ?? []
    }

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try storage.createFolder(named: trimmed)
            refreshFolders()
        } catch {
            folderActionError = error.localizedDescription
        }
    }

    private func moveDocument(_ summary: DocumentSummary, to folderURL: URL) {
        do {
            _ = try storage.moveDocument(at: summary.url, toFolder: folderURL)
            store.refresh()
        } catch {
            folderActionError = error.localizedDescription
        }
    }

    private func renameFolder() {
        guard let folder = folderBeingRenamed else { return }
        let trimmed = renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try storage.renameFolder(at: folder, to: trimmed)
            refreshFolders()
            store.refresh()
        } catch {
            folderActionError = error.localizedDescription
        }
        folderBeingRenamed = nil
    }

    private func deleteFolder() {
        guard let folder = folderBeingDeleted else { return }
        do {
            try storage.deleteFolder(at: folder)
            refreshFolders()
            store.refresh()
        } catch {
            folderActionError = error.localizedDescription
        }
        folderBeingDeleted = nil
    }

    private func isFolderEmpty(_ folderURL: URL) -> Bool {
        let path = folderURL.standardizedFileURL.path
        return !store.summaries.contains {
            $0.url.deletingLastPathComponent().standardizedFileURL.path == path
        }
    }
}

import SwiftUI

/// Shows the documents inside a single folder. Pushed onto the root
/// LibraryView's NavigationStack when the user taps a folder row.
/// Inherits the navigationDestination handlers from the root, so
/// tapping a document still pushes the existing DocumentViewerView.
///
/// Has its own scan flow whose Save sheet defaults its destination to this
/// folder (`defaultDestination: folderURL`); the sheet can still retarget the
/// scan to any folder or sub-folder.
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
    @State private var subfolders: [URL] = []
    @State private var showingNewSubfolderAlert = false
    @State private var newSubfolderName = ""
    @State private var subfolderBeingRenamed: URL?
    @State private var renameSubfolderName = ""
    @State private var subfolderBeingDeleted: URL?
    @State private var folderActionError: String?

    /// True only for a level-1 folder (can hold sub-folders). A level-2 folder cannot.
    private var canCreateSubfolder: Bool {
        FolderPaths.level(of: folderURL, root: storage.documentsURL) < 2
    }

    /// A sub-folder is empty if no known document lives anywhere inside it.
    private func isSubfolderEmpty(_ url: URL) -> Bool {
        let prefix = url.standardizedFileURL.path + "/"
        return !store.summaries.contains { $0.url.standardizedFileURL.path.hasPrefix(prefix) }
    }
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

    var body: some View {
        Group {
            if docsInFolder.isEmpty && subfolders.isEmpty {
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
        .alert("New Sub-folder", isPresented: $showingNewSubfolderAlert) {
            TextField("Folder name", text: $newSubfolderName).autocorrectionDisabled()
            Button("Create") { createSubfolder() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Enter a name for the new sub-folder.") }
        .alert("Rename Folder",
               isPresented: Binding(
                get: { subfolderBeingRenamed != nil },
                set: { if !$0 { subfolderBeingRenamed = nil } }
               )) {
            TextField("Folder name", text: $renameSubfolderName).autocorrectionDisabled()
            Button("Rename") { renameSubfolder() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Choose a new name for this folder.") }
        .alert("Delete Folder?",
               isPresented: Binding(
                get: { subfolderBeingDeleted != nil },
                set: { if !$0 { subfolderBeingDeleted = nil } }
               )) {
            Button("Delete", role: .destructive) { deleteSubfolder() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let folder = subfolderBeingDeleted, !isSubfolderEmpty(folder) {
                Text("This folder and all documents inside it will be deleted.")
            } else {
                Text("This folder will be deleted.")
            }
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
                if canCreateSubfolder {
                    Menu {
                        Button {
                            triggerScan()
                        } label: {
                            Label("Scan Document", systemImage: "doc.viewfinder")
                        }
                        Button {
                            newSubfolderName = ""
                            showingNewSubfolderAlert = true
                        } label: {
                            Label("New Sub-folder", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("Folder.AddButton")
                } else {
                    Button {
                        triggerScan()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("Folder.AddButton")
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
                rootStorage: storage,
                defaultDestination: folderURL,
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
        subfolders = (try? storage.listFolders(in: folderURL))?
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            ?? []
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

    @ViewBuilder private func subfolderContextMenu(_ url: URL) -> some View {
        Button {
            renameSubfolderName = url.lastPathComponent
            subfolderBeingRenamed = url
        } label: { Label("Rename", systemImage: "pencil") }
        Button(role: .destructive) {
            subfolderBeingDeleted = url
        } label: { Label("Delete", systemImage: "trash") }
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
        List {
            if !subfolders.isEmpty && searchText.isEmpty {
                Section {
                    ForEach(subfolders, id: \.self) { subfolderURL in
                        NavigationLink(value: subfolderURL) {
                            folderRow(subfolderURL)
                        }
                        .contextMenu { subfolderContextMenu(subfolderURL) }
                    }
                }
            }
            if !filtered.isEmpty {
                Section {
                    ForEach(filtered) { summary in
                        docRow(summary)
                    }
                }
            }
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
                if !subfolders.isEmpty && searchText.isEmpty {
                    ForEach(subfolders, id: \.self) { subfolderURL in
                        NavigationLink(value: subfolderURL) {
                            FolderTile(url: subfolderURL)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { subfolderContextMenu(subfolderURL) }
                    }
                }
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

    private func createSubfolder() {
        let trimmed = newSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do { _ = try storage.createFolder(named: trimmed, in: folderURL); refreshFolders() }
        catch { folderActionError = error.localizedDescription }
    }

    private func renameSubfolder() {
        guard let folder = subfolderBeingRenamed else { return }
        let trimmed = renameSubfolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do { _ = try storage.renameFolder(at: folder, to: trimmed); refreshFolders() }
        catch { folderActionError = error.localizedDescription }
        subfolderBeingRenamed = nil
    }

    private func deleteSubfolder() {
        guard let folder = subfolderBeingDeleted else { return }
        do { try storage.deleteFolder(at: folder); store.refresh(); refreshFolders() }
        catch { folderActionError = error.localizedDescription }
        subfolderBeingDeleted = nil
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

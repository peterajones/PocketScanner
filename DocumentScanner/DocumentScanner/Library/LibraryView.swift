import SwiftUI

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

    private struct NameSheetContext: Identifiable {
        let id = UUID()
        let task: Task<ScanResult, Error>
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if folders.isEmpty && docsAtRoot.isEmpty {
                    ContentUnavailableView(
                        "No documents yet",
                        systemImage: "doc.viewfinder",
                        description: Text("Tap + to scan a document or create a folder.")
                    )
                } else {
                    List {
                        if !folders.isEmpty {
                            Section {
                                ForEach(folders, id: \.self) { folderURL in
                                    NavigationLink(value: folderURL) {
                                        folderRow(folderURL)
                                    }
                                    .accessibilityIdentifier("Library.Folder.\(folderURL.lastPathComponent)")
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
                    .refreshable {
                        store.refresh()
                        refreshFolders()
                    }
                }
            }
            .navigationTitle("Scanned Documents")
            .navigationDestination(for: DocumentSummary.self) { summary in
                DocumentViewerView(
                    summary: summary,
                    storage: storage,
                    scannerPresenter: scannerPresenter,
                    pipeline: pipeline,
                    searchTerm: searchText.isEmpty ? nil : searchText,
                    onDeleted: {
                        store.refresh()
                        path.removeLast()
                    }
                )
            }
            .navigationDestination(for: URL.self) { folderURL in
                FolderContentsView(folderURL: folderURL, store: store, storage: storage)
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
            .alert("Couldn't update folder",
                   isPresented: Binding(
                    get: { folderActionError != nil },
                    set: { _ in folderActionError = nil }
                   )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(folderActionError ?? "")
            }
            .task { refreshFolders() }
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
    private func docRow(_ summary: DocumentSummary) -> some View {
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
            .contextMenu {
                if !folders.isEmpty {
                    Menu("Move to Folder") {
                        ForEach(folders, id: \.self) { folder in
                            Button(folder.lastPathComponent) {
                                moveDocument(summary, to: folder)
                            }
                        }
                    }
                }
            }
        }
    }

    private var docsAtRoot: [DocumentSummary] {
        let rootPath = storage.documentsURL.standardizedFileURL.path
        return store.summaries.filter {
            $0.url.deletingLastPathComponent().standardizedFileURL.path == rootPath
        }
    }

    private var filteredDocs: [DocumentSummary] {
        guard !searchText.isEmpty else { return docsAtRoot }
        let needle = searchText.lowercased()
        return docsAtRoot.filter {
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
}

import SwiftUI
import PDFKit
import UIKit

struct DocumentViewerView: View {
    let summary: DocumentSummary
    let storage: DocumentStorage
    let scannerPresenter: DocumentScannerPresenting
    let pipeline: ScanPipeline
    let searchContext: SearchContext?
    /// Closure dismissing the viewer; provided by LibraryView so the deletion
    /// path can pop the navigation stack.
    let onDeleted: () -> Void
    /// Called after this viewer creates a NEW document (page extraction) so the
    /// library can refresh. The local-mode `InMemoryLibraryStore` doesn't detect
    /// new files on its own the way the iCloud `NSMetadataQuery` store does, so
    /// without this the extracted doc wouldn't appear until a manual refresh.
    let onDocumentCreated: () -> Void

    init(summary: DocumentSummary,
         storage: DocumentStorage,
         scannerPresenter: DocumentScannerPresenting,
         pipeline: ScanPipeline,
         searchContext: SearchContext?,
         onDeleted: @escaping () -> Void,
         onDocumentCreated: @escaping () -> Void) {
        self.summary = summary
        self.storage = storage
        self.scannerPresenter = scannerPresenter
        self.pipeline = pipeline
        self.searchContext = searchContext
        self.onDeleted = onDeleted
        self.onDocumentCreated = onDocumentCreated
        // Seed currentDocIndex from the context so the first .task(id:) fires
        // on the correct doc — avoiding an .onAppear two-phase race where
        // task(id:0) could briefly start loading docs[0] before being cancelled.
        _currentDocIndex = State(initialValue: searchContext?.startDocIndex ?? 0)
    }

    private struct PageEditorContext: Identifiable {
        let index: Int
        var id: Int { index }
    }

    private struct PendingDeletion: Identifiable {
        let id = UUID()
        let annotation: PDFAnnotation
        let page: PDFPage
    }

    private struct PendingExtraction: Identifiable {
        let id = UUID()
        let pdf: PDFDocument
    }

    @State private var session: DocumentSession?
    @State private var loadError: String?
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var editMode = false
    @State private var showAddPages = false
    @State private var addPagesTask: Task<Void, Never>?
    @State private var editingPageIndex: Int?
    @State private var searchHighlight: SearchHighlight?
    @State private var currentDocIndex: Int
    @State private var pendingJumpToLastMatch: Bool = false
    @State private var annotationRevision: Int = 0
    @State private var pendingDeletion: PendingDeletion?
    @State private var pendingExtraction: PendingExtraction?
    @State private var extractName: String = ""
    @State private var extractError: String?
    @State private var showingSignCapture = false
    @State private var showingSignaturePicker = false
    @State private var showingAddDate = false
    @State private var pendingDateEdit: SignatureEdit?
    @State private var placement: PlacementRequest?
    @State private var pendingSignatureEdit: SignatureEdit?
    @State private var showingMovePicker = false
    @State private var moveTarget: SignatureEdit?
    @State private var currentVisiblePageIndex = 0
    /// Bumped only on signature add/remove/move. A signature is a custom-draw
    /// stamp painted into PDFView's cached page tile, so (unlike standard
    /// highlights, which live in an overlay layer) removing/moving it doesn't
    /// invalidate the tile — the stale paint lingers. PDFKitView watches this to
    /// force a tile-clearing reload only when a signature actually changed.
    @State private var signatureRevision = 0
    private let signatureStore = SignatureStore()

    private struct PlacementRequest: Identifiable {
        let id = UUID()
        let signature: UIImage
        var signatureID: String? = nil    // which saved signature this came from (for Move)
        let page: PDFPage
        let seedRect: CGRect?
        /// When moving an existing signature, the annotation to remove — but only
        /// once the user commits (taps Done), so a Cancel keeps the original.
        var replacing: PDFAnnotation? = nil
        var title: String = "Place Signature"
        var dateString: String? = nil     // non-nil ⇒ a date stamp (place via placeDateStamp)
    }
    private struct SignatureEdit: Identifiable {
        let id = UUID()
        let annotation: PDFAnnotation
        let page: PDFPage
    }

    /// The summary the viewer is currently displaying. Falls back to the
    /// `summary` parameter when there's no search context (single-doc nav).
    private var activeSummary: DocumentSummary {
        searchContext?.docs[safe: currentDocIndex]?.summary ?? summary
    }

    private var hasNextDoc: Bool {
        guard let ctx = searchContext else { return false }
        return currentDocIndex < ctx.docs.count - 1
    }

    private var hasPreviousDoc: Bool { currentDocIndex > 0 }

    private func handleNext(_ h: SearchHighlight) {
        if h.currentIndex == h.matchCount - 1, hasNextDoc {
            currentDocIndex += 1
            // Mutating currentDocIndex changes the session-loading task's id,
            // which triggers a reload and a fresh SearchHighlight pointing at
            // match 0 of the next doc.
        } else {
            h.next()
        }
    }

    private func handlePrevious(_ h: SearchHighlight) {
        if h.currentIndex == 0, hasPreviousDoc {
            pendingJumpToLastMatch = true
            currentDocIndex -= 1
            // rebuildHighlight will see pendingJumpToLastMatch and jump to
            // matchCount-1 after the new highlight is built.
        } else {
            h.previous()
        }
    }

    private func counterLabel(highlight h: SearchHighlight) -> String {
        guard let ctx = searchContext else {
            return "\((h.currentIndex ?? 0) + 1)/\(h.matchCount)"
        }
        let priorMatches = ctx.docs[..<currentDocIndex]
            .reduce(0) { $0 + $1.matchCount }
        let global = priorMatches + (h.currentIndex ?? 0) + 1
        return "\(global)/\(ctx.totalMatches)"
    }

    var body: some View {
        Group {
            if let session {
                loadedBody(session: session)
            } else if let loadError {
                ContentUnavailableView("Couldn't open document",
                                       systemImage: "doc.text.fill",
                                       description: Text(loadError))
            } else {
                ProgressView()
            }
        }
        .task(id: currentDocIndex) {
            session = nil
            loadError = nil
            do { session = try DocumentSession(summary: activeSummary, storage: storage) }
            catch { loadError = String(describing: error) }
        }
    }

    /// `documentContent` plus the date-stamp sheet + edit alert. Split into its own
    /// helper so the modifier chain in `loadedBody` stays within the Swift
    /// type-checker's budget — adding these two modifiers inline tripped "unable to
    /// type-check this expression in reasonable time" (the same ceiling the rename
    /// alert hit earlier).
    @ViewBuilder
    private func dateStampContent(session: DocumentSession) -> some View {
        documentContent(session: session)
            .sheet(isPresented: $showingAddDate) {
                AddDateSheet(
                    onPick: { date, format in
                        showingAddDate = false
                        guard let page = currentPageForSigning(session: session) else { return }
                        let str = format.string(for: date)
                        let img = DateStampRenderer.image(for: str)
                        placement = PlacementRequest(signature: img, page: page, seedRect: nil,
                                                     title: "Place Date", dateString: str)
                    },
                    onCancel: { showingAddDate = false }
                )
            }
            .alert("Date", isPresented: Binding(
                get: { pendingDateEdit != nil },
                set: { if !$0 { pendingDateEdit = nil } }
            ), presenting: pendingDateEdit) { item in
                Button("Move") {
                    // Re-render the SAME date from the string persisted in contents,
                    // then re-place it (works before and after a save→reload).
                    let str = item.annotation.contents ?? ""
                    let img = DateStampRenderer.image(for: str)
                    placement = PlacementRequest(signature: img, page: item.page,
                                                 seedRect: item.annotation.bounds,
                                                 replacing: item.annotation,
                                                 title: "Place Date", dateString: str)
                    pendingDateEdit = nil
                }
                Button("Remove", role: .destructive) {
                    item.page.removeAnnotation(item.annotation)
                    _ = try? session.save(); annotationRevision &+= 1; signatureRevision &+= 1
                    pendingDateEdit = nil
                }
                Button("Cancel", role: .cancel) { pendingDateEdit = nil }
            }
    }

    @ViewBuilder
    private func loadedBody(session: DocumentSession) -> some View {
        if !session.conflicts.isEmpty {
            ConflictResolutionView(session: session, onResolved: {
                // No-op — once session.conflicts is empty, this view rebuilds
                // and falls through to the main body below.
            })
        } else {
            dateStampContent(session: session)
        .animation(.easeInOut(duration: 0.2), value: editMode)
        .task(id: ObjectIdentifier(session.pdf)) {
            rebuildHighlight(session: session)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { viewerToolbar(session: session) }
        .alert("Rename Document", isPresented: $isRenaming) {
            renameAlertActions(session: session)
        }
        .confirmationDialog("Delete this document?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                try? storage.delete(at: session.url)
                onDeleted()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove \"\(session.displayName).pdf\" from iCloud.")
        }
        .alert("Save as New Document", isPresented: Binding(
            get: { pendingExtraction != nil },
            set: { if !$0 { pendingExtraction = nil } }
        )) {
            TextField("Name", text: $extractName)
            Button("Save") { saveExtraction(session: session) }
            Button("Cancel", role: .cancel) { pendingExtraction = nil }
        } message: {
            Text("Adds a new document with the selected pages to this folder. The original is unchanged.")
        }
        .alert("Couldn't Save", isPresented: Binding(
            get: { extractError != nil },
            set: { if !$0 { extractError = nil } }
        )) {
            Button("OK", role: .cancel) { extractError = nil }
        } message: {
            Text(extractError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestDeleteDocument)) { _ in
            showDeleteConfirm = true
        }
        .fullScreenCover(isPresented: $showAddPages) {
            CaptureSheet(
                presenter: scannerPresenter,
                onFinish: { images in
                    showAddPages = false
                    addPagesTask = Task { @MainActor in
                        guard let session = self.session else { return }
                        do {
                            let result = try await pipeline.process(images: images)
                            DocumentMutations.append(result.pdf, to: session.pdf)
                            _ = try session.save()
                        } catch {
                            // Surfaced later by Plan 4 error handling.
                        }
                    }
                },
                onCancel: { showAddPages = false }
            )
            .ignoresSafeArea()
        }
        .sheet(item: Binding(
            get: { editingPageIndex.map { PageEditorContext(index: $0) } },
            set: { editingPageIndex = $0?.index }
        )) { ctx in
            PageEditorView(
                session: session,
                pageIndex: ctx.index,
                onDismiss: { editingPageIndex = nil }
            )
        }
        .sheet(isPresented: $showingSignCapture) {
            SignatureCaptureView(
                presenter: SingleShotCameraScanner(), store: signatureStore,
                onSaved: {
                    showingSignCapture = false
                    if let sig = signatureStore.all().first, let page = currentPageForSigning(session: session) {
                        placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                     page: page, seedRect: nil)
                    }
                },
                onCancel: { showingSignCapture = false }
            )
        }
        .sheet(isPresented: $showingSignaturePicker) {
            SignaturePicker(
                signatures: signatureStore.all(),
                onPick: { sig in
                    showingSignaturePicker = false
                    if let page = currentPageForSigning(session: session) {
                        placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                     page: page, seedRect: nil)
                    }
                },
                onCancel: { showingSignaturePicker = false }
            )
        }
        .sheet(isPresented: $showingMovePicker) {
            SignaturePicker(
                signatures: signatureStore.all(),
                onPick: { sig in
                    showingMovePicker = false
                    if let target = moveTarget {
                        placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                     page: target.page, seedRect: target.annotation.bounds,
                                                     replacing: target.annotation)
                    }
                    moveTarget = nil
                },
                onCancel: { showingMovePicker = false; moveTarget = nil }
            )
        }
        .sheet(item: $placement) { req in
            SignaturePlacementView(
                pageImage: pageRenderForSigning(req.page),
                signature: req.signature,
                pageBounds: req.page.bounds(for: .mediaBox),
                initialPageRect: req.seedRect,
                title: req.title,
                onPlace: { rect in
                    // Remove the old annotation only now, on commit — so a Cancel
                    // above leaves the original untouched.
                    if let old = req.replacing { req.page.removeAnnotation(old) }
                    if let ds = req.dateString {
                        placeDateStamp(req.signature, dateString: ds, at: rect, on: req.page, session: session)
                    } else {
                        placeSignature(req.signature, id: req.signatureID, at: rect, on: req.page, session: session)
                    }
                    placement = nil
                },
                onCancel: { placement = nil }
            )
        }
        .alert("Signature", isPresented: Binding(
            get: { pendingSignatureEdit != nil },
            set: { if !$0 { pendingSignatureEdit = nil } }
        ), presenting: pendingSignatureEdit) { item in
            Button("Move") {
                // Re-place the SAME signature: read its id off the annotation and
                // reload that image. If it was deleted (or has no id), fall back to
                // the picker so the move still works.
                let id = item.annotation.contents
                if let sig = id.flatMap({ signatureStore.signature(withID: $0) }) {
                    placement = PlacementRequest(signature: sig.image, signatureID: sig.id,
                                                 page: item.page, seedRect: item.annotation.bounds,
                                                 replacing: item.annotation)
                    pendingSignatureEdit = nil
                } else {
                    moveTarget = item                 // remember what we're moving
                    pendingSignatureEdit = nil
                    showingMovePicker = true
                }
            }
            Button("Remove", role: .destructive) {
                item.page.removeAnnotation(item.annotation)
                _ = try? session.save(); annotationRevision &+= 1; signatureRevision &+= 1
                pendingSignatureEdit = nil
            }
            Button("Cancel", role: .cancel) { pendingSignatureEdit = nil }
        }
        }
    }

    private func applyTool(_ tool: AnnotationTool, to selection: PDFSelection, session: DocumentSession) {
        let made = AnnotationFactory.annotations(for: selection, tool: tool)
        guard !made.isEmpty else { return }
        for (page, annotation) in made {
            page.addAnnotation(annotation)
        }
        // Persist immediately (consistent with edit-mode saves). save() strips
        // only search highlights, so these user marks are written to disk.
        _ = try? session.save()
        annotationRevision &+= 1
    }

    private func rebuildHighlight(session: DocumentSession) {
        guard let term = searchContext?.term, !term.isEmpty else {
            searchHighlight = nil
            return
        }
        let matches = session.pdf.findString(term, withOptions: .caseInsensitive)
        let h = SearchHighlight(matches: matches)
        // Always clear the pending-jump flag once we've built a highlight for
        // the destination doc — even if matchCount is 0 (e.g., file became
        // temporarily unreadable). Leaving the flag set would misroute the
        // next successful doc load to its last match instead of its first.
        if pendingJumpToLastMatch {
            if h.matchCount > 0 {
                for _ in 0..<(h.matchCount - 1) { h.next() }
            }
            pendingJumpToLastMatch = false
        }
        searchHighlight = h
    }

    private func saveExtraction(session: DocumentSession) {
        guard let extraction = pendingExtraction else { return }
        let name = extractName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        // Write next to the source document so the new doc lands in the same
        // folder (consistent with folder-aware scan saving). DocumentStorage
        // sanitizes the name and resolves collisions with a " (N)" suffix.
        let folderStorage = DocumentStorage(documentsURL: session.url.deletingLastPathComponent())
        do {
            _ = try folderStorage.write(extraction.pdf, preferredName: name)
            onDocumentCreated()
        } catch {
            extractError = "Couldn't save \"\(name)\". Please try again."
        }
        pendingExtraction = nil
    }

    private func beginRename(session: DocumentSession) {
        renameText = session.displayName
        isRenaming = true
    }

    @ViewBuilder
    private func documentContent(session: DocumentSession) -> some View {
        VStack(spacing: 0) {
            PDFKitView(
                document: session.pdf,
                highlightedSelections: searchHighlight?.matches ?? [],
                currentSelection: searchHighlight?.current,
                annotationRevision: annotationRevision,
                signatureRevision: signatureRevision,
                onApplyTool: { tool, selection in
                    applyTool(tool, to: selection, session: session)
                },
                onRequestDelete: { annotation, page in
                    if annotation.userName == DocumentSession.signatureAnnotationName {
                        pendingSignatureEdit = SignatureEdit(annotation: annotation, page: page)
                    } else if annotation.userName == DocumentSession.dateStampAnnotationName {
                        pendingDateEdit = SignatureEdit(annotation: annotation, page: page)
                    } else {
                        pendingDeletion = PendingDeletion(annotation: annotation, page: page)
                    }
                },
                currentPageIndex: $currentVisiblePageIndex
            )
            .ignoresSafeArea(edges: editMode ? [] : .bottom)
            .confirmationDialog(
                "Remove this mark?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                presenting: pendingDeletion
            ) { item in
                Button("Delete", role: .destructive) {
                    item.page.removeAnnotation(item.annotation)
                    _ = try? session.save()
                    annotationRevision &+= 1
                    pendingDeletion = nil
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            }
            if editMode {
                EditModeView(
                    session: session,
                    onEditPage: { editingPageIndex = $0 },
                    onAddPages: { showAddPages = true },
                    onExtract: { indices in
                        let extracted = DocumentMutations.extractPages(from: session.pdf, at: indices)
                        guard extracted.pageCount > 0 else { return }
                        extractName = "\(session.displayName) extract"
                        pendingExtraction = PendingExtraction(pdf: extracted)
                    }
                )
                .transition(.move(edge: .bottom))
            }
        }
    }

    @ViewBuilder
    private func renameAlertActions(session: DocumentSession) -> some View {
        TextField("Name", text: $renameText).autocorrectionDisabled()
        Button("Rename") {
            session.displayName = renameText
            commitRename(session: session)
        }
        Button("Cancel", role: .cancel) {}
    }

    @ToolbarContentBuilder
    private func viewerToolbar(session: DocumentSession) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button(session.displayName) { beginRename(session: session) }
                .font(.headline)
                .foregroundStyle(.primary)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button(editMode ? "Done" : "Edit") { editMode.toggle() }
                .accessibilityIdentifier("Viewer.EditToggle")
            Button("Sign") {
                let sigs = signatureStore.all()
                if sigs.isEmpty {
                    showingSignCapture = true
                } else if sigs.count == 1 {
                    // place the only signature directly (no-op if no page to sign)
                    if let page = currentPageForSigning(session: session) {
                        placement = PlacementRequest(signature: sigs[0].image, signatureID: sigs[0].id,
                                                     page: page, seedRect: nil)
                    }
                } else {
                    showingSignaturePicker = true
                }
            }
            Button("Date") {
                if currentPageForSigning(session: session) != nil { showingAddDate = true }
            }
            .accessibilityIdentifier("Viewer.DateButton")
            Spacer()
            if let h = searchHighlight, h.matchCount > 0 {
                Button { handlePrevious(h) } label: { Image(systemName: "chevron.up") }
                Text(counterLabel(highlight: h))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button { handleNext(h) } label: { Image(systemName: "chevron.down") }
                Spacer()
            }
            ShareLink(item: session.url)
            Menu {
                Button {
                    beginRename(session: session)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .accessibilityIdentifier("Viewer.Rename")
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("Viewer.Delete")
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func commitRename(session: DocumentSession) {
        isRenaming = false
        let trimmed = session.displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            session.displayName = summary.displayName // revert to original
            return
        }
        do { try session.save() }
        catch { session.displayName = summary.displayName } // revert on failure
    }

    private func currentPageForSigning(session: DocumentSession) -> PDFPage? {
        let idx = min(max(currentVisiblePageIndex, 0), session.pdf.pageCount - 1)
        return session.pdf.page(at: idx)
    }

    private func pageRenderForSigning(_ page: PDFPage) -> UIImage {
        PageImageRenderer().image(from: page) ?? UIImage()
    }

    private func placeSignature(_ image: UIImage, id: String?, at rect: CGRect, on page: PDFPage, session: DocumentSession) {
        let stamp = ImageStampAnnotation(image: image, bounds: rect,
                                         userName: DocumentSession.signatureAnnotationName)
        stamp.contents = id    // remember which saved signature this is, for Move
        page.addAnnotation(stamp)
        _ = try? session.save()
        annotationRevision &+= 1
        signatureRevision &+= 1
    }

    private func placeDateStamp(_ image: UIImage, dateString: String, at rect: CGRect, on page: PDFPage, session: DocumentSession) {
        let stamp = ImageStampAnnotation(image: image, bounds: rect,
                                         userName: DocumentSession.dateStampAnnotationName)
        stamp.contents = dateString   // persist the rendered date so Move can re-render it
        page.addAnnotation(stamp)
        _ = try? session.save()
        annotationRevision &+= 1
        signatureRevision &+= 1
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private final class MarkupPDFView: PDFView {
    /// Called when the user picks a tool from the selection menu.
    var onMark: ((AnnotationTool, PDFSelection) -> Void)?
    /// Called when the user taps an existing, deletable mark.
    var onTapAnnotation: ((PDFAnnotation, PDFPage) -> Void)?

    private var didInstallTap = false

    func installTapIfNeeded() {
        guard !didInstallTap else { return }
        didInstallTap = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard currentSelection != nil else { return }

        let highlightActions = AnnotationColor.allCases.map { color in
            UIAction(title: color.displayName) { [weak self] _ in
                guard let self, let selection = self.currentSelection else { return }
                self.onMark?(.highlight(color), selection)
                self.clearSelection()
            }
        }
        let highlightMenu = UIMenu(title: "Highlight",
                                   image: UIImage(systemName: "highlighter"),
                                   children: highlightActions)
        let strikeAction = UIAction(title: "Strikethrough",
                                    image: UIImage(systemName: "strikethrough")) { [weak self] _ in
            guard let self, let selection = self.currentSelection else { return }
            self.onMark?(.strikethrough, selection)
            self.clearSelection()
        }
        let group = UIMenu(title: "", options: .displayInline,
                           children: [highlightMenu, strikeAction])
        builder.insertChild(group, atEndOfMenu: .standardEdit)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let viewPoint = gesture.location(in: self)
        guard let page = page(for: viewPoint, nearest: true) else { return }
        let pagePoint = convert(viewPoint, to: page)
        guard let annotation = page.annotation(at: pagePoint),
              AnnotationFactory.isUserDeletable(annotation) else { return }
        onTapAnnotation?(annotation, page)
    }
}

extension MarkupPDFView {
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                    shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let highlightedSelections: [PDFSelection]
    let currentSelection: PDFSelection?
    /// Bumped by the parent after add/delete to force a redraw of annotations.
    let annotationRevision: Int
    /// Bumped only when a signature stamp changes — triggers a harder, tile-cache
    /// clearing reload (a custom-draw stamp paints into the cached page tile).
    let signatureRevision: Int
    let onApplyTool: (AnnotationTool, PDFSelection) -> Void
    let onRequestDelete: (PDFAnnotation, PDFPage) -> Void
    @Binding var currentPageIndex: Int

    /// Tag we attach to highlight annotations so we can remove the ones we
    /// added on the next update without disturbing any annotations that
    /// happened to be in the PDF already.
    private static let annotationUserName = DocumentSession.searchHighlightAnnotationName

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator {
        var parent: PDFKitView
        var lastSignatureRevision = 0
        init(_ parent: PDFKitView) { self.parent = parent }
        @objc func pageChanged(_ note: Notification) {
            guard let view = note.object as? PDFView,
                  let doc = view.document, let page = view.currentPage else { return }
            let idx = doc.index(for: page)
            if idx != parent.currentPageIndex { parent.currentPageIndex = idx }
        }
    }

    func makeUIView(context: Context) -> PDFView {
        let v = MarkupPDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.usePageViewController(false)
        v.installTapIfNeeded()
        NotificationCenter.default.addObserver(
            context.coordinator, selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged, object: v)
        return v
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator, name: .PDFViewPageChanged, object: view)
    }

    func updateUIView(_ view: PDFView, context: Context) {
        context.coordinator.parent = self    // keep the coordinator's binding current
        guard let view = view as? MarkupPDFView else { return }
        view.onMark = onApplyTool
        view.onTapAnnotation = onRequestDelete

        // PDFView.highlightedSelections doesn't reliably render on iOS — use
        // real PDFAnnotation highlights, which are guaranteed to draw.
        removeOurAnnotations(from: document)

        for match in highlightedSelections {
            let color: UIColor = (match == currentSelection)
                ? UIColor.systemBlue.withAlphaComponent(0.45)
                : UIColor.systemYellow.withAlphaComponent(0.45)
            addHighlight(for: match, color: color)
        }

        // PDFView doesn't automatically redraw when annotations on its
        // document change after the document was first assigned. Re-assigning
        // forces a refresh; we keep it unconditional rather than gated on
        // `view.document !== document` so highlight edits flow through.
        view.document = document

        // A removed/moved signature is a custom-draw stamp baked into PDFView's
        // cached page tile, which the reassignment above does NOT invalidate
        // (standard highlights live in an overlay layer and refresh fine). When
        // a signature actually changed, force a tile-clearing reload by nil'ing
        // the document first, then restore the viewed page so scroll doesn't jump
        // to the top. Gated so ordinary highlight edits don't pay this cost.
        if signatureRevision != context.coordinator.lastSignatureRevision {
            context.coordinator.lastSignatureRevision = signatureRevision
            let page = view.currentPage
            view.document = nil
            view.document = document
            if let page { view.go(to: page) }
        }

        if let currentSelection {
            view.go(to: currentSelection)
        }
    }

    private func removeOurAnnotations(from document: PDFDocument) {
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for annotation in page.annotations where annotation.userName == Self.annotationUserName {
                page.removeAnnotation(annotation)
            }
        }
    }

    private func addHighlight(for selection: PDFSelection, color: UIColor) {
        // selectionsByLine() splits a multi-line match into one selection per
        // line, each with a single bounding rect we can wrap in an annotation.
        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }
                let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                annotation.color = color
                annotation.userName = Self.annotationUserName
                page.addAnnotation(annotation)
            }
        }
    }
}

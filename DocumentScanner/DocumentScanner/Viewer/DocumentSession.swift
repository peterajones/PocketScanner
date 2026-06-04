import Foundation
import Observation
import PDFKit

/// Per-screen view-model owning the document the viewer is showing. Wraps
/// the file URL, the parsed PDFDocument, and the document's display name
/// (filename without extension). Saves back to disk via DocumentStorage
/// at explicit save points.
@MainActor
@Observable
final class DocumentSession {
    private(set) var url: URL
    private(set) var pdf: PDFDocument
    var displayName: String
    private(set) var conflicts: [NSFileVersion]

    /// Monotonic counter incremented whenever the PDF's page content changes.
    /// `PDFDocument` is a reference type and `DocumentMutations` mutates it in
    /// place — so `pdf`'s identity doesn't change, and `@Observable` never
    /// notifies dependent views. Views that need to react to page-list
    /// changes (e.g. `EditModeView`'s thumbnail strip) read `revision` to
    /// subscribe to it. `save()` bumps it after every persisted mutation.
    private(set) var revision: Int = 0

    private let storage: DocumentStorage

    /// Annotation `userName` that marks PDFAnnotations added by the search-highlight
    /// view layer. `save()` strips these before writing so they don't persist.
    static let searchHighlightAnnotationName = "DocumentScanner.searchHighlight"

    /// Annotation `userName` that marks PDFAnnotations the USER created
    /// (highlights / strikethroughs). These persist across save.
    static let userAnnotationName = "DocumentScanner.userAnnotation"

    enum InitError: Error { case unreadablePDF }

    init(summary: DocumentSummary, storage: DocumentStorage) throws {
        guard let pdf = PDFDocument(url: summary.url) else { throw InitError.unreadablePDF }
        self.url = summary.url
        self.pdf = pdf
        self.displayName = summary.displayName
        self.storage = storage
        self.conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: summary.url) ?? []
    }

    func resolveConflict(keeping chosen: NSFileVersion?) throws {
        // chosen == nil means "keep this device's current version" (i.e., do nothing
        // with the conflict version, just mark resolved).
        // chosen != nil means "replace with that version".
        if let chosen {
            try chosen.replaceItem(at: url, options: [])
        }
        for version in conflicts {
            version.isResolved = true
        }
        conflicts = []
        if let reloaded = PDFDocument(url: url) {
            pdf = reloaded
        }
    }

    /// Persist the current `pdf` over the current `url`. Used after edit-mode
    /// mutations or rename. Returns the (possibly new) URL.
    @discardableResult
    func save() throws -> URL {
        stripSearchHighlightAnnotations()
        let newURL = try storage.write(pdf, replacing: url, withName: displayName)
        self.url = newURL
        revision &+= 1
        return newURL
    }

    private func stripSearchHighlightAnnotations() {
        // Remove ONLY the ephemeral search highlights, identified by the tag
        // the view layer sets. Search highlights are added in-session by
        // PDFKitView and never loaded from disk, so their userName is always
        // freshly set and reliable here (the same in-session reliability
        // PDFKitView.removeOurAnnotations already depends on). User marks
        // (highlights / strikethroughs) are not search-tagged, so they survive
        // and persist into the saved PDF.
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            let toRemove = page.annotations.filter {
                $0.userName == Self.searchHighlightAnnotationName
            }
            for annotation in toRemove {
                page.removeAnnotation(annotation)
            }
        }
    }
}

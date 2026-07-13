import SwiftUI
import UniformTypeIdentifiers

/// Adds a PDF file-importer plus an error alert to a view. Shared by the library
/// root and the folder-contents screen so both offer "Import PDF" identically.
///
/// Extracting these two modifiers into a `ViewModifier` also keeps each screen's
/// `body` under SwiftUI's expression type-check ceiling.
struct ImportPDFModifier: ViewModifier {
    @Binding var isPresented: Bool
    let storage: DocumentStorage
    let onImported: () -> Void

    @State private var importError: String?

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented,
                          allowedContentTypes: [.pdf],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        _ = try PDFImporter.importPDF(from: url, using: storage)
                        onImported()
                    } catch {
                        importError = "That file isn't a readable PDF."
                    }
                case .failure:
                    importError = "Couldn't import the file."
                }
            }
            .alert("Couldn't Import", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK", role: .cancel) { importError = nil }
            } message: {
                Text(importError ?? "")
            }
    }
}

extension View {
    /// Presents a PDF picker; on success imports into `storage` and calls `onImported`.
    func importPDF(isPresented: Binding<Bool>,
                   storage: DocumentStorage,
                   onImported: @escaping () -> Void) -> some View {
        modifier(ImportPDFModifier(isPresented: isPresented,
                                   storage: storage,
                                   onImported: onImported))
    }
}

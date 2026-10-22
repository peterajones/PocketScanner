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
    @State private var progress: ImportProgress?

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented,
                          allowedContentTypes: [.pdf],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        do {
                            _ = try await PDFImporter.importPDF(from: url, using: storage) { current, total in
                                await MainActor.run { progress = ImportProgress(current: current, total: total) }
                            }
                            progress = nil
                            onImported()
                        } catch {
                            progress = nil
                            importError = "That file isn't a readable PDF."
                        }
                    }
                case .failure:
                    importError = "Couldn't import the file."
                }
            }
            .overlay {
                if let progress { ImportProgressOverlay(progress: progress) }
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

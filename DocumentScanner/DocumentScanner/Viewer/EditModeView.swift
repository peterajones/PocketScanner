import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct EditModeView: View {
    @Bindable var session: DocumentSession

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(currentPages.indices, id: \.self) { index in
                    thumbnail(at: index)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 140)
        .background(.thinMaterial)
    }

    private var currentPages: [PDFPage] {
        (0..<session.pdf.pageCount).compactMap(session.pdf.page(at:))
    }

    @ViewBuilder
    private func thumbnail(at index: Int) -> some View {
        if let page = session.pdf.page(at: index) {
            VStack(spacing: 4) {
                PageThumbnail(page: page, size: CGSize(width: 80, height: 104))
                    .draggable(IndexPayload(index: index)) {
                        PageThumbnail(page: page, size: CGSize(width: 60, height: 78))
                    }
                    .dropDestination(for: IndexPayload.self) { items, _ in
                        guard let first = items.first else { return false }
                        DocumentMutations.reorder(in: session.pdf, from: first.index, to: index)
                        _ = try? session.save()
                        return true
                    }
                Text("\(index + 1)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private struct IndexPayload: Codable, Transferable {
        let index: Int
        static var transferRepresentation: some TransferRepresentation {
            CodableRepresentation(contentType: .data)
        }
    }
}

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct EditModeView: View {
    @Bindable var session: DocumentSession
    let onEditPage: (Int) -> Void
    let onAddPages: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(currentPages.indices, id: \.self) { index in
                    thumbnail(at: index)
                }
                Button {
                    onAddPages()
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(.tint)
                            .overlay(Image(systemName: "plus").font(.title2).foregroundStyle(.tint))
                            .frame(width: 80, height: 104)
                        Text("Add").font(.caption).foregroundStyle(.tint)
                    }
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
                    .contextMenu {
                        Button(role: .destructive) {
                            deletePage(at: index)
                        } label: {
                            Label("Delete page", systemImage: "trash")
                        }
                    }
                    .onTapGesture {
                        onEditPage(index)
                    }
                Text("\(index + 1)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func deletePage(at index: Int) {
        guard session.pdf.pageCount > 1 else {
            // Last page — surface delete-whole-document via notification so
            // EditModeView doesn't need direct access to storage/onDeleted.
            NotificationCenter.default.post(name: .requestDeleteDocument, object: nil)
            return
        }
        DocumentMutations.deletePage(in: session.pdf, at: index)
        _ = try? session.save()
    }

    private struct IndexPayload: Codable, Transferable {
        let index: Int
        static var transferRepresentation: some TransferRepresentation {
            CodableRepresentation(contentType: .data)
        }
    }
}

extension Notification.Name {
    static let requestDeleteDocument = Notification.Name("requestDeleteDocument")
}

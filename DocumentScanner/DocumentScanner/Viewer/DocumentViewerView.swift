import SwiftUI
import PDFKit

struct DocumentViewerView: View {
    let summary: DocumentSummary

    var body: some View {
        PDFKitView(url: summary.url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(summary.displayName)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.usePageViewController(false)
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        view.document = PDFDocument(url: url)
    }
}

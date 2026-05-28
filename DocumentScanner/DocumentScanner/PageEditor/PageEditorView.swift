import SwiftUI
import PDFKit
import UIKit

/// Full-screen sheet for editing a single page's crop and rotation.
/// Mutates the passed-in DocumentSession on Apply and saves.
struct PageEditorView: View {
    @Bindable var session: DocumentSession
    let pageIndex: Int
    let onDismiss: () -> Void

    private let renderer = PageImageRenderer()
    private let segmenter = DocumentSegmenter()
    private let corrector = PerspectiveCorrector()
    private let ocr = OCREngine()
    private let filterEngine = ImageFilterEngine()

    @State private var pageImage: UIImage?
    @State private var quad: Quad?
    @State private var rotationQuarterTurns = 0  // 0/1/2/3 → 0°/90°/180°/270° CW
    @State private var filter: ImageFilter = .none
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showingApplyAllConfirm = false
    @State private var bulkProgress: BulkProgress?

    private struct BulkProgress: Equatable {
        let current: Int
        let total: Int
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if let pageImage, let quadBinding {
                        VStack(spacing: 8) {
                            QuadOverlay(image: displayedImage(pageImage), quad: quadBinding)
                                .padding()
                            rotationControls
                            filterControls
                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red).font(.footnote)
                            }
                        }
                    } else {
                        ProgressView("Preparing page…")
                    }
                }

                if let bulkProgress {
                    bulkProgressOverlay(bulkProgress)
                }
            }
            .navigationTitle("Edit Page \(pageIndex + 1)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }.disabled(isWorking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Apply") { Task { await applyEdit() } }
                            .disabled(quad == nil)
                    }
                }
            }
            .task { await prepare() }
            .interactiveDismissDisabled(isWorking)
            .alert("Apply \(filter.displayName) to all pages?",
                   isPresented: $showingApplyAllConfirm) {
                Button("Apply", role: .destructive) {
                    Task { await applyToAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will re-process all \(session.pdf.pageCount) pages and may take a moment.")
            }
        }
    }

    private var quadBinding: Binding<Quad>? {
        guard quad != nil else { return nil }
        return Binding(
            get: { quad ?? Quad.fullRect(in: pageImage?.size ?? .zero) },
            set: { quad = $0 }
        )
    }

    private var rotationControls: some View {
        HStack(spacing: 24) {
            Button {
                rotationQuarterTurns = (rotationQuarterTurns + 3) % 4   // counter-clockwise
            } label: {
                Image(systemName: "rotate.left").font(.title2)
            }
            Text("Rotation: \(rotationQuarterTurns * 90)°").font(.footnote).monospaced()
            Button {
                rotationQuarterTurns = (rotationQuarterTurns + 1) % 4   // clockwise
            } label: {
                Image(systemName: "rotate.right").font(.title2)
            }
        }
        .padding(.bottom, 16)
    }

    private var filterControls: some View {
        VStack(spacing: 8) {
            Picker("Filter", selection: $filter) {
                ForEach(ImageFilter.allCases) { f in
                    Text(f.displayName).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if filter != .none && session.pdf.pageCount > 1 {
                Button {
                    showingApplyAllConfirm = true
                } label: {
                    Label("Apply \(filter.displayName) to all pages",
                          systemImage: "rectangle.stack")
                        .font(.footnote)
                }
                .disabled(isWorking)
            }
        }
    }

    private func bulkProgressOverlay(_ progress: BulkProgress) -> some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: Double(progress.current), total: Double(progress.total))
                    .frame(width: 200)
                Text("Processing page \(progress.current) of \(progress.total)")
                    .font(.subheadline)
            }
            .padding(24)
            .background(.regularMaterial)
            .cornerRadius(12)
        }
    }

    private func prepare() async {
        guard let page = session.pdf.page(at: pageIndex),
              let rendered = renderer.image(from: page) else {
            errorMessage = "Couldn't render page \(pageIndex + 1)."
            return
        }
        pageImage = rendered
        quad = (try? await segmenter.detect(in: rendered)) ?? Quad.fullRect(in: rendered.size)
    }

    private func rotatedImage(_ image: UIImage) -> UIImage {
        guard rotationQuarterTurns != 0 else { return image }
        // Apply rotation to the displayed image only. The actual quad still
        // operates in the underlying image's coordinate space; the apply
        // step rotates the corrected output, not the source.
        let angle = CGFloat(rotationQuarterTurns) * .pi / 2
        let size: CGSize = (rotationQuarterTurns % 2 == 0)
            ? image.size
            : CGSize(width: image.size.height, height: image.size.width)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.cgContext.rotate(by: angle)
            image.draw(in: CGRect(x: -image.size.width / 2,
                                  y: -image.size.height / 2,
                                  width: image.size.width,
                                  height: image.size.height))
        }
    }

    private func displayedImage(_ image: UIImage) -> UIImage {
        let rotated = rotatedImage(image)
        return filterEngine.apply(filter, to: rotated) ?? rotated
    }

    private func applyEdit() async {
        isWorking = true
        defer { isWorking = false }
        guard let pageImage, let quad else { return }
        do {
            try await processAndReplaceCurrentPage(pageImage: pageImage, quad: quad)
            _ = try session.save()
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyToAll() async {
        isWorking = true
        defer {
            isWorking = false
            bulkProgress = nil
        }
        guard let pageImage, let quad else { return }
        let total = session.pdf.pageCount

        do {
            // Current page first, with its full edits.
            bulkProgress = BulkProgress(current: 1, total: total)
            try await processAndReplaceCurrentPage(pageImage: pageImage, quad: quad)

            // Then every other page, filter only.
            var done = 1
            for index in 0..<total where index != pageIndex {
                done += 1
                bulkProgress = BulkProgress(current: done, total: total)
                try await processAndReplaceFilterOnly(at: index)
            }

            _ = try session.save()
            onDismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processAndReplaceCurrentPage(pageImage: UIImage, quad: Quad) async throws {
        guard let corrected = corrector.correct(pageImage, quad: quad) else {
            throw PageEditError.cropFailed
        }
        let rotated = rotatedImage(corrected)
        let finalImage = filterEngine.apply(filter, to: rotated) ?? rotated
        let observations = (try? await ocr.recognizeText(in: finalImage)) ?? []
        let newDoc = try PDFAssembler().assemble(
            pages: [ScannedPage(image: finalImage, observations: observations)],
            createdAt: Date()
        )
        DocumentMutations.replacePage(in: session.pdf, at: pageIndex, with: newDoc)
    }

    private func processAndReplaceFilterOnly(at index: Int) async throws {
        guard let page = session.pdf.page(at: index),
              let rendered = renderer.image(from: page) else { return }
        let filtered = filterEngine.apply(filter, to: rendered) ?? rendered
        let observations = (try? await ocr.recognizeText(in: filtered)) ?? []
        let newDoc = try PDFAssembler().assemble(
            pages: [ScannedPage(image: filtered, observations: observations)],
            createdAt: Date()
        )
        DocumentMutations.replacePage(in: session.pdf, at: index, with: newDoc)
    }
}

private enum PageEditError: LocalizedError {
    case cropFailed
    var errorDescription: String? {
        switch self {
        case .cropFailed: return "Couldn't apply crop."
        }
    }
}

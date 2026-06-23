import SwiftUI

/// Scan a signature on paper → SignatureProcessor → preview on a checkerboard
/// → Save (to SignatureStore) or Rescan. Presented from Settings and from the
/// viewer's first-run. Calls `onSaved` after a successful save, `onCancel` if
/// the user backs out without saving.
struct SignatureCaptureView: View {
    let presenter: DocumentScannerPresenting
    let store: SignatureStore
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var processed: UIImage?
    @State private var showingScanner = true
    @State private var processingFailed = false

    private let processor = SignatureProcessor()

    var body: some View {
        NavigationStack {
            Group {
                if let processed {
                    VStack(spacing: 16) {
                        Text("Your signature").font(.headline)
                        CheckerboardPreview(image: processed)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .padding()
                        Text("Looks good? Save it to reuse on any document.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } else if processingFailed {
                    ContentUnavailableView("Couldn't read that",
                        systemImage: "signature",
                        description: Text("Try again on a plain, well-lit sheet with a dark pen."))
                } else {
                    ProgressView("Preparing…")
                }
            }
            .navigationTitle("Add Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if processed != nil {
                        Button("Save") { save() }
                    } else {
                        Button("Rescan") { showingScanner = true; processingFailed = false }
                    }
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                CaptureSheet(
                    presenter: presenter,
                    onFinish: { images in showingScanner = false; handleScan(images) },
                    onCancel: { showingScanner = false; if processed == nil { onCancel() } }
                )
                .ignoresSafeArea()
            }
        }
    }

    private func handleScan(_ images: [UIImage]) {
        guard let first = images.first else { processingFailed = true; return }
        if let out = processor.process(first) {
            processed = out
            processingFailed = false
        } else {
            processed = nil
            processingFailed = true
        }
    }

    private func save() {
        guard let processed else { return }
        _ = try? store.add(processed)
        onSaved()
    }
}

/// Renders an image over a checkerboard so transparency is visible.
private struct CheckerboardPreview: View {
    let image: UIImage
    var body: some View {
        ZStack {
            Checkerboard().fill(Color(.systemGray5))
            Image(uiImage: image).resizable().scaledToFit().padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.systemGray4)))
    }
}

private struct Checkerboard: Shape {
    var square: CGFloat = 10
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cols = Int(rect.width / square) + 1, rows = Int(rect.height / square) + 1
        for r in 0..<rows {
            for c in 0..<cols where (r + c) % 2 == 0 {
                p.addRect(CGRect(x: CGFloat(c) * square, y: CGFloat(r) * square,
                                 width: square, height: square))
            }
        }
        return p
    }
}

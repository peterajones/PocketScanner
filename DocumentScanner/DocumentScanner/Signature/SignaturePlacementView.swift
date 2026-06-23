import SwiftUI
import PDFKit

/// Overlays the saved signature on a page image; the user drags and pinches it
/// into position. `onPlace` receives the final signature rect in the page's
/// PDF coordinate space (origin bottom-left); `onCancel` discards.
struct SignaturePlacementView: View {
    let pageImage: UIImage
    let signature: UIImage
    let pageBounds: CGRect          // page.bounds(for: .mediaBox)
    var initialPageRect: CGRect? = nil   // seed position/scale when MOVING an existing signature
    let onPlace: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var center: CGPoint = .zero
    @State private var scale: CGFloat = 1
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let fit = aspectFit(pageImage.size, in: geo.size)
                ZStack {
                    Image(uiImage: pageImage).resizable().scaledToFit()
                    let sigSize = signatureSize(in: fit.size)
                    Image(uiImage: signature)
                        .resizable().scaledToFit()
                        .frame(width: sigSize.width * scale * pinch,
                               height: sigSize.height * scale * pinch)
                        .position(x: center.x + dragOffset.width,
                                  y: center.y + dragOffset.height)
                        .gesture(
                            DragGesture().updating($dragOffset) { v, s, _ in s = v.translation }
                                .onEnded { v in center.x += v.translation.width; center.y += v.translation.height }
                        )
                        .simultaneousGesture(
                            MagnificationGesture().updating($pinch) { v, s, _ in s = v }
                                .onEnded { v in scale *= v }
                        )
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .onAppear { seedPosition(in: geo.size) }
                .onChange(of: geo.size) { _, newSize in seedPosition(in: newSize) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onCancel() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { onPlace(pageRect(in: geo.size)) }
                    }
                }
            }
            .navigationTitle("Place Signature")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func pageRect(in container: CGSize) -> CGRect {
        let fit = aspectFit(pageImage.size, in: container)
        let sigSize = signatureSize(in: fit.size)
        let w = sigSize.width * scale, h = sigSize.height * scale
        let originView = CGPoint(x: center.x - w/2, y: center.y - h/2)
        let lx = (originView.x - fit.origin.x), ly = (originView.y - fit.origin.y)
        let nx = lx / fit.size.width, ny = ly / fit.size.height
        let nw = w / fit.size.width, nh = h / fit.size.height
        let px = pageBounds.minX + nx * pageBounds.width
        let pw = nw * pageBounds.width
        let ph = nh * pageBounds.height
        let py = pageBounds.minY + (1 - ny - nh) * pageBounds.height
        return CGRect(x: px, y: py, width: pw, height: ph)
    }

    /// Seed center/scale. Always start centered in the fitted page (so the
    /// signature can't open under the nav bar / off-screen); when moving an
    /// existing signature, preserve its *size* (derive scale from the original
    /// rect) but not its position.
    private func seedPosition(in container: CGSize) {
        // Only seed once, and only when the geometry is real — an early
        // .onAppear can fire with a .zero size, which would otherwise lock the
        // signature at the top-left corner.
        guard center == .zero, container.width > 0, container.height > 0 else { return }
        let fit = aspectFit(pageImage.size, in: container)
        center = CGPoint(x: fit.origin.x + fit.size.width / 2,
                         y: fit.origin.y + fit.size.height / 2)
        if let r = initialPageRect {
            let vw = (r.width / pageBounds.width) * fit.size.width
            let baseW = signatureSize(in: fit.size).width
            scale = baseW > 0 ? vw / baseW : 1
        }
    }

    private func signatureSize(in fitted: CGSize) -> CGSize {
        let targetW = fitted.width * 0.4
        let aspect = signature.size.height / max(signature.size.width, 1)
        return CGSize(width: targetW, height: targetW * aspect)
    }

    private func aspectFit(_ image: CGSize, in container: CGSize) -> CGRect {
        let s = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * s, height: image.height * s)
        return CGRect(x: (container.width - size.width)/2,
                      y: (container.height - size.height)/2,
                      width: size.width, height: size.height)
    }
}

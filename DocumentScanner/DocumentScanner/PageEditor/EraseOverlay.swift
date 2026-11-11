import SwiftUI

/// Erase mode's canvas: the page as it will be saved, the boxes marked so far, and a
/// drag that draws a new one. Same fit geometry as `QuadOverlay`, with the page inset
/// by `margin` and the drag live across the margin too: the natural way to box a
/// staple hole is to start just outside the page corner and drag inward.
struct EraseOverlay: View {
    let image: UIImage
    let rects: [CGRect]
    let onAdd: (CGRect) -> Void

    private let margin: CGFloat = 16

    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let imageSize = image.size
            let scale = min((geo.size.width - 2 * margin) / imageSize.width,
                            (geo.size.height - 2 * margin) / imageSize.height)
            let shown = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            let offset = CGPoint(x: (geo.size.width - shown.width) / 2,
                                 y: (geo.size.height - shown.height) / 2)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: shown.width, height: shown.height)
                    .offset(x: offset.x, y: offset.y)

                ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                    box(CGRect(x: offset.x + rect.minX * scale, y: offset.y + rect.minY * scale,
                               width: rect.width * scale, height: rect.height * scale))
                }

                if let dragStart, let dragEnd {
                    box(CGRect(x: min(dragStart.x, dragEnd.x), y: min(dragStart.y, dragEnd.y),
                               width: abs(dragEnd.x - dragStart.x), height: abs(dragEnd.y - dragStart.y)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragStart = value.startLocation
                        dragEnd = value.location
                    }
                    .onEnded { value in
                        if scale > 0,
                           let rect = EraseSelection.imageRect(from: value.startLocation, to: value.location,
                                                               scale: scale, offset: offset,
                                                               imageSize: imageSize) {
                            onAdd(rect)
                        }
                        dragStart = nil
                        dragEnd = nil
                    }
            )
        }
    }

    private func box(_ frame: CGRect) -> some View {
        Rectangle()
            .fill(Color.red.opacity(0.18))
            .overlay(Rectangle().stroke(Color.red, lineWidth: 2))
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .allowsHitTesting(false)
    }
}

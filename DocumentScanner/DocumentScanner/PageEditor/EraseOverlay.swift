import SwiftUI

/// Erase mode's canvas: the page as it will be saved, the boxes marked so far, and a
/// drag that draws a new one. Uses the same fit geometry as `QuadOverlay`.
struct EraseOverlay: View {
    let image: UIImage
    let rects: [CGRect]
    let onAdd: (CGRect) -> Void

    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let imageSize = image.size
            let scale = min(geo.size.width / imageSize.width, geo.size.height / imageSize.height)
            let offset = CGPoint(x: (geo.size.width - imageSize.width * scale) / 2,
                                 y: (geo.size.height - imageSize.height * scale) / 2)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                ForEach(Array(rects.enumerated()), id: \.offset) { _, rect in
                    box(CGRect(x: offset.x + rect.minX * scale, y: offset.y + rect.minY * scale,
                               width: rect.width * scale, height: rect.height * scale))
                }

                if let dragStart, let dragEnd {
                    box(CGRect(x: min(dragStart.x, dragEnd.x), y: min(dragStart.y, dragEnd.y),
                               width: abs(dragEnd.x - dragStart.x), height: abs(dragEnd.y - dragStart.y)))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragStart = value.startLocation
                        dragEnd = value.location
                    }
                    .onEnded { value in
                        if let rect = EraseSelection.imageRect(from: value.startLocation, to: value.location,
                                                               scale: scale, offset: offset,
                                                               imageSize: imageSize) {
                            onAdd(rect)
                        }
                        dragStart = nil
                        dragEnd = nil
                    }
            )
        }
        .aspectRatio(image.size, contentMode: .fit)
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

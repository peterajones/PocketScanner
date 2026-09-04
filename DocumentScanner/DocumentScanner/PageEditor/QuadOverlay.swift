import SwiftUI

struct QuadOverlay: View {
    let image: UIImage
    @Binding var quad: Quad

    /// Visual size of a corner handle. The TOUCH target is `hitSize`, which is larger:
    /// Apple's minimum is 44pt and these were 24pt with no expanded hit area, which is
    /// most of why adjusting a crop felt fiddly.
    private let handleSize: CGFloat = 24
    private let hitSize: CGFloat = 44

    /// Below this on-screen length an edge is too short to host a handle without colliding
    /// with the corners either side of it.
    private let minimumEdgeLengthForHandle: CGFloat = 80

    /// Where a drag began, so movement is RELATIVE. Previously a handle jumped to the
    /// finger's centre on touch-down, which made small adjustments impossible: you could
    /// re-place a corner but never nudge one.
    @State private var dragStart: Quad?

    var body: some View {
        GeometryReader { geo in
            let imageSize = image.size
            let viewSize = geo.size
            let scale = min(viewSize.width / imageSize.width,
                            viewSize.height / imageSize.height)
            let displayedSize = CGSize(width: imageSize.width * scale,
                                       height: imageSize.height * scale)
            let offset = CGPoint(x: (viewSize.width - displayedSize.width) / 2,
                                 y: (viewSize.height - displayedSize.height) / 2)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                Path { path in
                    let pts = quad.corners.map { screenPoint($0, scale: scale, offset: offset) }
                    path.move(to: pts[0])
                    path.addLine(to: pts[1])
                    path.addLine(to: pts[2])
                    path.addLine(to: pts[3])
                    path.closeSubpath()
                }
                .stroke(Color.accentColor, lineWidth: 2)

                ForEach(Array(Quad.Edge.allCases.enumerated()), id: \.offset) { _, edge in
                    edgeHandle(edge, scale: scale, offset: offset, imageSize: imageSize)
                }

                cornerHandle(\.topLeft, scale: scale, offset: offset, imageSize: imageSize)
                cornerHandle(\.topRight, scale: scale, offset: offset, imageSize: imageSize)
                cornerHandle(\.bottomRight, scale: scale, offset: offset, imageSize: imageSize)
                cornerHandle(\.bottomLeft, scale: scale, offset: offset, imageSize: imageSize)
            }
        }
        .aspectRatio(image.size, contentMode: .fit)
    }

    private func screenPoint(_ p: CGPoint, scale: CGFloat, offset: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + p.x * scale, y: offset.y + p.y * scale)
    }

    // MARK: - Corners

    @ViewBuilder
    private func cornerHandle(_ corner: WritableKeyPath<Quad, CGPoint>,
                              scale: CGFloat,
                              offset: CGPoint,
                              imageSize: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
            .shadow(radius: 2)
            // A 44pt target around a 24pt dot: the handle looks the same, but is
            // catchable. contentShape is what makes the invisible area draggable.
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
            .position(screenPoint(quad[keyPath: corner], scale: scale, offset: offset))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let start = dragStart ?? quad
                        if dragStart == nil { dragStart = quad }
                        // Relative: translation from where the drag began, converted to
                        // image space. A 3pt nudge moves the corner 3pt.
                        var next = start
                        next[keyPath: corner] = CGPoint(
                            x: start[keyPath: corner].x + value.translation.width / scale,
                            y: start[keyPath: corner].y + value.translation.height / scale
                        )
                        quad = next.clamped(to: imageSize)
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }

    // MARK: - Edges

    /// A capsule at the midpoint of each edge, aligned with it — visually distinct from a
    /// corner dot so it reads as "drag this edge", not "another corner".
    ///
    /// Dragging an edge moves both its corners equally, so it trims a margin without
    /// introducing skew. That is the common case: shaving a strip of desk off one side of
    /// a scan that is otherwise square.
    @ViewBuilder
    private func edgeHandle(_ edge: Quad.Edge,
                            scale: CGFloat,
                            offset: CGPoint,
                            imageSize: CGSize) -> some View {
        let onScreenLength = quad.length(of: edge) * scale
        if onScreenLength >= minimumEdgeLengthForHandle {
            let mid = screenPoint(quad.midpoint(of: edge), scale: scale, offset: offset)
            let isHorizontal = (edge == .top || edge == .bottom)

            // Deliberately lighter than a corner dot: thinner, shorter and a finer stroke.
            // Eight handles on one image reads as busy, and edge handles are the secondary
            // control — the visual weight should say so. The 44pt touch target below is
            // unchanged, so this costs nothing in grabbability.
            Capsule()
                .fill(Color.white)
                .frame(width: isHorizontal ? 28 : 6,
                       height: isHorizontal ? 6 : 28)
                .overlay(Capsule().stroke(Color.accentColor, lineWidth: 1.5))
                .shadow(radius: 1)
                .frame(width: hitSize, height: hitSize)
                .contentShape(Rectangle())
                .position(mid)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let start = dragStart ?? quad
                            if dragStart == nil { dragStart = quad }
                            let delta = CGPoint(x: value.translation.width / scale,
                                                y: value.translation.height / scale)
                            quad = start.moving(edge, by: delta).clamped(to: imageSize)
                        }
                        .onEnded { _ in dragStart = nil }
                )
        }
    }
}

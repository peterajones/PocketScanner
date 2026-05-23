import CoreGraphics

/// Four-corner shape in image pixel coordinates (origin top-left, y-down).
/// Corner naming uses the document's own orientation, not the screen's:
/// `topLeft` is the upper-left when the document is shown right-side-up.
struct Quad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    static func fullRect(in size: CGSize) -> Quad {
        Quad(
            topLeft: .zero,
            topRight: CGPoint(x: size.width, y: 0),
            bottomRight: CGPoint(x: size.width, y: size.height),
            bottomLeft: CGPoint(x: 0, y: size.height)
        )
    }

    /// Returns a copy with each corner clamped into the given bounds.
    func clamped(to size: CGSize) -> Quad {
        Quad(
            topLeft: Self.clamp(topLeft, to: size),
            topRight: Self.clamp(topRight, to: size),
            bottomRight: Self.clamp(bottomRight, to: size),
            bottomLeft: Self.clamp(bottomLeft, to: size)
        )
    }

    private static func clamp(_ point: CGPoint, to size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(0, point.x), size.width),
            y: min(max(0, point.y), size.height)
        )
    }
}

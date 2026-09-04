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

    /// One side of the quad, named by the document's own orientation.
    enum Edge: CaseIterable {
        case top, right, bottom, left
    }

    /// The two corners an edge joins, in order.
    private func endpoints(of edge: Edge) -> (WritableKeyPath<Quad, CGPoint>, WritableKeyPath<Quad, CGPoint>) {
        switch edge {
        case .top:    return (\.topLeft, \.topRight)
        case .right:  return (\.topRight, \.bottomRight)
        case .bottom: return (\.bottomRight, \.bottomLeft)
        case .left:   return (\.bottomLeft, \.topLeft)
        }
    }

    func midpoint(of edge: Edge) -> CGPoint {
        let (a, b) = endpoints(of: edge)
        return CGPoint(x: (self[keyPath: a].x + self[keyPath: b].x) / 2,
                       y: (self[keyPath: a].y + self[keyPath: b].y) / 2)
    }

    func length(of edge: Edge) -> CGFloat {
        let (a, b) = endpoints(of: edge)
        return hypot(self[keyPath: b].x - self[keyPath: a].x,
                     self[keyPath: b].y - self[keyPath: a].y)
    }

    /// Moves one edge by the **perpendicular component** of `delta`, shifting both of its
    /// corners equally.
    ///
    /// Two properties follow, and both are the reason edge handles exist:
    ///
    /// - **A square document stays square.** Both corners move by an identical vector, so the
    ///   edge's angle and length are unchanged. Dragging corners individually cannot promise
    ///   that — it is how a scan that needed no deskewing acquires skew.
    /// - **The edge moves in the direction it faces**, not simply up/down or left/right. On a
    ///   skewed scan the top edge is not horizontal; moving it vertically would change its
    ///   angle. Projecting onto the perpendicular keeps the shape and only shifts the edge.
    ///
    /// A drag *along* the edge is therefore a no-op, which is correct: sliding sideways
    /// across the top of a page should not trim it.
    func moving(_ edge: Edge, by delta: CGPoint) -> Quad {
        let (a, b) = endpoints(of: edge)
        let from = self[keyPath: a], to = self[keyPath: b]

        // Unit vector along the edge. A degenerate (zero-length) edge has no meaningful
        // perpendicular, so leave the quad untouched rather than dividing by zero.
        let ex = to.x - from.x, ey = to.y - from.y
        let len = hypot(ex, ey)
        guard len > 0 else { return self }
        let ux = ex / len, uy = ey / len

        // Perpendicular to the edge, and the signed distance the drag covers along it.
        let px = -uy, py = ux
        let distance = delta.x * px + delta.y * py

        var next = self
        next[keyPath: a] = CGPoint(x: from.x + px * distance, y: from.y + py * distance)
        next[keyPath: b] = CGPoint(x: to.x + px * distance, y: to.y + py * distance)
        return next
    }

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

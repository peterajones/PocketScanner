import CoreGraphics

/// The boxes marked for erasing on one page, in the straightened (corrected and
/// rotated) image's pixel space. Nothing is erased until the page editor's Apply.
struct EraseSelection: Equatable {
    private(set) var rects: [CGRect] = []

    var count: Int { rects.count }
    var isEmpty: Bool { rects.isEmpty }

    mutating func add(_ imageRect: CGRect) { rects.append(imageRect) }

    /// Removes the most recent box; does nothing when there are none.
    mutating func undo() { _ = rects.popLast() }

    mutating func clear() { rects.removeAll() }

    /// A drag shorter than this on screen, in either direction, is a tap or a slip.
    static let minimumDragPoints: CGFloat = 8

    /// Maps a drag between two view points to an image rect, using the same fit
    /// geometry as `QuadOverlay` (image = (view − offset) / scale). The result is
    /// normalised (any drag direction) and clipped to the image; nil when the drag is
    /// too short on screen or lies entirely off the image.
    static func imageRect(from start: CGPoint, to end: CGPoint,
                          scale: CGFloat, offset: CGPoint, imageSize: CGSize) -> CGRect? {
        guard scale > 0,
              abs(end.x - start.x) >= minimumDragPoints,
              abs(end.y - start.y) >= minimumDragPoints else { return nil }
        func image(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x - offset.x) / scale, y: (p.y - offset.y) / scale)
        }
        let a = image(start), b = image(end)
        let rect = CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                          width: abs(b.x - a.x), height: abs(b.y - a.y))
        let clipped = rect.intersection(CGRect(origin: .zero, size: imageSize))
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }
}

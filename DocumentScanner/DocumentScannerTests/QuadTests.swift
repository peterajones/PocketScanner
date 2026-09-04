import XCTest
import CoreGraphics
@testable import DocumentScanner

final class QuadTests: XCTestCase {

    func test_init_storesFourCorners() {
        let q = Quad(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 100, y: 0),
            bottomRight: CGPoint(x: 100, y: 200),
            bottomLeft: CGPoint(x: 0, y: 200)
        )
        XCTAssertEqual(q.topLeft, CGPoint(x: 0, y: 0))
        XCTAssertEqual(q.topRight, CGPoint(x: 100, y: 0))
        XCTAssertEqual(q.bottomRight, CGPoint(x: 100, y: 200))
        XCTAssertEqual(q.bottomLeft, CGPoint(x: 0, y: 200))
    }

    func test_fullRect_fillsBounds() {
        let bounds = CGSize(width: 800, height: 600)
        let q = Quad.fullRect(in: bounds)
        XCTAssertEqual(q.topLeft, CGPoint(x: 0, y: 0))
        XCTAssertEqual(q.topRight, CGPoint(x: 800, y: 0))
        XCTAssertEqual(q.bottomRight, CGPoint(x: 800, y: 600))
        XCTAssertEqual(q.bottomLeft, CGPoint(x: 0, y: 600))
    }

    func test_clamped_movesPointsInsideBounds() {
        let q = Quad(
            topLeft: CGPoint(x: -50, y: -50),
            topRight: CGPoint(x: 9999, y: 0),
            bottomRight: CGPoint(x: 9999, y: 9999),
            bottomLeft: CGPoint(x: 0, y: 9999)
        )
        let bounds = CGSize(width: 800, height: 600)
        let clamped = q.clamped(to: bounds)
        XCTAssertEqual(clamped.topLeft, CGPoint(x: 0, y: 0))
        XCTAssertEqual(clamped.topRight, CGPoint(x: 800, y: 0))
        XCTAssertEqual(clamped.bottomRight, CGPoint(x: 800, y: 600))
        XCTAssertEqual(clamped.bottomLeft, CGPoint(x: 0, y: 600))
    }

    func test_corners_returnsAllFourInTRBLOrder() {
        let q = Quad.fullRect(in: CGSize(width: 100, height: 100))
        XCTAssertEqual(q.corners, [q.topLeft, q.topRight, q.bottomRight, q.bottomLeft])
    }
    // MARK: - Edge dragging

    private func square(_ side: CGFloat = 100) -> Quad {
        Quad(topLeft: .zero,
             topRight: CGPoint(x: side, y: 0),
             bottomRight: CGPoint(x: side, y: side),
             bottomLeft: CGPoint(x: 0, y: side))
    }

    /// The whole point of edge handles: both corners of the edge move by the SAME amount,
    /// so a document that was square stays square. Corner dragging cannot promise that.
    func test_movingTopEdge_movesBothTopCornersEqually() {
        let moved = square().moving(.top, by: CGPoint(x: 0, y: 10))
        XCTAssertEqual(moved.topLeft.y, 10, accuracy: 0.01)
        XCTAssertEqual(moved.topRight.y, 10, accuracy: 0.01)
        XCTAssertEqual(moved.topLeft.x, 0, accuracy: 0.01, "x drifted")
        XCTAssertEqual(moved.topRight.x, 100, accuracy: 0.01, "x drifted")
    }

    func test_movingTopEdge_leavesTheBottomAlone() {
        let original = square()
        let moved = original.moving(.top, by: CGPoint(x: 0, y: 10))
        XCTAssertEqual(moved.bottomLeft, original.bottomLeft)
        XCTAssertEqual(moved.bottomRight, original.bottomRight)
    }

    func test_movingLeftEdge_movesBothLeftCornersEqually() {
        let moved = square().moving(.left, by: CGPoint(x: 8, y: 0))
        XCTAssertEqual(moved.topLeft.x, 8, accuracy: 0.01)
        XCTAssertEqual(moved.bottomLeft.x, 8, accuracy: 0.01)
        XCTAssertEqual(moved.topRight.x, 100, accuracy: 0.01)
    }

    /// Perpendicular projection: a drag along the edge's own direction does nothing.
    /// Sliding a finger sideways along the top edge should not move it up or down.
    func test_draggingAlongAnEdgeDoesNotMoveIt() {
        let original = square()
        let moved = original.moving(.top, by: CGPoint(x: 25, y: 0))
        XCTAssertEqual(moved, original, "a drag parallel to the edge must be a no-op")
    }

    /// Only the perpendicular COMPONENT counts, so a diagonal drag moves the edge by the
    /// part that faces outward and ignores the rest.
    func test_diagonalDragUsesOnlyThePerpendicularComponent() {
        let moved = square().moving(.top, by: CGPoint(x: 40, y: 10))
        XCTAssertEqual(moved.topLeft.y, 10, accuracy: 0.01)
        XCTAssertEqual(moved.topLeft.x, 0, accuracy: 0.01, "parallel component leaked in")
    }

    /// On a skewed scan the top edge is not horizontal. The edge must move in the direction
    /// it FACES, not simply vertically, or dragging it introduces skew.
    func test_skewedEdgeMovesPerpendicularToItself() {
        let skewed = Quad(topLeft: CGPoint(x: 0, y: 0),
                          topRight: CGPoint(x: 100, y: 20),   // top edge slopes down
                          bottomRight: CGPoint(x: 100, y: 120),
                          bottomLeft: CGPoint(x: 0, y: 100))
        let moved = skewed.moving(.top, by: CGPoint(x: 0, y: 10))

        let beforeSlope = skewed.topRight.y - skewed.topLeft.y
        let afterSlope = moved.topRight.y - moved.topLeft.y
        XCTAssertEqual(afterSlope, beforeSlope, accuracy: 0.01, "edge angle changed")

        let dx = moved.topLeft.x - skewed.topLeft.x
        let dy = moved.topLeft.y - skewed.topLeft.y
        XCTAssertGreaterThan(dy, 0, "did not move inward")
        XCTAssertLessThan(dx, 0, "expected a perpendicular move, not a purely vertical one")
    }

    func test_movingAnEdgeByZeroChangesNothing() {
        let original = square()
        for edge in Quad.Edge.allCases {
            XCTAssertEqual(original.moving(edge, by: .zero), original, "\(edge) moved on a zero drag")
        }
    }

    func test_everyEdgeMovesExactlyItsTwoCorners() {
        let original = square()
        let expected: [Quad.Edge: Set<CGPoint>] = [
            .top:    [original.topLeft, original.topRight],
            .right:  [original.topRight, original.bottomRight],
            .bottom: [original.bottomRight, original.bottomLeft],
            .left:   [original.bottomLeft, original.topLeft],
        ]
        for (edge, shouldMove) in expected {
            let moved = original.moving(edge, by: CGPoint(x: 5, y: 5))
            let pairs = zip(original.corners, moved.corners)
            for (before, after) in pairs {
                if shouldMove.contains(before) {
                    XCTAssertNotEqual(before, after, "\(edge): a corner on the edge did not move")
                } else {
                    XCTAssertEqual(before, after, "\(edge): a corner off the edge moved")
                }
            }
        }
    }

    // MARK: - Edge midpoints (where the handles are drawn)

    func test_midpointsSitHalfwayAlongEachEdge() {
        let q = square()
        XCTAssertEqual(q.midpoint(of: .top), CGPoint(x: 50, y: 0))
        XCTAssertEqual(q.midpoint(of: .right), CGPoint(x: 100, y: 50))
        XCTAssertEqual(q.midpoint(of: .bottom), CGPoint(x: 50, y: 100))
        XCTAssertEqual(q.midpoint(of: .left), CGPoint(x: 0, y: 50))
    }

    func test_edgeLengthIsMeasuredCorrectly() {
        let q = square(100)
        for edge in Quad.Edge.allCases {
            XCTAssertEqual(q.length(of: edge), 100, accuracy: 0.01)
        }
    }

}

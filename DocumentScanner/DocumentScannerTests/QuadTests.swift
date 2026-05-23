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
}

import XCTest
import UIKit
@testable import DocumentScanner

final class PerspectiveCorrectorTests: XCTestCase {

    func test_correct_returnsImageWithReasonableDimensions() throws {
        // 200×300 source, quad covering the top half → expected ~200×150 output.
        let source = whiteImage(size: CGSize(width: 200, height: 300))
        let quad = Quad(
            topLeft: CGPoint(x: 0, y: 0),
            topRight: CGPoint(x: 200, y: 0),
            bottomRight: CGPoint(x: 200, y: 150),
            bottomLeft: CGPoint(x: 0, y: 150)
        )
        let corrected = try XCTUnwrap(PerspectiveCorrector().correct(source, quad: quad))
        XCTAssertEqual(corrected.size.width, 200, accuracy: 2)
        XCTAssertEqual(corrected.size.height, 150, accuracy: 2)
    }

    func test_correct_fullRectQuadReturnsImageOfOriginalSize() throws {
        let source = whiteImage(size: CGSize(width: 400, height: 600))
        let quad = Quad.fullRect(in: source.size)
        let corrected = try XCTUnwrap(PerspectiveCorrector().correct(source, quad: quad))
        XCTAssertEqual(corrected.size.width, 400, accuracy: 2)
        XCTAssertEqual(corrected.size.height, 600, accuracy: 2)
    }

    // MARK: - Helpers

    private func whiteImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }
    }
}

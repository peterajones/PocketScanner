import XCTest
import UIKit
@testable import DocumentScanner

final class ImageFilterTests: XCTestCase {

    func test_none_returnsSameDimensions() throws {
        let source = colorImage(width: 100, height: 200)
        let result = try XCTUnwrap(ImageFilterEngine().apply(.none, to: source))
        XCTAssertEqual(result.size.width, 100, accuracy: 1)
        XCTAssertEqual(result.size.height, 200, accuracy: 1)
    }

    func test_greyscale_returnsSameDimensions() throws {
        let source = colorImage(width: 100, height: 100)
        let result = try XCTUnwrap(ImageFilterEngine().apply(.greyscale, to: source))
        XCTAssertEqual(result.size.width, 100, accuracy: 1)
        XCTAssertEqual(result.size.height, 100, accuracy: 1)
    }

    func test_blackAndWhite_returnsSameDimensions() throws {
        let source = colorImage(width: 100, height: 100)
        let result = try XCTUnwrap(ImageFilterEngine().apply(.blackAndWhite, to: source))
        XCTAssertEqual(result.size.width, 100, accuracy: 1)
        XCTAssertEqual(result.size.height, 100, accuracy: 1)
    }

    func test_photo_returnsSameDimensions() throws {
        let source = colorImage(width: 100, height: 100)
        let result = try XCTUnwrap(ImageFilterEngine().apply(.photo, to: source))
        XCTAssertEqual(result.size.width, 100, accuracy: 1)
        XCTAssertEqual(result.size.height, 100, accuracy: 1)
    }

    // MARK: - Helpers

    private func colorImage(width: CGFloat, height: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { _ in
            UIColor.red.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: height))
            UIColor.blue.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width / 2, height: height / 2))
        }
    }
}

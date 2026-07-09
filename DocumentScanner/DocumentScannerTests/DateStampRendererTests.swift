import XCTest
import UIKit
@testable import DocumentScanner

final class DateStampRendererTests: XCTestCase {

    func test_image_hasPositiveSize_andCGImage() {
        let img = DateStampRenderer.image(for: "2026-07-09")
        XCTAssertGreaterThan(img.size.width, 0)
        XCTAssertGreaterThan(img.size.height, 0)
        XCTAssertNotNil(img.cgImage)
    }

    func test_longerText_isWider() {
        let short = DateStampRenderer.image(for: "1")
        let long = DateStampRenderer.image(for: "September 30, 2026")
        XCTAssertGreaterThan(long.size.width, short.size.width,
                             "wider text produces a wider image")
    }
}

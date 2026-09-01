import XCTest
@testable import DocumentScanner

final class PaperSizeTests: XCTestCase {

    // MARK: - .auto

    func test_auto_normalisesLongEdgeTo11Inches() {
        let size = PaperSize.auto.pageSize(forImage: CGSize(width: 2100, height: 2800))
        XCTAssertEqual(size.height, 792, accuracy: 0.5, "long edge should be 11in = 792pt")
    }

    func test_auto_preservesAspectExactly() {
        let image = CGSize(width: 2100, height: 2800)
        let size = PaperSize.auto.pageSize(forImage: image)
        XCTAssertEqual(size.width / size.height,
                       image.width / image.height,
                       accuracy: 0.0001,
                       "aspect must survive untouched — the whole point of .auto")
    }

    /// The case that motivated all of this: a well-cropped Letter scan should land on
    /// something a normal PDF reader treats as a Letter page.
    func test_auto_letterShapedScanLandsNearTrueLetter() {
        let size = PaperSize.auto.pageSize(forImage: CGSize(width: 1700, height: 2200))
        XCTAssertEqual(size.width, 612, accuracy: 10)
        XCTAssertEqual(size.height, 792, accuracy: 1)
    }

    /// A till receipt is not Letter-shaped and must not be forced into it.
    func test_auto_receiptStaysTallAndNarrow() {
        let size = PaperSize.auto.pageSize(forImage: CGSize(width: 800, height: 2400))
        XCTAssertEqual(size.height, 792, accuracy: 0.5)
        XCTAssertEqual(size.width, 264, accuracy: 1, "1:3 receipt stays 1:3")
    }

    func test_auto_landscapeNormalisesTheWidth() {
        let size = PaperSize.auto.pageSize(forImage: CGSize(width: 2800, height: 2100))
        XCTAssertEqual(size.width, 792, accuracy: 0.5, "long edge is the width when landscape")
        XCTAssertEqual(size.height, 594, accuracy: 1)
    }

    // MARK: - Fixed sizes

    func test_usLetter_isExactlyLetter_regardlessOfImageProportions() {
        for image in [CGSize(width: 1700, height: 2200),   // letter-ish
                      CGSize(width: 800, height: 2400),    // receipt
                      CGSize(width: 2000, height: 2000)] { // square
            let size = PaperSize.usLetter.pageSize(forImage: image)
            XCTAssertEqual(size.width, 612, accuracy: 0.01)
            XCTAssertEqual(size.height, 792, accuracy: 0.01)
        }
    }

    func test_a4_isExactlyA4() {
        let size = PaperSize.a4.pageSize(forImage: CGSize(width: 1700, height: 2400))
        XCTAssertEqual(size.width, 595, accuracy: 0.01)
        XCTAssertEqual(size.height, 842, accuracy: 0.01)
    }

    func test_fixedSizes_rotateForLandscapeScans() {
        let letter = PaperSize.usLetter.pageSize(forImage: CGSize(width: 2200, height: 1700))
        XCTAssertEqual(letter.width, 792, accuracy: 0.01, "landscape scan gets a landscape page")
        XCTAssertEqual(letter.height, 612, accuracy: 0.01)

        let a4 = PaperSize.a4.pageSize(forImage: CGSize(width: 2400, height: 1700))
        XCTAssertEqual(a4.width, 842, accuracy: 0.01)
        XCTAssertEqual(a4.height, 595, accuracy: 0.01)
    }

    func test_squareImageIsTreatedAsPortrait() {
        let size = PaperSize.usLetter.pageSize(forImage: CGSize(width: 2000, height: 2000))
        XCTAssertEqual(size.height, 792, accuracy: 0.01, "a tie is not landscape")
    }

    // MARK: - Degenerate input

    func test_zeroSizedImageDoesNotProduceAZeroOrNaNPage() {
        for paper in PaperSize.allCases {
            let size = paper.pageSize(forImage: .zero)
            XCTAssertGreaterThan(size.width, 0, "\(paper) produced a non-positive width")
            XCTAssertGreaterThan(size.height, 0, "\(paper) produced a non-positive height")
            XCTAssertFalse(size.width.isNaN || size.height.isNaN, "\(paper) produced NaN")
        }
    }

    // MARK: - Settings round-trip

    func test_allCasesRoundTripThroughRawValue() {
        for paper in PaperSize.allCases {
            XCTAssertEqual(PaperSize(rawValue: paper.rawValue), paper)
        }
    }

    /// The shipped default. `.auto` keeps the proportions users already get, so an
    /// upgrade changes a scan's SIZE (the bug) without changing its SHAPE.
    func test_shippedDefaultIsAuto() {
        XCTAssertEqual(PaperSize(rawValue: "auto"), .auto)
    }

    func test_displayNamesAreNonEmptyAndDistinct() {
        let names = PaperSize.allCases.map(\.displayName)
        XCTAssertFalse(names.contains(where: \.isEmpty))
        XCTAssertEqual(Set(names).count, names.count)
    }
}

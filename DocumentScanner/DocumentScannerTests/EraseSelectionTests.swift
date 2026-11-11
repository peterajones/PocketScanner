import XCTest
@testable import DocumentScanner

final class EraseSelectionTests: XCTestCase {

    private let first = CGRect(x: 1, y: 2, width: 30, height: 40)
    private let second = CGRect(x: 50, y: 60, width: 10, height: 10)

    func test_add_undo_clear() {
        var selection = EraseSelection()
        selection.add(first)
        selection.add(second)
        XCTAssertEqual(selection.count, 2)
        selection.undo()
        XCTAssertEqual(selection.rects, [first])
        selection.clear()
        XCTAssertTrue(selection.isEmpty)
    }

    func test_undo_whenEmpty_doesNothing() {
        var selection = EraseSelection()
        selection.undo()
        XCTAssertTrue(selection.isEmpty)
    }

    func test_imageRect_mapsViewToImage() {
        let rect = EraseSelection.imageRect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 60, y: 70),
                                            scale: 0.5, offset: CGPoint(x: 10, y: 20),
                                            imageSize: CGSize(width: 400, height: 400))
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func test_imageRect_reversedDrag_isNormalised() {
        let rect = EraseSelection.imageRect(from: CGPoint(x: 60, y: 70), to: CGPoint(x: 10, y: 20),
                                            scale: 0.5, offset: CGPoint(x: 10, y: 20),
                                            imageSize: CGSize(width: 400, height: 400))
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    func test_imageRect_dragPastEdge_isClipped() {
        let rect = EraseSelection.imageRect(from: CGPoint(x: 80, y: 80), to: CGPoint(x: 150, y: 150),
                                            scale: 1, offset: .zero,
                                            imageSize: CGSize(width: 100, height: 100))
        XCTAssertEqual(rect, CGRect(x: 80, y: 80, width: 20, height: 20))
    }

    func test_imageRect_shortDrag_isNil() {
        let rect = EraseSelection.imageRect(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 15, y: 40),
                                            scale: 1, offset: .zero,
                                            imageSize: CGSize(width: 100, height: 100))
        XCTAssertNil(rect)
    }

    func test_imageRect_entirelyOffImage_isNil() {
        let rect = EraseSelection.imageRect(from: CGPoint(x: 120, y: 120), to: CGPoint(x: 150, y: 150),
                                            scale: 1, offset: .zero,
                                            imageSize: CGSize(width: 100, height: 100))
        XCTAssertNil(rect)
    }
}

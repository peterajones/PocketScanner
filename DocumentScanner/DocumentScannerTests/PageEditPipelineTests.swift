import XCTest
import UIKit
@testable import DocumentScanner

final class PageEditPipelineTests: XCTestCase {

    private let cream = UIColor(red: 245/255, green: 240/255, blue: 224/255, alpha: 1)
    private let pipeline = PageEditPipeline()

    private func page(_ size: CGSize, marks: [CGRect] = []) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = true
        return UIGraphicsImageRenderer(size: size, format: f).image { c in
            cream.setFill(); c.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            for rect in marks { c.fill(rect) }
        }
    }

    private func assertClose(_ a: (r: Int, g: Int, b: Int), _ b: (r: Int, g: Int, b: Int),
                             tolerance: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(abs(a.r - b.r), tolerance, "\(a) vs \(b)", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(a.g - b.g), tolerance, "\(a) vs \(b)", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(a.b - b.b), tolerance, "\(a) vs \(b)", file: file, line: line)
    }

    func test_render_noRects_matchesCorrectRotateFilter() throws {
        let image = page(CGSize(width: 300, height: 200))
        let quad = Quad.fullRect(in: image.size)
        let out = try XCTUnwrap(pipeline.render(image, quad: quad, quarterTurns: 1,
                                                eraseRects: [], filter: .greyscale))
        let straight = try XCTUnwrap(pipeline.straightened(image, quad: quad, quarterTurns: 1))
        let expected = try XCTUnwrap(ImageFilterEngine().apply(.greyscale, to: straight))
        XCTAssertEqual(out.size, straight.size)
        assertClose(out.rgb(atX: 100, y: 150), expected.rgb(atX: 100, y: 150), tolerance: 2)
    }

    // The fill is sampled before the filter and filtered with the paper around it.
    func test_render_erasesBeforeFilter() throws {
        let image = page(CGSize(width: 300, height: 300), marks: [CGRect(x: 100, y: 100, width: 20, height: 20)])
        let out = try XCTUnwrap(pipeline.render(image, quad: Quad.fullRect(in: image.size), quarterTurns: 0,
                                                eraseRects: [CGRect(x: 95, y: 95, width: 30, height: 30)],
                                                filter: .blackAndWhite))
        assertClose(out.rgb(atX: 110, y: 110), out.rgb(atX: 200, y: 200), tolerance: 3)
    }

    // Rects are in the rotated image's space: a box drawn on the rotated view erases there.
    func test_render_quarterTurn_erasesInRotatedSpace() throws {
        let image = page(CGSize(width: 300, height: 200), marks: [CGRect(x: 0, y: 0, width: 20, height: 20)])
        let quad = Quad.fullRect(in: image.size)
        let kept = try XCTUnwrap(pipeline.render(image, quad: quad, quarterTurns: 1,
                                                 eraseRects: [], filter: .none))
        XCTAssertLessThan(kept.rgb(atX: 190, y: 10).r, 60, "the black square should sit top-right after a clockwise turn")
        let erased = try XCTUnwrap(pipeline.render(image, quad: quad, quarterTurns: 1,
                                                   eraseRects: [CGRect(x: 170, y: 0, width: 30, height: 30)],
                                                   filter: .none))
        assertClose(erased.rgb(atX: 190, y: 10), (245, 240, 224), tolerance: 3)
    }

    func test_render_erasedTextIsNotRecognised() async throws {
        let image = UIImage.renderingLines(["Keep this line", "Erase me please"],
                                           size: CGSize(width: 1400, height: 300))
        let before = try await OCREngine().recognizeText(in: image).map(\.string).joined(separator: " ")
        XCTAssertTrue(before.contains("Erase"), "control: the line must be readable before erasing: \(before)")
        let out = try XCTUnwrap(pipeline.render(image, quad: Quad.fullRect(in: image.size), quarterTurns: 0,
                                                eraseRects: [CGRect(x: 0, y: 140, width: 1400, height: 110)],
                                                filter: .none))
        let joined = try await OCREngine().recognizeText(in: out).map(\.string).joined(separator: " ")
        XCTAssertTrue(joined.contains("Keep"), "expected the kept line in \(joined)")
        XCTAssertFalse(joined.contains("Erase"), "erased text still recognised: \(joined)")
    }
}

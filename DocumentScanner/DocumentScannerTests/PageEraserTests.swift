import XCTest
import UIKit
@testable import DocumentScanner

final class PageEraserTests: XCTestCase {

    private let cream = UIColor(red: 245/255, green: 240/255, blue: 224/255, alpha: 1)

    /// A scale-1 image of `size` filled with `background`, then each (rect, colour) painted on top.
    private func page(_ size: CGSize, _ background: UIColor,
                      _ marks: [(CGRect, UIColor)] = []) -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1; f.opaque = true
        return UIGraphicsImageRenderer(size: size, format: f).image { c in
            background.setFill(); c.fill(CGRect(origin: .zero, size: size))
            for (rect, colour) in marks { colour.setFill(); c.fill(rect) }
        }
    }

    private func assertRGB(_ c: (r: Int, g: Int, b: Int), _ expected: (Int, Int, Int),
                           tolerance: Int = 2, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThanOrEqual(abs(c.r - expected.0), tolerance, "r \(c)", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(c.g - expected.1), tolerance, "g \(c)", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(c.b - expected.2), tolerance, "b \(c)", file: file, line: line)
    }

    private func rgb(_ colour: UIColor) -> (r: Int, g: Int, b: Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        colour.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    // MARK: - paperColor

    func test_paperColor_uniformCream_returnsCream() {
        let image = page(CGSize(width: 200, height: 200), cream)
        let colour = PageEraser.paperColor(around: CGRect(x: 80, y: 80, width: 40, height: 40), in: image)
        assertRGB(rgb(colour), (245, 240, 224))
    }

    // A box drawn tight against print: part of the band is dark, the fill must still be paper.
    func test_paperColor_bandPartlyDark_returnsPaper() {
        let image = page(CGSize(width: 200, height: 200), cream,
                         [(CGRect(x: 120, y: 0, width: 10, height: 200), .black)])
        let colour = PageEraser.paperColor(around: CGRect(x: 80, y: 80, width: 40, height: 40), in: image)
        assertRGB(rgb(colour), (245, 240, 224))
    }

    // A staple hole in the very corner: most of the band is off the image.
    func test_paperColor_boxAtCorner_samplesOnlyInsideImage() {
        let image = page(CGSize(width: 200, height: 200), cream)
        let colour = PageEraser.paperColor(around: CGRect(x: -10, y: -10, width: 30, height: 30), in: image)
        assertRGB(rgb(colour), (245, 240, 224))
    }

    // MARK: - erase

    func test_erase_fillsInsideWithPaper_leavesOutsideAlone() {
        let image = page(CGSize(width: 200, height: 200), cream,
                         [(CGRect(x: 50, y: 50, width: 10, height: 10), .black),
                          (CGRect(x: 150, y: 150, width: 10, height: 10), .black)])
        let out = PageEraser.erase([CGRect(x: 45, y: 45, width: 20, height: 20)], in: image)
        assertRGB(out.rgb(atX: 55, y: 55), (245, 240, 224))
        assertRGB(out.rgb(atX: 5, y: 5), (245, 240, 224))
        assertRGB(out.rgb(atX: 155, y: 155), (0, 0, 0))
    }

    func test_erase_keepsSizeAndScaleOne() throws {
        let image = page(CGSize(width: 300, height: 200), cream)
        let out = PageEraser.erase([CGRect(x: 10, y: 10, width: 20, height: 20)], in: image)
        let cg = try XCTUnwrap(out.cgImage)
        XCTAssertEqual(out.scale, 1)
        XCTAssertEqual(cg.width, 300)
        XCTAssertEqual(cg.height, 200)
    }

    func test_erase_rectPartlyOffImage_isClipped() throws {
        let image = page(CGSize(width: 200, height: 200), cream,
                         [(CGRect(x: 192, y: 192, width: 8, height: 8), .black)])
        let out = PageEraser.erase([CGRect(x: 190, y: 190, width: 50, height: 50)], in: image)
        let cg = try XCTUnwrap(out.cgImage)
        XCTAssertEqual(cg.width, 200)
        XCTAssertEqual(cg.height, 200)
        assertRGB(out.rgb(atX: 195, y: 195), (245, 240, 224))
    }

    func test_erase_rectCoversWholeImage_fillsWhite() {
        let image = page(CGSize(width: 200, height: 200), .gray)
        let out = PageEraser.erase([CGRect(x: -5, y: -5, width: 210, height: 210)], in: image)
        assertRGB(out.rgb(atX: 100, y: 100), (255, 255, 255))
    }

    // Box edges fall on fractional pixels (view points ÷ screen scale). A blended edge
    // pixel left a grey hairline of whatever the box cut through.
    func test_erase_fractionalEdge_leavesNoHairline() {
        let image = page(CGSize(width: 200, height: 200), cream,
                         [(CGRect(x: 100, y: 100, width: 20, height: 20), .black)])
        let out = PageEraser.erase([CGRect(x: 95, y: 95, width: 15.5, height: 30)], in: image)
        assertRGB(out.rgb(atX: 110, y: 105), (245, 240, 224))
    }

    // A box at the page edge beside a note erased with another box: its band is mostly
    // that note's ink. Ink under another box is being erased, so it must not colour the fill.
    func test_erase_bandInsideAnotherBox_isNotSampled() {
        let image = page(CGSize(width: 200, height: 200), cream,
                         [(CGRect(x: 0, y: 0, width: 190, height: 200), .black)])
        let out = PageEraser.erase([CGRect(x: 0, y: 0, width: 190, height: 200),
                                    CGRect(x: 190, y: 50, width: 10, height: 20)], in: image)
        assertRGB(out.rgb(atX: 195, y: 60), (245, 240, 224))
    }

    // A small box drawn inside a bigger one has no band of its own left to sample;
    // it must not paint a white patch over the bigger box's cream fill.
    func test_erase_boxInsideAnotherBox_keepsPaperColour() {
        let image = page(CGSize(width: 200, height: 200), cream,
                         [(CGRect(x: 80, y: 80, width: 20, height: 20), .black)])
        let out = PageEraser.erase([CGRect(x: 50, y: 50, width: 100, height: 100),
                                    CGRect(x: 70, y: 70, width: 40, height: 40)], in: image)
        assertRGB(out.rgb(atX: 90, y: 90), (245, 240, 224))
    }

    func test_erase_noRects_returnsSameImage() {
        let image = page(CGSize(width: 20, height: 20), cream)
        XCTAssertTrue(PageEraser.erase([], in: image) === image)
    }
}

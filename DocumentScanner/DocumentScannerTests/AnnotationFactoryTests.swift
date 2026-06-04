import XCTest
import PDFKit
import UIKit
@testable import DocumentScanner

final class AnnotationFactoryTests: XCTestCase {

    /// Builds a 1-page PDF with one OCR observation so findString returns a
    /// real PDFSelection to annotate.
    private func pdfWithSelection(_ needle: String) throws -> (PDFDocument, PDFSelection) {
        let pageSize = CGSize(width: 612, height: 792)
        let normalized = CGRect(x: 0.1, y: 0.25, width: 0.6, height: 0.03)
        let observation = OCRObservation(string: needle, boundingBox: normalized)
        let image = UIGraphicsImageRenderer(size: pageSize).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: pageSize))
        }
        let pdf = try PDFAssembler().assemble(
            pages: [ScannedPage(image: image, observations: [observation])],
            createdAt: Date()
        )
        let selection = try XCTUnwrap(
            pdf.findString(needle, withOptions: .caseInsensitive).first,
            "expected a selection for the needle"
        )
        return (pdf, selection)
    }

    func test_highlight_producesHighlightAnnotationsTaggedAsUser() throws {
        let (_, selection) = try pdfWithSelection("Annotate me")
        let made = AnnotationFactory.annotations(for: selection, tool: .highlight(.yellow))
        XCTAssertFalse(made.isEmpty, "expected at least one annotation")
        for (_, annotation) in made {
            XCTAssertEqual(annotation.type, "Highlight")
            XCTAssertEqual(annotation.userName, DocumentSession.userAnnotationName)
            XCTAssertNotNil(annotation.color)
        }
    }

    func test_strikethrough_producesStrikeOutAnnotations() throws {
        let (_, selection) = try pdfWithSelection("Strike me")
        let made = AnnotationFactory.annotations(for: selection, tool: .strikethrough)
        XCTAssertFalse(made.isEmpty)
        for (_, annotation) in made {
            XCTAssertEqual(annotation.type, "StrikeOut")
            XCTAssertEqual(annotation.userName, DocumentSession.userAnnotationName)
        }
    }

    func test_differentColours_produceDifferentAnnotationColours() throws {
        let (_, selection) = try pdfWithSelection("Colour me")
        let yellow = AnnotationFactory.annotations(for: selection, tool: .highlight(.yellow)).first
        let blue = AnnotationFactory.annotations(for: selection, tool: .highlight(.blue)).first
        let yColor = try XCTUnwrap(yellow?.annotation.color)
        let bColor = try XCTUnwrap(blue?.annotation.color)
        XCTAssertNotEqual(yColor, bColor)
    }

    func test_isUserDeletable_classification() {
        let bounds = CGRect(x: 0, y: 0, width: 10, height: 10)

        // Highlight loaded from disk (no userName) → deletable.
        let loadedHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        XCTAssertTrue(AnnotationFactory.isUserDeletable(loadedHL))

        // Strikethrough → deletable.
        let strike = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
        XCTAssertTrue(AnnotationFactory.isUserDeletable(strike))

        // Search-tagged highlight → NOT deletable.
        let searchHL = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
        searchHL.userName = DocumentSession.searchHighlightAnnotationName
        XCTAssertFalse(AnnotationFactory.isUserDeletable(searchHL))

        // A non-mark annotation (free text) → NOT deletable.
        let note = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        XCTAssertFalse(AnnotationFactory.isUserDeletable(note))
    }
}

import PDFKit
import UIKit

/// A markup tool the user can apply to a text selection.
enum AnnotationTool: Equatable {
    case highlight(AnnotationColor)
    case strikethrough
}

/// Builds the PDFAnnotations for a tool applied to a selection, and classifies
/// whether a tapped annotation is a user mark the user may delete. Pure — no
/// SwiftUI, no view state.
enum AnnotationFactory {

    /// Solid red line for strikethroughs — conventional "done / no longer needed".
    static let strikethroughColor = UIColor.systemRed

    /// One annotation per visual line of the selection (mirrors the search-
    /// highlight rendering). Empty-bounds lines are skipped. Each annotation is
    /// tagged with `DocumentSession.userAnnotationName` so it persists.
    static func annotations(
        for selection: PDFSelection,
        tool: AnnotationTool
    ) -> [(page: PDFPage, annotation: PDFAnnotation)] {
        var result: [(page: PDFPage, annotation: PDFAnnotation)] = []
        for lineSelection in selection.selectionsByLine() {
            for page in lineSelection.pages {
                let bounds = lineSelection.bounds(for: page)
                guard !bounds.isEmpty else { continue }

                let annotation: PDFAnnotation
                switch tool {
                case .highlight(let color):
                    annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                    annotation.color = color.uiColor
                case .strikethrough:
                    annotation = PDFAnnotation(bounds: bounds, forType: .strikeOut, withProperties: nil)
                    annotation.color = strikethroughColor
                }
                annotation.userName = DocumentSession.userAnnotationName
                result.append((page, annotation))
            }
        }
        return result
    }

    /// True for marks the user created and may delete. Keyed on SUBTYPE (not the
    /// user tag) so marks loaded from disk — whose userName may not round-trip —
    /// are still recognised. In-session search highlights are excluded by tag.
    /// Signature stamps are recognised by their explicit userName tag.
    static func isUserDeletable(_ annotation: PDFAnnotation) -> Bool {
        if annotation.userName == DocumentSession.signatureAnnotationName { return true }
        let isMarkSubtype = annotation.type == "Highlight" || annotation.type == "StrikeOut"
        return isMarkSubtype && annotation.userName != DocumentSession.searchHighlightAnnotationName
    }
}

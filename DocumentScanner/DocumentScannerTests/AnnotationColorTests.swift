import XCTest
import UIKit
@testable import DocumentScanner

final class AnnotationColorTests: XCTestCase {

    func test_allCases_areTheFourPaletteColours() {
        XCTAssertEqual(AnnotationColor.allCases, [.yellow, .green, .pink, .blue])
    }

    func test_rawValues_roundTrip() {
        for color in AnnotationColor.allCases {
            XCTAssertEqual(AnnotationColor(rawValue: color.rawValue), color)
        }
    }

    func test_uiColors_areTranslucentAndPairwiseDistinct() {
        let colors = AnnotationColor.allCases.map(\.uiColor)
        // Translucent so the scan shows through.
        for c in colors {
            var alpha: CGFloat = 0
            c.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            XCTAssertLessThan(alpha, 1.0, "highlight colour should be translucent")
        }
        // Pairwise distinct.
        for i in colors.indices {
            for j in colors.indices where j > i {
                XCTAssertFalse(colors[i].isApproximately(colors[j]),
                               "palette colours must be visually distinct")
            }
        }
    }

    func test_displayNames() {
        XCTAssertEqual(AnnotationColor.yellow.displayName, "Yellow")
        XCTAssertEqual(AnnotationColor.green.displayName, "Green")
        XCTAssertEqual(AnnotationColor.pink.displayName, "Pink")
        XCTAssertEqual(AnnotationColor.blue.displayName, "Blue")
    }
}

private extension UIColor {
    /// Compares RGBA components within a small tolerance.
    func isApproximately(_ other: UIColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.05 && abs(g1 - g2) < 0.05
            && abs(b1 - b2) < 0.05 && abs(a1 - a2) < 0.05
    }
}

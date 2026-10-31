import XCTest
import UIKit
@testable import DocumentScanner

final class OCREngineTests: XCTestCase {

    func test_recognizeText_emptyImage_returnsEmptyArray() async throws {
        let image = UIImage.fromColor(.white, size: CGSize(width: 100, height: 100))
        let engine = OCREngine()
        let observations = try await engine.recognizeText(in: image)
        XCTAssertTrue(observations.isEmpty)
    }

    func test_recognizeText_imageWithText_returnsRecognizedStrings() async throws {
        let image = UIImage.renderingText("Hello World", size: CGSize(width: 800, height: 200))
        let engine = OCREngine()
        let observations = try await engine.recognizeText(in: image)
        let joined = observations.map(\.string).joined(separator: " ")
        XCTAssertTrue(joined.localizedCaseInsensitiveContains("hello"),
                      "expected to recognize 'hello' in \(observations.map(\.string))")
        // Each observation should have a real bounding box on the image.
        XCTAssertTrue(observations.allSatisfy { $0.boundingBox.width > 0 && $0.boundingBox.height > 0 })
    }

    // Vision's default request reads only en_US, so a Chinese page came back empty
    // and zh-Hans users got scans they couldn't search.
    func test_recognizeText_chineseText_returnsChinese() async throws {
        let image = UIImage.renderingLines(["处方 化验结果"], size: CGSize(width: 900, height: 200))
        let joined = try await OCREngine().recognizeText(in: image).map(\.string).joined()
        XCTAssertTrue(joined.contains("化验"), "expected Chinese in \(joined)")
    }

    // Automatic detection alone picks one language per page, so on a mostly-English
    // page the Chinese comes back as Latin noise. Listing zh-Hans keeps it.
    func test_recognizeText_mixedChineseAndEnglishPage_keepsTheChinese() async throws {
        let image = UIImage.renderingLines(["Lab Results 化验结果",
                                            "Patient 患者: Zhang Wei",
                                            "Glucose 5.4 mmol/L"],
                                           size: CGSize(width: 1400, height: 420))
        let joined = try await OCREngine().recognizeText(in: image).map(\.string).joined(separator: " ")
        XCTAssertTrue(joined.contains("化验"), "expected Chinese in \(joined)")
        XCTAssertTrue(joined.contains("Glucose"), "expected English in \(joined)")
    }

    // Listing zh-Hans without automatic detection strips Latin diacritics
    // ("Prufungsergebnis StraBe"), which would break search in de/fr/es/it.
    func test_recognizeText_accentedLatinText_keepsTheAccents() async throws {
        let image = UIImage.renderingLines(["Prüfungsergebnis Straße"], size: CGSize(width: 1400, height: 200))
        let joined = try await OCREngine().recognizeText(in: image).map(\.string).joined(separator: " ")
        XCTAssertTrue(joined.contains("Prüfungsergebnis"), "expected the umlaut in \(joined)")
        XCTAssertTrue(joined.contains("Straße"), "expected the ß in \(joined)")
    }
}

private extension UIImage {
    static func fromColor(_ color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    static func renderingText(_ text: String, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 96),
            .foregroundColor: UIColor.black
        ]
        (text as NSString).draw(at: CGPoint(x: 20, y: 40), withAttributes: attrs)
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }

    /// One line of 64pt system text per entry, top to bottom.
    static func renderingLines(_ lines: [String], size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        UIColor.white.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 64),
            .foregroundColor: UIColor.black
        ]
        for (i, line) in lines.enumerated() {
            (line as NSString).draw(at: CGPoint(x: 20, y: 30 + CGFloat(i) * 120), withAttributes: attrs)
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return img
    }
}

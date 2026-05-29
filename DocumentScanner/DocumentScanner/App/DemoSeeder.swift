#if DEBUG
import Foundation
import UIKit
import PDFKit

/// Populates the dev build's local Documents with realistic folders and
/// PDFs so we can shoot App Store screenshots without having to manually
/// scan documents (the simulator can't use VisionKit's camera anyway).
///
/// Launch the dev scheme with the argument `-SeedDemoData` to trigger.
/// Safe to re-run: clears existing content first.
struct DemoSeeder {
    let documentsURL: URL

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-SeedDemoData")
    }

    func seed() {
        do {
            try wipe()
            let storage = DocumentStorage(documentsURL: documentsURL)

            let receipts = try storage.createFolder(named: "Receipts")
            let recipes = try storage.createFolder(named: "Recipes")
            _ = try storage.createFolder(named: "Tax 2025")  // intentionally empty

            // Loose at root
            try writeDemo(at: documentsURL, name: "Lease Agreement",
                          text: "Lease Agreement\n101 Peter St\nEffective May 2026")
            try writeDemo(at: documentsURL, name: "Travel Insurance Policy",
                          text: "TD Insurance Policy\nPolicy #44218\nValid 2026")
            try writeDemo(at: documentsURL, name: "Vacation Itinerary",
                          text: "Vacation Itinerary\nMontreal — June 12-18\nFlight + Hotel",
                          pageCount: 5)

            // In Receipts
            try writeDemo(at: receipts, name: "Costco Receipt — May 29",
                          text: "COSTCO WHOLESALE\n#1234\nTotal 87.42\nReceipt")
            try writeDemo(at: receipts, name: "Whole Foods — May 26",
                          text: "Whole Foods Market\nReceipt\nTotal 42.15")
            try writeDemo(at: receipts, name: "Home Depot — May 20",
                          text: "Home Depot\nReceipt\nSubtotal 153.00\nTotal 172.89")

            // In Recipes
            try writeDemo(at: recipes, name: "Recipe — Banana Bread",
                          text: "Banana Bread\nIngredients\n3 ripe bananas\nDirections\nPreheat oven to 350")
            try writeDemo(at: recipes, name: "Recipe — Pumpkin Pie",
                          text: "Pumpkin Pie\nIngredients\nPumpkin puree\nDirections")
        } catch {
            print("[DemoSeeder] Failed to seed: \(error)")
        }
    }

    private func wipe() throws {
        let items = try FileManager.default.contentsOfDirectory(at: documentsURL,
                                                                includingPropertiesForKeys: nil)
        for url in items {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func writeDemo(at folder: URL, name: String, text: String, pageCount: Int = 1) throws {
        let pages = (0..<pageCount).map { i -> ScannedPage in
            let pageText = pageCount > 1 ? "\(text)\n\nPage \(i + 1)" : text
            return ScannedPage(image: placeholderImage(text: pageText),
                               observations: observations(from: pageText))
        }
        let createdAt = Date().addingTimeInterval(-Double.random(in: 0...86400 * 14))
        let pdf = try PDFAssembler().assemble(pages: pages, createdAt: createdAt)
        let url = folder.appendingPathComponent("\(name).pdf")
        guard let data = pdf.dataRepresentation() else { return }
        try data.write(to: url)
    }

    /// A page-sized rectangle with the text drawn on it. Doesn't have to look
    /// like a real scan — the library list shows the displayName and thumbnails
    /// at small size, so a clean off-white card with the OCR text on top is
    /// enough for screenshots.
    private func placeholderImage(text: String) -> UIImage {
        let size = CGSize(width: 850, height: 1100)  // ~standard letter ratio
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(white: 0.98, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let para = NSMutableParagraphStyle()
            para.alignment = .left
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .regular),
                .foregroundColor: UIColor(white: 0.15, alpha: 1),
                .paragraphStyle: para
            ]
            let inset: CGFloat = 64
            let drawRect = CGRect(x: inset, y: inset,
                                  width: size.width - inset * 2,
                                  height: size.height - inset * 2)
            (text as NSString).draw(in: drawRect, withAttributes: attrs)
        }
    }

    /// Build OCR observations that the search/index can find without running
    /// Vision. Each non-empty line becomes one observation at a plausible y.
    private func observations(from text: String) -> [OCRObservation] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let yStep: CGFloat = 0.04
        return lines.enumerated().map { i, line in
            let y = 0.9 - CGFloat(i) * yStep
            return OCRObservation(string: line,
                                  boundingBox: CGRect(x: 0.08, y: max(0.05, y),
                                                      width: 0.84, height: 0.03))
        }
    }
}
#endif

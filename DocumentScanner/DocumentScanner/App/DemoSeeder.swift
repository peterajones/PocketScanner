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

            // A deliberately unreadable PDF at root, so the 🚫 corrupt-row path
            // (and its immediate, no-confirm delete) is testable on device.
            try writeCorruptDemo(at: documentsURL, name: "Damaged Scan")
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
            let rendered = renderPage(text: pageText)
            return ScannedPage(image: rendered.image, observations: rendered.observations)
        }
        let createdAt = Date().addingTimeInterval(-Double.random(in: 0...86400 * 14))
        let pdf = try PDFAssembler().assemble(pages: pages, createdAt: createdAt)
        let url = folder.appendingPathComponent("\(name).pdf")
        guard let data = pdf.dataRepresentation() else { return }
        try data.write(to: url)
    }

    /// Writes a `.pdf` whose bytes are not a valid PDF, so `PDFDocument(url:)`
    /// returns nil and the library renders it as a corrupt (🚫) row.
    private func writeCorruptDemo(at folder: URL, name: String) throws {
        let url = folder.appendingPathComponent("\(name).pdf")
        let garbage = Data("%PDF-1.4 this file is intentionally not a valid PDF".utf8)
        try garbage.write(to: url)
    }

    /// Renders the page image AND its matching OCR observations from one shared
    /// per-line layout, so the invisible text layer lines up with the visible
    /// glyphs. Earlier these were produced independently (a fixed-size 0.84×0.03
    /// box per line), which made search/user highlights bloat and mis-align —
    /// but only on demo docs; real Vision OCR boxes hug the ink. See
    /// FutureEnhancements "Highlighter thickness / bleed". Each non-empty line's
    /// box is the tight glyph rect (cap-height to descender, measured width),
    /// normalised to Vision's bottom-left coordinate space.
    private func renderPage(text: String) -> (image: UIImage, observations: [OCRObservation]) {
        let size = CGSize(width: 850, height: 1100)  // ~standard letter ratio
        let font = UIFont.systemFont(ofSize: 34, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor(white: 0.15, alpha: 1)
        ]
        let leftInset: CGFloat = 64
        let topInset: CGFloat = 96
        let lineStride = font.lineHeight + 14
        let lines = text.components(separatedBy: "\n")

        var observations: [OCRObservation] = []
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(white: 0.98, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            for (i, line) in lines.enumerated() {
                let origin = CGPoint(x: leftInset, y: topInset + CGFloat(i) * lineStride)
                (line as NSString).draw(at: origin, withAttributes: attrs)
                guard !line.isEmpty else { continue }

                // Tight ink rect for this line, in image (top-left) pixels.
                let baseline = origin.y + font.ascender
                let inkTop = baseline - font.capHeight
                let inkBottom = baseline - font.descender        // descender is negative
                let width = (line as NSString).size(withAttributes: attrs).width

                // Normalise to Vision's 0–1 space with a BOTTOM-LEFT origin.
                observations.append(OCRObservation(
                    string: line,
                    boundingBox: CGRect(
                        x: origin.x / size.width,
                        y: 1 - inkBottom / size.height,
                        width: width / size.width,
                        height: (inkBottom - inkTop) / size.height)))
            }
        }
        return (image, observations)
    }
}
#endif

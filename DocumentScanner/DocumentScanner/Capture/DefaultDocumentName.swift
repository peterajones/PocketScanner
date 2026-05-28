import Foundation

/// Computes a default name for a freshly scanned document.
///
/// `fallback(now:)` returns the historical timestamp form
/// (`Scan YYYY-MM-DD HH:mm`) that's used while OCR is still running.
///
/// `suggest(from:now:)` runs a small set of pattern matchers against
/// OCR text and returns a more descriptive name when one matches —
/// e.g. `"Costco Wholesale Receipt — May 28"` for receipts, or
/// `"Recipe — Banana Bread"` for recipe pages. Returns nil when no
/// pattern fits, leaving the caller to keep the fallback.
enum DefaultDocumentName {
    static func fallback(now: Date = .init()) -> String {
        let f = DateFormatter()
        f.dateFormat = "'Scan' yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: now)
    }

    static func suggest(from ocrText: String, now: Date = .init()) -> String? {
        let lines = nonEmptyLines(in: ocrText)
        guard !lines.isEmpty else { return nil }
        let dateString = shortDate(now)
        let lowered = ocrText.lowercased()

        if let receipt = receiptName(lines: lines, lowered: lowered, dateString: dateString) {
            return receipt
        }
        if let invoice = invoiceName(lines: lines, lowered: lowered, dateString: dateString) {
            return invoice
        }
        if let recipe = recipeName(lines: lines, lowered: lowered) {
            return recipe
        }
        if let title = titleName(lines: lines, dateString: dateString) {
            return title
        }
        return nil
    }

    // MARK: - Pattern matchers

    private static func receiptName(lines: [String], lowered: String, dateString: String) -> String? {
        let isReceipt = lowered.contains("receipt")
            || (lowered.contains("subtotal") && lowered.contains("total"))
            || (lowered.contains("total") && lowered.contains("tax"))
        guard isReceipt else { return nil }
        let vendor = topLineAsVendor(lines)
        return vendor.map { "\($0) Receipt — \(dateString)" } ?? "Receipt — \(dateString)"
    }

    private static func invoiceName(lines: [String], lowered: String, dateString: String) -> String? {
        guard lowered.contains("invoice") || lowered.contains("bill to") else { return nil }
        let vendor = topLineAsVendor(lines)
        return vendor.map { "\($0) Invoice — \(dateString)" } ?? "Invoice — \(dateString)"
    }

    private static func recipeName(lines: [String], lowered: String) -> String? {
        let isRecipe = lowered.contains("ingredients")
            || lowered.contains("directions")
            || lowered.contains("preheat")
            || lowered.contains("recipe")
        guard isRecipe else { return nil }
        let name = lines.first { line in
            isTitleLike(line) && line.lowercased() != "recipe"
        }
        return name.map { "Recipe — \(titleCase($0))" }
    }

    private static func titleName(lines: [String], dateString: String) -> String? {
        guard let first = lines.first, isTitleLike(first) else { return nil }
        return "\(titleCase(first)) — \(dateString)"
    }

    // MARK: - Helpers

    private static func nonEmptyLines(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private static func topLineAsVendor(_ lines: [String]) -> String? {
        for line in lines.prefix(3) where isTitleLike(line) {
            return titleCase(line)
        }
        return nil
    }

    private static func isTitleLike(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 50 else { return false }
        return trimmed.contains(where: { $0.isLetter })
    }

    /// Convert all-caps strings (`COSTCO WHOLESALE`) to title case
    /// (`Costco Wholesale`). Mixed-case input is returned unchanged.
    private static func titleCase(_ s: String) -> String {
        let isAllCaps = s.uppercased() == s && s.contains(where: { $0.isLetter })
        return isAllCaps ? s.capitalized : s
    }
}

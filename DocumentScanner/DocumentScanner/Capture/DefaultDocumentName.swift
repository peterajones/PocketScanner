import Foundation

/// Computes a default name for a freshly scanned document.
///
/// `fallback(now:)` returns the timestamp form (`Scan YYYY-MM-DD HH:mm`) used while OCR is
/// still running. It is deliberately NOT localized: it is a sortable, unambiguous filename
/// stem, and `yyyy-MM-dd` sorts correctly in every locale.
///
/// `suggest(from:now:)` classifies the OCR text and returns a descriptive name, or nil when
/// nothing fits — leaving the caller on the fallback.
///
/// Two things this got wrong before, both fixed here:
///
/// **It matched substrings anywhere in the document.** A consulting agreement containing
/// "payable within thirty (30) days of receipt" was named "Meridian Advisory Group Receipt",
/// and that shipped in an App Store screenshot. Any document containing both "total" and
/// "tax" — a tax slip, a lease — was also a receipt. Classification now weighs evidence and
/// looks at where in the document it appears, rather than firing on one word.
///
/// **Its output was hardcoded English.** A German user scanning a Beleg got
/// "Rewe Receipt — Sep 4". The type words and the date are localized now.
enum DefaultDocumentName {

    static func fallback(now: Date = .init()) -> String {
        let f = DateFormatter()
        f.dateFormat = "'Scan' yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: now)
    }

    /// What a scan appears to be. Ordered by how specific the evidence is.
    enum DocumentKind {
        case receipt, invoice, recipe, generic

        var localizedLabel: String? {
            switch self {
            case .receipt: return String(localized: "Receipt", comment: "Auto-generated document name: a shop receipt")
            case .invoice: return String(localized: "Invoice", comment: "Auto-generated document name: a bill or invoice")
            case .recipe:  return String(localized: "Recipe", comment: "Auto-generated document name: a cooking recipe")
            case .generic: return nil
            }
        }
    }

    static func suggest(from ocrText: String, now: Date = .init()) -> String? {
        let lines = nonEmptyLines(in: ocrText)
        guard !lines.isEmpty else { return nil }

        let kind = classify(lines: lines)
        let date = localizedDate(now)

        switch kind {
        case .recipe:
            // A recipe is named for the dish, not dated — "Recipe, Banana Bread" is
            // more useful than the day you scanned it.
            guard let dish = recipeTitle(lines: lines) else { return nil }
            return join(kind.localizedLabel, dish)
        case .receipt, .invoice:
            guard let label = kind.localizedLabel else { return nil }
            if let vendor = vendorLine(lines) {
                return join("\(vendor) \(label)", date)
            }
            return join(label, date)
        case .generic:
            guard let first = lines.first, isTitleLike(first) else { return nil }
            return join(titleCase(first), date)
        }
    }

    // MARK: - Classification

    /// Scores each kind against the text instead of returning on the first keyword hit.
    ///
    /// Two rules do most of the work:
    /// - **Position matters.** A receipt says "TOTAL" near the END. A contract that mentions
    ///   receipt in a payment clause says it in the middle of prose.
    /// - **A single word is never enough.** The old code fired on one substring; a kind now
    ///   needs corroboration.
    static func classify(lines: [String]) -> DocumentKind {
        let lowered = lines.map { $0.lowercased() }
        let all = lowered.joined(separator: "\n")

        // Prose is the strongest negative signal. Receipts and invoices are terse lines of
        // items and amounts; contracts, leases and letters are sentences. Checking this
        // first is what stops "days of receipt" in a paragraph from classifying.
        let longLines = lines.filter { $0.count > 80 }.count
        let looksLikeProse = longLines >= 2

        if !looksLikeProse {
            let tail = lowered.suffix(max(4, lowered.count / 3))
            let hasTotalNearEnd = tail.contains { $0.contains("total") || $0.contains("amount due") }
            let hasMoneyLines = lines.filter { containsAmount($0) }.count >= 3

            // "Money lines with a total at the end" is NOT enough on its own: a tax slip,
            // a payslip and a bank statement all look exactly like that. A receipt is
            // distinguished by RETAIL vocabulary, so require at least one such term and
            // treat the structural signals as corroboration.
            let retailTerms = ["subtotal", "cashier", "thank you for shopping", "change due",
                               "visa", "mastercard", "debit", "cash tendered", "qty",
                               "store #", "till", "register"]
            let hasRetailTerm = retailTerms.contains { all.contains($0) }
            let saysReceipt = lowered.contains { $0.hasPrefix("receipt") || $0.hasSuffix("receipt") }

            var receiptScore = 0
            if hasRetailTerm || saysReceipt {
                if hasTotalNearEnd { receiptScore += 2 }
                if hasMoneyLines { receiptScore += 2 }
                if saysReceipt { receiptScore += 2 }
                if hasRetailTerm { receiptScore += 1 }
            }

            var invoiceScore = 0
            if lowered.contains(where: { $0.contains("invoice") && $0.count < 40 }) { invoiceScore += 3 }
            if all.contains("bill to") { invoiceScore += 2 }
            if all.contains("amount due") || all.contains("due date") { invoiceScore += 2 }

            // 4 = at least two independent signals agreeing.
            if invoiceScore >= 4, invoiceScore >= receiptScore { return .invoice }
            if receiptScore >= 4 { return .receipt }
        }

        var recipeScore = 0
        if all.contains("ingredients") { recipeScore += 3 }
        if all.contains("directions") || all.contains("instructions") { recipeScore += 2 }
        if all.contains("preheat") { recipeScore += 2 }
        if all.contains("recipe") { recipeScore += 1 }
        if recipeScore >= 4 { return .recipe }

        return .generic
    }

    // MARK: - Helpers

    /// A line carrying a currency amount: at least one digit group with a decimal separator,
    /// which is what an item or total line looks like in any locale.
    private static func containsAmount(_ line: String) -> Bool {
        line.range(of: #"\d[\d,. ]*[.,]\d{2}\b"#, options: .regularExpression) != nil
    }

    /// Joins with a comma rather than an em dash: these strings become FILENAMES, and em
    /// dashes are against Peter's standing preference for shipped copy.
    private static func join(_ a: String?, _ b: String) -> String? {
        guard let a, !a.isEmpty else { return nil }
        return "\(a), \(b)"
    }

    private static func nonEmptyLines(in text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Locale-aware, matching how `DocumentSummary` formats dates elsewhere in the app.
    private static func localizedDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// The shop or company name: the first title-like line in the header, skipping lines
    /// that are themselves the document type.
    private static func vendorLine(_ lines: [String]) -> String? {
        for line in lines.prefix(3) where isTitleLike(line) {
            let l = line.lowercased()
            guard !l.hasPrefix("receipt"), !l.hasPrefix("invoice"), !l.hasPrefix("tax invoice") else { continue }
            return titleCase(line)
        }
        return nil
    }

    private static func recipeTitle(lines: [String]) -> String? {
        lines.first {
            let l = $0.lowercased()
            return isTitleLike($0) && l != "recipe" && !l.hasPrefix("ingredients") && !l.hasPrefix("directions")
        }.map(titleCase)
    }

    private static func isTitleLike(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3, trimmed.count <= 50 else { return false }
        return trimmed.contains(where: { $0.isLetter })
    }

    /// Convert all-caps strings (`COSTCO WHOLESALE`) to title case (`Costco Wholesale`).
    /// Mixed-case input is returned unchanged.
    private static func titleCase(_ s: String) -> String {
        let isAllCaps = s.uppercased() == s && s.contains(where: { $0.isLetter })
        return isAllCaps ? s.capitalized : s
    }
}

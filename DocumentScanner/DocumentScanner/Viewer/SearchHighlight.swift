import Foundation
import Observation
import PDFKit

/// Tracks the current match in a fixed list of PDFSelections. `next()` and
/// `previous()` wrap. Pure value-type-ish — PDFKit's findString runs once
/// when the helper is constructed; this class only manages the index.
@MainActor
@Observable
final class SearchHighlight {

    let matches: [PDFSelection]
    private(set) var currentIndex: Int?

    init(matches: [PDFSelection]) {
        self.matches = matches
        self.currentIndex = matches.isEmpty ? nil : 0
    }

    var matchCount: Int { matches.count }

    var current: PDFSelection? {
        guard let i = currentIndex else { return nil }
        return matches[i]
    }

    func next() {
        guard !matches.isEmpty, let i = currentIndex else { return }
        currentIndex = (i + 1) % matches.count
    }

    func previous() {
        guard !matches.isEmpty, let i = currentIndex else { return }
        currentIndex = (i - 1 + matches.count) % matches.count
    }
}

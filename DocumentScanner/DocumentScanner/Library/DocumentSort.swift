import Foundation

/// The field documents are sorted by.
enum SortKey: String, CaseIterable {
    case date
    case name
    case pageCount

    /// Menu label.
    var title: String {
        switch self {
        case .date:      return "Date"
        case .name:      return "Name"
        case .pageCount: return "Page Count"
        }
    }
}

/// A document sort order: a key plus a direction. Pure value type — no SwiftUI,
/// no view state — so it can be unit-tested directly.
struct DocumentSort: Equatable {
    var key: SortKey
    var ascending: Bool

    /// The natural default direction when first switching to a key: Name reads
    /// A–Z (ascending); Date and Page Count read newest/most first (descending).
    static func defaultAscending(for key: SortKey) -> Bool {
        key == .name
    }

    /// Returns `docs` ordered by the current key and direction. Stable: when the
    /// primary key is equal, ties break by case-insensitive name, then url path,
    /// so the order never jitters between runs.
    func sorted(_ docs: [DocumentSummary]) -> [DocumentSummary] {
        docs.sorted { a, b in
            let order = Self.primaryOrder(a, b, key: key)
            if order != .orderedSame {
                return ascending
                    ? order == .orderedAscending
                    : order == .orderedDescending
            }
            // Stable tie-break, always ascending regardless of `ascending`.
            let byName = a.displayName.localizedCaseInsensitiveCompare(b.displayName)
            if byName != .orderedSame { return byName == .orderedAscending }
            return a.url.path < b.url.path
        }
    }

    private static func primaryOrder(
        _ a: DocumentSummary, _ b: DocumentSummary, key: SortKey
    ) -> ComparisonResult {
        switch key {
        case .date:
            if a.createdAt == b.createdAt { return .orderedSame }
            return a.createdAt < b.createdAt ? .orderedAscending : .orderedDescending
        case .name:
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName)
        case .pageCount:
            if a.pageCount == b.pageCount { return .orderedSame }
            return a.pageCount < b.pageCount ? .orderedAscending : .orderedDescending
        }
    }
}

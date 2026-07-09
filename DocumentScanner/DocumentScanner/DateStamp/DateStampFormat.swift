import Foundation

/// The five date formats a date stamp can render in. Explicit, fixed formats with
/// a fixed `en_US_POSIX` locale so output never shifts with the device's region —
/// the document dictates the format, not the phone. `rawValue` backs @AppStorage.
enum DateStampFormat: String, CaseIterable, Identifiable, Equatable {
    case iso          // 2026-07-09
    case numericUS    // 07/09/2026
    case numericIntl  // 09/07/2026
    case longUS       // July 9, 2026
    case longIntl     // 9 July 2026

    var id: String { rawValue }

    private var template: String {
        switch self {
        case .iso:         return "yyyy-MM-dd"
        case .numericUS:   return "MM/dd/yyyy"
        case .numericIntl: return "dd/MM/yyyy"
        case .longUS:      return "MMMM d, yyyy"
        case .longIntl:    return "d MMMM yyyy"
        }
    }

    func string(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = template
        return f.string(from: date)
    }
}

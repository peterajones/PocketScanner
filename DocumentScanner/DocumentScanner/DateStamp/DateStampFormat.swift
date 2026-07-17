import Foundation

/// The date formats a date stamp can render in. The numeric/ISO formats use a
/// fixed `en_US_POSIX` locale so their digits and separators never shift with the
/// device region (the document dictates the numeric format, not the phone). The
/// long format instead follows the device language for a natural, fully localized
/// date — correct component order and month name, with the locale's particles
/// ("July 9, 2026" / "9 de julio de 2026" / "9 juillet 2026"). `rawValue` backs
/// @AppStorage.
enum DateStampFormat: String, CaseIterable, Identifiable, Equatable {
    case iso          // 2026-07-09
    case numericUS    // 07/09/2026
    case numericIntl  // 09/07/2026
    case long = "longUS"  // locale-natural long date. rawValue kept as "longUS" so
                          // a previously-saved preference still resolves; the old
                          // "longIntl" value harmlessly falls back to the default.

    var id: String { rawValue }

    /// Fixed template for the region-neutral numeric formats; `nil` for the
    /// locale-natural long format (which uses the locale's own `.long` style).
    private var numericTemplate: String? {
        switch self {
        case .iso:         return "yyyy-MM-dd"
        case .numericUS:   return "MM/dd/yyyy"
        case .numericIntl: return "dd/MM/yyyy"
        case .long:        return nil
        }
    }

    func string(for date: Date, locale: Locale = .current) -> String {
        let f = DateFormatter()
        if let template = numericTemplate {
            f.locale = Locale(identifier: "en_US_POSIX")   // digits never shift with region
            f.dateFormat = template
        } else {
            f.locale = locale                               // locale-natural long date
            f.dateStyle = .long
            f.timeStyle = .none
        }
        return f.string(from: date)
    }
}

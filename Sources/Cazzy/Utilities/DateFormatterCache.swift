import Foundation

/// Shared, reused DateFormatters. Creating a DateFormatter is comparatively expensive, and the
/// calendar and to-do views used to build a fresh one for every row label on every redraw —
/// which, since every view watches the shared store, meant on every keystroke anywhere in the
/// app. Only used from view bodies (main thread).
enum DateFormatterCache {
    private static var formatters: [String: DateFormatter] = [:]

    /// A formatter with this fixed `dateFormat` (e.g. "EEE d").
    static func format(_ dateFormat: String) -> DateFormatter {
        cached("format:\(dateFormat)") { $0.dateFormat = dateFormat }
    }

    /// A formatter localized from a template (e.g. "MMM d"), as
    /// `DateFormatter.dateFormat(fromTemplate:options:locale:)` would build.
    static func template(_ template: String) -> DateFormatter {
        cached("template:\(template):\(Locale.current.identifier)") {
            $0.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .current)
        }
    }

    /// The user's short time style (e.g. "3:30 PM").
    static var shortTime: DateFormatter {
        cached("time:short") { $0.timeStyle = .short }
    }

    private static func cached(_ key: String, configure: (DateFormatter) -> Void) -> DateFormatter {
        if let existing = formatters[key] { return existing }
        let formatter = DateFormatter()
        configure(formatter)
        formatters[key] = formatter
        return formatter
    }
}

import Foundation

enum LabMode: String, Codable, CaseIterable, Identifiable {
    case wet, dry

    var id: String { rawValue }
}

enum LabModeFilter: String, CaseIterable, Identifiable {
    case all, wet, dry

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .wet: return "Wet Lab"
        case .dry: return "Dry Lab"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "circle.grid.3x3.fill"
        case .wet: return "flask.fill"
        case .dry: return "laptopcomputer"
        }
    }

    func matches(_ mode: LabMode?) -> Bool {
        guard let mode else { return true }
        switch self {
        case .all: return true
        case .wet: return mode == .wet
        case .dry: return mode == .dry
        }
    }

    /// A newly-created notebook defaults to whichever lab mode the sidebar is currently
    /// filtered to, so it shows up immediately instead of seeming to vanish; "All" has no
    /// single mode to default to, so it falls back to shared (nil, visible everywhere).
    var defaultLabModeForNewNotebook: LabMode? {
        switch self {
        case .all: return nil
        case .wet: return .wet
        case .dry: return .dry
        }
    }
}

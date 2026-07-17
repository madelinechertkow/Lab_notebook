import Foundation

/// Supported plate sizes — the standard multiwell-plate row/column counts.
enum PlateSize: Int, Codable, CaseIterable, Identifiable {
    case wells6 = 6
    case wells12 = 12
    case wells24 = 24
    case wells48 = 48
    case wells96 = 96

    var id: Int { rawValue }

    var rows: Int {
        switch self {
        case .wells6: return 2
        case .wells12: return 3
        case .wells24: return 4
        case .wells48: return 6
        case .wells96: return 8
        }
    }

    var columns: Int {
        switch self {
        case .wells6: return 3
        case .wells12: return 4
        case .wells24: return 6
        case .wells48: return 8
        case .wells96: return 12
        }
    }

    var label: String { "\(rawValue)-well" }

    /// Coordinates in row-major order, e.g. "A1", "A2", ... "H12" for a 96-well plate.
    var wellCoordinates: [String] {
        let rowLetters = (0..<rows).map { String(UnicodeScalar(65 + $0)!) }
        return rowLetters.flatMap { row in (1...columns).map { "\(row)\($0)" } }
    }
}

/// What's annotated on a single well.
struct WellAnnotation: Codable, Equatable {
    var label: String = ""
    var colorHex: UInt32?
    var notes: String = ""

    var isEmpty: Bool { label.isEmpty && colorHex == nil && notes.isEmpty }
}

/// A reusable plate layout saved in the library, independent of any specific note.
struct PlateMapTemplate: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var size: PlateSize
    var wells: [String: WellAnnotation] = [:]
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

/// A lightweight, note-embedded copy of a plate layout — identified by the fence's block id,
/// not its own id, and never written back to the template it may have started from.
struct PlateMapInstance: Codable, Equatable {
    var size: PlateSize
    var wells: [String: WellAnnotation] = [:]
    var sourceTemplateName: String?
}

import SwiftUI

/// Fixed palette for color-coding experiment blocks on the calendar. Stored by rawValue
/// so saved data stays readable if the palette's exact hues are ever tuned.
enum ExperimentColor: String, Codable, CaseIterable, Identifiable {
    case teal, blue, purple, pink, red, orange, yellow, green

    var id: String { rawValue }

    var label: String {
        switch self {
        case .teal: return "Teal"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        }
    }

    var color: Color {
        switch self {
        case .teal: return Color(hex: 0x218380)
        case .blue: return Color(hex: 0x3581B8)
        case .purple: return Color(hex: 0x8F2D56)
        case .pink: return Color(hex: 0xE55381)
        case .red: return Color(hex: 0xD72483)
        case .orange: return Color(hex: 0xF48498)
        case .yellow: return Color(hex: 0xBFAB25)
        case .green: return Color(hex: 0x6B8F71)
        }
    }
}

/// How a repeating experiment repeats. Occurrences are materialized into individual
/// `ScheduledExperiment` rows at creation time (sharing a `seriesID`), so this type only
/// exists as editor input — it is not persisted.
enum ExperimentRecurrence: Equatable {
    case none
    case everyNDays(Int)
    case weekly

    var stepDays: Int? {
        switch self {
        case .none: return nil
        case .everyNDays(let n): return max(1, n)
        case .weekly: return 7
        }
    }
}

enum DurationText {
    static func format(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours) hr \(minutes) min" }
        if hours > 0 { return "\(hours) hr" }
        return "\(minutes) min"
    }
}

/// A planned experiment occupying a time slot on the Cazzy calendar.
struct ScheduledExperiment: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    /// Link back to the protocol this experiment runs, if it was scheduled from one.
    var protocolID: UUID?
    var start: Date
    var durationMinutes: Int
    var color: ExperimentColor = .teal
    var notes: String = ""
    var isCompleted: Bool = false
    /// Shared by all occurrences of a repeating experiment so the series can be deleted together.
    var seriesID: UUID?
    /// Lab Notebook entry created from this experiment, if any.
    var linkedNoteID: UUID?
    /// Identifier of the EKEvent pushed to Apple Calendar, if the user chose to push one.
    var appleCalendarEventID: String?

    init(
        id: UUID = UUID(),
        title: String,
        protocolID: UUID? = nil,
        start: Date,
        durationMinutes: Int,
        color: ExperimentColor = .teal,
        notes: String = "",
        isCompleted: Bool = false,
        seriesID: UUID? = nil,
        linkedNoteID: UUID? = nil,
        appleCalendarEventID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.protocolID = protocolID
        self.start = start
        self.durationMinutes = durationMinutes
        self.color = color
        self.notes = notes
        self.isCompleted = isCompleted
        self.seriesID = seriesID
        self.linkedNoteID = linkedNoteID
        self.appleCalendarEventID = appleCalendarEventID
    }

    enum CodingKeys: String, CodingKey {
        case id, title, protocolID, start, durationMinutes, color, notes, isCompleted, seriesID, linkedNoteID, appleCalendarEventID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        protocolID = try container.decodeIfPresent(UUID.self, forKey: .protocolID)
        start = try container.decode(Date.self, forKey: .start)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 60
        color = try container.decodeIfPresent(ExperimentColor.self, forKey: .color) ?? .teal
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        seriesID = try container.decodeIfPresent(UUID.self, forKey: .seriesID)
        linkedNoteID = try container.decodeIfPresent(UUID.self, forKey: .linkedNoteID)
        appleCalendarEventID = try container.decodeIfPresent(String.self, forKey: .appleCalendarEventID)
    }

    var end: Date {
        start.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    var interval: DateInterval {
        DateInterval(start: start, end: end)
    }
}

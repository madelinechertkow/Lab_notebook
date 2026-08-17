import Foundation

enum Weekday: Int, CaseIterable, Codable, Identifiable, Hashable {
    case monday = 0, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        case .sunday: return "Sunday"
        }
    }

    var shortLabel: String {
        switch self {
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        case .sunday: return "Sun"
        }
    }

    /// Today's weekday, derived from `Calendar.current` (whose `.weekday` is 1 = Sunday ... 7 = Saturday).
    static var today: Weekday {
        Weekday(date: Date())
    }

    /// The weekday a given date falls on, derived from `Calendar.current`.
    init(date: Date) {
        switch Calendar.current.component(.weekday, from: date) {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        default: self = .saturday
        }
    }
}

struct Subtask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, text, isDone
    }

    init(text: String) {
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool = false
    var createdAt: Date = Date()
    /// The calendar day (start-of-day) this todo belongs to.
    var date: Date
    var subtasks: [Subtask] = []

    var weekday: Weekday { Weekday(date: date) }

    enum CodingKeys: String, CodingKey {
        case id, text, isDone, createdAt, date, subtasks
    }

    init(text: String, date: Date = Date()) {
        self.text = text
        self.date = Calendar.current.startOfDay(for: date)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        let created = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        createdAt = created
        if let storedDate = try container.decodeIfPresent(Date.self, forKey: .date) {
            date = Calendar.current.startOfDay(for: storedDate)
        } else {
            // Todos saved before per-day support existed only recorded a recurring
            // weekday, not a real date. New todos already default to the day they're
            // added on, so falling back to the creation date is the closest faithful
            // migration for old ones.
            date = Calendar.current.startOfDay(for: created)
        }
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
    }
}

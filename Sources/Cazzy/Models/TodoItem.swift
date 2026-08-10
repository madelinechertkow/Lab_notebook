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
        switch Calendar.current.component(.weekday, from: Date()) {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
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
    var weekday: Weekday
    var subtasks: [Subtask] = []

    enum CodingKeys: String, CodingKey {
        case id, text, isDone, createdAt, weekday, subtasks
    }

    init(text: String, weekday: Weekday = .today) {
        self.text = text
        self.weekday = weekday
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        isDone = try container.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        // Todos saved before day-of-week support existed default to Monday.
        weekday = try container.decodeIfPresent(Weekday.self, forKey: .weekday) ?? .monday
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
    }
}

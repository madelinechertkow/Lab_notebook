import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var isDone: Bool = false
    var createdAt: Date = Date()
}

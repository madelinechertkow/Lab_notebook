import Foundation

struct Note: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var notebookID: UUID
    var title: String
    var content: String
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var preview: String {
        let stripped = content
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "- [ ] ", with: "")
            .replacingOccurrences(of: "- [x] ", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = stripped.split(separator: "\n").first.map(String.init) ?? ""
        return firstLine
    }

    var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

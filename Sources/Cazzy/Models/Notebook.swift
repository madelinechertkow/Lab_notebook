import Foundation

struct Notebook: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var symbol: String
    var colorIndex: Int
    /// nil means the notebook is shared between wet and dry lab modes.
    var labMode: LabMode?
    /// Archived notebooks are hidden from the main sidebar and "All Notes",
    /// but their notes are untouched — unlike deleteNotebook, nothing is lost.
    var isArchived: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, colorIndex, labMode, isArchived
    }

    init(id: UUID = UUID(), name: String, symbol: String, colorIndex: Int, labMode: LabMode?, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorIndex = colorIndex
        self.labMode = labMode
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        colorIndex = try container.decode(Int.self, forKey: .colorIndex)
        labMode = try container.decodeIfPresent(LabMode.self, forKey: .labMode)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    static func defaults() -> [Notebook] {
        [
            Notebook(name: "Lab Notebook", symbol: "book.closed.fill", colorIndex: 0, labMode: .wet),
            Notebook(name: "Protocols", symbol: "cross.vial.fill", colorIndex: 1, labMode: .wet),
            Notebook(name: "Analysis Notebook", symbol: "chart.xyaxis.line", colorIndex: 0, labMode: .dry),
            Notebook(name: "Scripts & Workflows", symbol: "terminal.fill", colorIndex: 1, labMode: .dry),
            Notebook(name: "Literature Notes", symbol: "books.vertical.fill", colorIndex: 2, labMode: nil),
            Notebook(name: "Thesis & Writing", symbol: "pencil.and.outline", colorIndex: 3, labMode: nil),
            Notebook(name: "Meeting Notes", symbol: "person.2.fill", colorIndex: 4, labMode: nil),
            Notebook(name: "Ideas & Hypotheses", symbol: "sparkles", colorIndex: 5, labMode: nil),
        ]
    }
}

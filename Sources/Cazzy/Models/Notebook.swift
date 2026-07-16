import Foundation

struct Notebook: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var symbol: String
    var colorIndex: Int
    /// nil means the notebook is shared between wet and dry lab modes.
    var labMode: LabMode?

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

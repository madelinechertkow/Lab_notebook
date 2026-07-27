import Foundation

/// A reference to a file that stays in its original location on disk — e.g. a thesis
/// chapter still being drafted in Word. Stored as a bookmark rather than a copy, so
/// opening it always goes back to that same file and picks up whatever was last saved
/// there, including edits made outside this app.
struct LinkedFile: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var notebookID: UUID
    var fileName: String
    var bookmarkData: Data
    var dateAdded: Date = Date()

    init(
        id: UUID = UUID(),
        notebookID: UUID,
        fileName: String,
        bookmarkData: Data,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.notebookID = notebookID
        self.fileName = fileName
        self.bookmarkData = bookmarkData
        self.dateAdded = dateAdded
    }
}

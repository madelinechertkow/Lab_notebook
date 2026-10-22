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

/// Hyperlinks to a linked file from inside a note's markdown (via the editor toolbar's
/// "Link file" button) are written as `[name](cazzy-file:<LinkedFile id>)` rather than an
/// absolute path, so they go through the same bookmark as the notebook's Files tab and keep
/// working if the original file is moved or renamed.
extension LinkedFile {
    static let noteLinkScheme = "cazzy-file"

    /// `label` is the note text the link is attached to (the user's highlighted text).
    func noteLinkMarkdown(label: String) -> String {
        let escaped = label
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escaped)](\(Self.noteLinkScheme):\(id.uuidString))"
    }

    /// The LinkedFile id a `cazzy-file:` URL points at, or nil for any other kind of URL.
    static func id(fromNoteLink url: URL) -> UUID? {
        guard url.scheme == noteLinkScheme else { return nil }
        return UUID(uuidString: String(url.absoluteString.dropFirst(noteLinkScheme.count + 1)))
    }
}

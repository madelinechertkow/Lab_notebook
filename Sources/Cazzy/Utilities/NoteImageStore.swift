import Foundation

/// Copies images inserted into note bodies (via the editor toolbar's "Insert Image" button)
/// into Application Support/Cazzy/NoteImages, mirroring GelImageStore. Note content never
/// stores an absolute path — only a `cazzy-note-image:<filename>` reference inside a normal
/// `![alt](...)` markdown image — so the app support folder stays self-contained and notes
/// stay portable if that folder ever moves.
enum NoteImageStore {
    static let urlScheme = "cazzy-note-image"

    private static var directory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Cazzy", isDirectory: true).appendingPathComponent("NoteImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copies the file at `sourceURL` into the note images folder under a fresh name,
    /// returning the filename to embed in a markdown image reference.
    static func importImage(from sourceURL: URL) throws -> String {
        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = directory.appendingPathComponent(filename)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return filename
    }

    /// The `![alt](cazzy-note-image:filename)` markdown to insert into note content.
    static func markdownReference(filename: String, alt: String) -> String {
        "![\(alt)](\(urlScheme):\(filename))"
    }

    /// Resolves a `cazzy-note-image:` URL (as parsed out of a note's markdown) to the file on
    /// disk. Returns nil for anything that isn't one of ours — a plain http(s) or file URL the
    /// user typed in by hand is left for the caller to load directly instead.
    static func resolve(_ url: URL) -> URL? {
        let prefix = "\(urlScheme):"
        guard url.absoluteString.hasPrefix(prefix) else { return nil }
        let filename = String(url.absoluteString.dropFirst(prefix.count)).removingPercentEncoding
        guard let filename, !filename.isEmpty else { return nil }
        return directory.appendingPathComponent(filename)
    }
}

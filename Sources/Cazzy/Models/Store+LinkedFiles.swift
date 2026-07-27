import Foundation
import AppKit

extension NoteStore {
    func linkedFiles(in notebookID: UUID) -> [LinkedFile] {
        linkedFiles.filter { $0.notebookID == notebookID }.sorted { $0.dateAdded > $1.dateAdded }
    }

    @discardableResult
    func linkFile(at url: URL, in notebookID: UUID) throws -> LinkedFile {
        let bookmarkData = try url.bookmarkData(options: [.suitableForBookmarkFile], includingResourceValuesForKeys: nil, relativeTo: nil)
        let linked = LinkedFile(notebookID: notebookID, fileName: url.lastPathComponent, bookmarkData: bookmarkData)
        linkedFiles.append(linked)
        save()
        return linked
    }

    func removeLinkedFile(_ file: LinkedFile) {
        linkedFiles.removeAll { $0.id == file.id }
        save()
    }

    /// Resolves a linked file's bookmark back to a URL on disk. If the file moved but is
    /// still reachable, the stored bookmark and display name are refreshed in place so
    /// future opens don't depend on the old path; returns nil only if the file is gone.
    func resolvedURL(for file: LinkedFile) -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: file.bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        if isStale, let idx = linkedFiles.firstIndex(where: { $0.id == file.id }),
           let refreshed = try? url.bookmarkData(options: [.suitableForBookmarkFile], includingResourceValuesForKeys: nil, relativeTo: nil) {
            linkedFiles[idx].bookmarkData = refreshed
            linkedFiles[idx].fileName = url.lastPathComponent
            save()
        }
        return url
    }

    @discardableResult
    func openLinkedFile(_ file: LinkedFile) -> Bool {
        guard let url = resolvedURL(for: file) else { return false }
        return NSWorkspace.shared.open(url)
    }

    func revealLinkedFileInFinder(_ file: LinkedFile) {
        guard let url = resolvedURL(for: file) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Points an existing entry at a new file location (e.g. after the user moved or
    /// renamed the original) without losing its dateAdded or identity.
    func relinkFile(_ file: LinkedFile, to url: URL) throws {
        guard let idx = linkedFiles.firstIndex(where: { $0.id == file.id }) else { return }
        let bookmarkData = try url.bookmarkData(options: [.suitableForBookmarkFile], includingResourceValuesForKeys: nil, relativeTo: nil)
        linkedFiles[idx].bookmarkData = bookmarkData
        linkedFiles[idx].fileName = url.lastPathComponent
        save()
    }
}

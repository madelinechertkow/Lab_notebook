import Foundation
import CryptoKit

/// Mirrors every note into a user-chosen folder as a plain Markdown file — normally a folder
/// inside Box Drive (~/Library/CloudStorage/Box-Box), which then uploads whatever lands there.
/// Talking to the Box API directly would need OAuth and a registered Box app; writing into the
/// Box Drive folder gets the same result with no credentials, and keeps working offline (Box
/// Drive uploads once it reconnects).
///
/// Layout, all inside a `Cazzy` subfolder of the chosen folder so it stays separate from
/// anything else already there:
///   `Cazzy/<Notebook name>/<yyyy-MM-dd> <Title>.md` — one folder per notebook (created even
///       while empty), inserted images copied to `Cazzy/<Notebook name>/images/`
///   `Cazzy/Protocol Library/<Protocol name>.md` — the structured protocols
/// A manifest in Application Support remembers which file
/// belongs to which note and a hash of what was last written, so a sync only touches notes
/// that actually changed (rewriting unchanged files would make Box re-upload them every time).
///
/// Deleting a note or protocol in Cazzy deliberately does NOT delete its backup file — the point of the
/// backup is a durable record. Renaming or moving a note does move its file, so stale copies
/// under old names don't pile up.
final class BoxBackupService: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var folderURL: URL?
    @Published private(set) var lastBackupAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isBackingUp = false

    /// Where Box Drive mounts on current macOS — used as the folder picker's starting point.
    static let boxDriveRoot = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/CloudStorage/Box-Box", isDirectory: true)

    private static let enabledKey = "boxBackupEnabled"
    private static let folderKey = "boxBackupFolderPath"
    /// Notes save on every keystroke; wait for a pause in typing before writing to Box.
    private static let debounceInterval: TimeInterval = 5

    private let queue = DispatchQueue(label: "com.madelinechertkow.cazzy.boxbackup")
    private var pendingWork: DispatchWorkItem?
    private let manifestURL: URL

    /// Everything Cazzy writes goes under this subfolder of the user's chosen folder.
    static let rootFolderName = "Cazzy"
    private static let protocolFolderName = "Protocol Library"

    private struct Snapshot {
        var notes: [Note]
        var notebooks: [Notebook]
        var protocols: [LabProtocol]
    }

    private struct ManifestEntry: Codable {
        var relativePath: String
        var hash: String
    }

    private struct Manifest: Codable {
        var folderPath: String
        var entries: [UUID: ManifestEntry]
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        manifestURL = appSupport.appendingPathComponent("Cazzy", isDirectory: true)
            .appendingPathComponent("box-backup-manifest.json")
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if let path = UserDefaults.standard.string(forKey: Self.folderKey) {
            folderURL = URL(fileURLWithPath: path, isDirectory: true)
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
    }

    func setFolder(_ url: URL) {
        folderURL = url
        UserDefaults.standard.set(url.path, forKey: Self.folderKey)
    }

    /// Called after every store save. Coalesces bursts (typing) into one backup.
    func scheduleBackup(notes: [Note], notebooks: [Notebook], protocols: [LabProtocol]) {
        guard isEnabled, folderURL != nil else { return }
        pendingWork?.cancel()
        let snapshot = Snapshot(notes: notes, notebooks: notebooks, protocols: protocols)
        let work = DispatchWorkItem { [weak self] in self?.run(snapshot) }
        pendingWork = work
        queue.asyncAfter(deadline: .now() + Self.debounceInterval, execute: work)
    }

    /// Runs immediately (e.g. the "Back Up Now" button), skipping the typing debounce.
    func backUpNow(notes: [Note], notebooks: [Notebook], protocols: [LabProtocol]) {
        guard folderURL != nil else { return }
        pendingWork?.cancel()
        let snapshot = Snapshot(notes: notes, notebooks: notebooks, protocols: protocols)
        queue.async { [weak self] in self?.run(snapshot) }
    }

    // MARK: - Backup (runs on `queue`)

    private func run(_ snapshot: Snapshot) {
        guard let folder = folderURL else { return }
        DispatchQueue.main.async { self.isBackingUp = true }
        let failure: String?
        do {
            try backUp(snapshot, to: folder)
            failure = nil
        } catch {
            failure = "Backup failed: \(error.localizedDescription)"
        }
        DispatchQueue.main.async {
            self.isBackingUp = false
            self.lastError = failure
            if failure == nil { self.lastBackupAt = Date() }
        }
    }

    private func backUp(_ snapshot: Snapshot, to folder: URL) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDir), isDir.boolValue else {
            throw BackupError.folderMissing(folder.path)
        }

        var manifest = loadManifest()
        if manifest.folderPath != folder.path {
            // A different destination: everything needs writing there from scratch.
            manifest = Manifest(folderPath: folder.path, entries: [:])
        }

        let root = Self.rootFolderName
        let notebooksByID = Dictionary(uniqueKeysWithValues: snapshot.notebooks.map { ($0.id, $0) })
        var claimedPaths = Set<String>()
        var vacatedFolders = Set<URL>()

        /// Picks a path not already used this run (two notes with the same date + title get a
        /// short ID appended), moves the item's old file there if it was renamed or moved, and
        /// writes it if its content changed since the last backup.
        func write(id: UUID, folder subfolder: String, fileName: (String?) -> String, markdown: String) throws {
            var relativePath = "\(root)/\(subfolder)/\(fileName(nil))"
            if claimedPaths.contains(relativePath.lowercased()) {
                relativePath = "\(root)/\(subfolder)/\(fileName(String(id.uuidString.prefix(6))))"
            }
            claimedPaths.insert(relativePath.lowercased())

            let destination = folder.appendingPathComponent(relativePath)
            let previous = manifest.entries[id]
            let hash = SHA256.hash(data: Data(markdown.utf8)).map { String(format: "%02x", $0) }.joined()

            if let previous, previous.relativePath != relativePath {
                // Renamed, moved to another notebook, or written before the Cazzy subfolder
                // existed — move the old file rather than leaving a stale copy behind.
                let oldURL = folder.appendingPathComponent(previous.relativePath)
                if fm.fileExists(atPath: oldURL.path) && !fm.fileExists(atPath: destination.path) {
                    try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? fm.moveItem(at: oldURL, to: destination)
                    vacatedFolders.insert(oldURL.deletingLastPathComponent())
                }
            }

            let unchanged = previous?.hash == hash
                && previous?.relativePath == relativePath
                && fm.fileExists(atPath: destination.path)
            if unchanged { return }

            try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(markdown.utf8).write(to: destination, options: .atomic)
            manifest.entries[id] = ManifestEntry(relativePath: relativePath, hash: hash)
        }

        // A folder for every active notebook, even before it has any entries.
        for notebook in snapshot.notebooks where !notebook.isArchived {
            let notebookFolder = folder.appendingPathComponent(root)
                .appendingPathComponent(Self.sanitize(notebook.name, fallback: "Unfiled"))
            try fm.createDirectory(at: notebookFolder, withIntermediateDirectories: true)
        }

        for note in snapshot.notes.sorted(by: { $0.createdAt < $1.createdAt }) {
            let notebookName = notebooksByID[note.notebookID]?.name ?? "Unfiled"
            let notebookFolder = Self.sanitize(notebookName, fallback: "Unfiled")

            // The images folder is per notebook, so links in the .md are relative and still
            // resolve when someone opens the file straight from Box.
            let (markdown, images) = render(note, notebookName: notebookName)
            try copyImages(images, into: folder.appendingPathComponent(root)
                .appendingPathComponent(notebookFolder).appendingPathComponent("images"))
            try write(id: note.id, folder: notebookFolder, fileName: { Self.fileName(for: note, suffix: $0) }, markdown: markdown)
        }

        for protocolItem in snapshot.protocols.sorted(by: { $0.createdAt < $1.createdAt }) {
            try write(
                id: protocolItem.id,
                folder: Self.protocolFolderName,
                fileName: { suffix in
                    let base = Self.sanitize(protocolItem.name, fallback: "Untitled Protocol")
                    return (suffix.map { "\(base) \($0)" } ?? base) + ".md"
                },
                markdown: render(protocolItem)
            )
        }

        // Tidy up folders left empty by moves (e.g. the pre-"Cazzy" notebook folders). Only
        // ever removes a folder with nothing in it but an empty images folder or .DS_Store.
        for vacated in vacatedFolders where vacated.path.hasPrefix(folder.path + "/") {
            Self.removeIfEmpty(vacated.appendingPathComponent("images"))
            Self.removeIfEmpty(vacated)
        }

        saveManifest(manifest)
    }

    /// The note as a standalone Markdown file: a small metadata header, then the body with
    /// Cazzy's internal image references rewritten to point at the copied image files.
    private func render(_ note: Note, notebookName: String) -> (String, [String]) {
        var images: [String] = []
        let prefix = "(\(NoteImageStore.urlScheme):"
        var body = note.content
        var searchRange = body.startIndex..<body.endIndex
        while let start = body.range(of: prefix, range: searchRange),
              let end = body[start.upperBound...].firstIndex(of: ")") {
            let filename = String(body[start.upperBound..<end])
            images.append(filename)
            let replacement = "(images/\(filename)"
            body.replaceSubrange(start.lowerBound..<end, with: replacement)
            let resumeAt = body.index(start.lowerBound, offsetBy: replacement.count)
            searchRange = resumeAt..<body.endIndex
        }

        let iso = ISO8601DateFormatter()
        var header = "---\n"
        header += "title: \(Self.yamlQuoted(note.title))\n"
        header += "notebook: \(Self.yamlQuoted(notebookName))\n"
        if !note.tags.isEmpty {
            header += "tags: [\(note.tags.map(Self.yamlQuoted).joined(separator: ", "))]\n"
        }
        header += "created: \(iso.string(from: note.createdAt))\n"
        header += "updated: \(iso.string(from: note.updatedAt))\n"
        if note.isArchived { header += "archived: true\n" }
        header += "cazzy-id: \(note.id.uuidString)\n"
        header += "---\n\n"
        return (header + body + (body.hasSuffix("\n") ? "" : "\n"), images)
    }

    private func render(_ protocolItem: LabProtocol) -> String {
        let iso = ISO8601DateFormatter()
        var header = "---\n"
        header += "title: \(Self.yamlQuoted(protocolItem.name))\n"
        header += "type: protocol\n"
        if protocolItem.currentVersionNumber > 0 { header += "version: \(protocolItem.currentVersionNumber)\n" }
        if !protocolItem.tags.isEmpty {
            header += "tags: [\(protocolItem.tags.map(Self.yamlQuoted).joined(separator: ", "))]\n"
        }
        header += "created: \(iso.string(from: protocolItem.createdAt))\n"
        header += "updated: \(iso.string(from: protocolItem.updatedAt))\n"
        header += "cazzy-id: \(protocolItem.id.uuidString)\n"
        header += "---\n\n"
        return header + protocolItem.markdownBody
    }

    private static func removeIfEmpty(_ directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory.path) else { return }
        guard contents.allSatisfy({ $0 == ".DS_Store" }) else { return }
        try? fm.removeItem(at: directory)
    }

    private func copyImages(_ filenames: [String], into imagesFolder: URL) throws {
        guard !filenames.isEmpty else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: imagesFolder, withIntermediateDirectories: true)
        for filename in filenames {
            let destination = imagesFolder.appendingPathComponent(filename)
            // Image files are UUID-named and never edited in place, so an existing copy is current.
            guard !fm.fileExists(atPath: destination.path),
                  let source = URL(string: "\(NoteImageStore.urlScheme):\(filename)").flatMap(NoteImageStore.resolve),
                  fm.fileExists(atPath: source.path)
            else { continue }
            try fm.copyItem(at: source, to: destination)
        }
    }

    // MARK: - Manifest

    private func loadManifest() -> Manifest {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else { return Manifest(folderPath: "", entries: [:]) }
        return manifest
    }

    private func saveManifest(_ manifest: Manifest) {
        guard let data = try? JSONEncoder().encode(manifest) else { return }
        try? data.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Naming

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func fileName(for note: Note, suffix: String? = nil) -> String {
        let title = sanitize(note.title, fallback: "Untitled")
        let base = "\(dayFormatter.string(from: note.createdAt)) \(title)"
        return (suffix.map { "\(base) \($0)" } ?? base) + ".md"
    }

    /// Makes a string safe as a single path component on macOS and in Box (which also
    /// rejects \ and some other characters Windows users would trip over).
    static func sanitize(_ name: String, fallback: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|").union(.newlines).union(.controlCharacters)
        let cleaned = name.components(separatedBy: illegal).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".")))
        let trimmed = String(cleaned.prefix(100)).trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func yamlQuoted(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private enum BackupError: LocalizedError {
        case folderMissing(String)

        var errorDescription: String? {
            switch self {
            case .folderMissing(let path):
                return "The backup folder can't be found (\(path)). Is Box Drive running and signed in?"
            }
        }
    }
}

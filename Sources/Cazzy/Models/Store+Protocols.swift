import Foundation

enum ProtocolImportError: LocalizedError {
    case unsupportedFormatVersion(Int)
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion(let version):
            return "This protocol file was exported by a newer version of Cazzy (format \(version)) and can't be imported here. Update Cazzy and try again."
        case .unreadableFile:
            return "This file isn't a valid Cazzy protocol export."
        }
    }
}

extension NoteStore {
    enum ProtocolImportResult {
        case newProtocol(LabProtocol)
        case conflict(local: LabProtocol, imported: LabProtocol)
    }

    @discardableResult
    func createProtocol(name: String = "Untitled Protocol") -> LabProtocol {
        let protocolItem = LabProtocol(name: name)
        protocols.append(protocolItem)
        save()
        return protocolItem
    }

    /// Persists live edits to a protocol's draft fields without touching version history.
    func updateProtocolDraft(_ protocolItem: LabProtocol) {
        guard let idx = protocols.firstIndex(where: { $0.id == protocolItem.id }) else { return }
        var updated = protocolItem
        updated.updatedAt = Date()
        protocols[idx] = updated
        save()
    }

    /// Snapshots the current draft into version history.
    func saveNewVersion(for protocolID: UUID, changeNote: String = "") {
        guard let idx = protocols.firstIndex(where: { $0.id == protocolID }) else { return }
        let nextVersionNumber = (protocols[idx].versions.map(\.versionNumber).max() ?? 0) + 1
        let version = ProtocolVersion(
            versionNumber: nextVersionNumber,
            changeNote: changeNote.trimmingCharacters(in: .whitespacesAndNewlines),
            snapshot: protocols[idx].draftSnapshot
        )
        protocols[idx].versions.append(version)
        protocols[idx].currentVersionNumber = nextVersionNumber
        protocols[idx].updatedAt = Date()
        save()
    }

    /// Loads a prior version's snapshot into the live draft fields. Version history is left
    /// untouched — the user must explicitly Save New Version to commit the restore.
    func restoreVersion(_ version: ProtocolVersion, in protocolID: UUID) {
        guard let idx = protocols.firstIndex(where: { $0.id == protocolID }) else { return }
        let snapshot = version.snapshot
        protocols[idx].name = snapshot.name
        protocols[idx].purpose = snapshot.purpose
        protocols[idx].reagents = snapshot.reagents
        protocols[idx].steps = snapshot.steps
        protocols[idx].tags = snapshot.tags
        protocols[idx].updatedAt = Date()
        save()
    }

    func deleteProtocol(_ protocolItem: LabProtocol) {
        protocols.removeAll { $0.id == protocolItem.id }
        save()
    }

    func exportProtocol(_ protocolItem: LabProtocol, to url: URL) throws {
        let package = ProtocolPackage(protocolPayload: protocolItem)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(package)
        try data.write(to: url, options: .atomic)
    }

    /// Decodes a `.cazzyprotocol` file. Ids are preserved verbatim so the imported protocol
    /// reads identically to how the exporting user authored it, and so id-based matching can
    /// detect when this is actually an update to a protocol that already exists locally.
    func importProtocol(from url: URL) throws -> ProtocolImportResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ProtocolImportError.unreadableFile
        }

        let package: ProtocolPackage
        do {
            package = try JSONDecoder().decode(ProtocolPackage.self, from: data)
        } catch {
            throw ProtocolImportError.unreadableFile
        }

        guard package.formatVersion <= ProtocolPackage.currentFormatVersion else {
            throw ProtocolImportError.unsupportedFormatVersion(package.formatVersion)
        }

        let imported = package.protocolPayload
        if let existing = protocols.first(where: { $0.id == imported.id }) {
            return .conflict(local: existing, imported: imported)
        } else {
            protocols.append(imported)
            save()
            return .newProtocol(imported)
        }
    }
}

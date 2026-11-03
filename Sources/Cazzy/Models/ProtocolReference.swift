import Foundation

/// A notebook entry refers to a protocol with an ordinary Markdown link:
/// `[RNA Extraction v3](cazzy-protocol:<protocol id>?v=3)`. Nothing extra is stored — the
/// protocol's "Used in notebook entries" list is worked out by scanning note text for these
/// links, so deleting the link from the entry is all it takes to remove the reference.
struct ProtocolReference: Equatable {
    static let scheme = "cazzy-protocol"

    let protocolID: UUID
    /// The saved version referenced, or nil when the protocol had no saved versions yet.
    let version: Int?

    var url: String {
        var url = "\(Self.scheme):\(protocolID.uuidString)"
        if let version { url += "?v=\(version)" }
        return url
    }

    func markdown(label: String) -> String {
        let escaped = label
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escaped)](\(url))"
    }

    init(protocolID: UUID, version: Int?) {
        self.protocolID = protocolID
        self.version = version
    }

    /// Parses a clicked link; nil for any other kind of URL.
    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        let rest = String(url.absoluteString.dropFirst(Self.scheme.count + 1))
        let parts = rest.split(separator: "?", maxSplits: 1)
        guard let first = parts.first, let id = UUID(uuidString: String(first)) else { return nil }
        protocolID = id
        if parts.count > 1, let value = parts[1].split(separator: "=").last, parts[1].hasPrefix("v=") {
            version = Int(value)
        } else {
            version = nil
        }
    }

    private static let pattern = try! NSRegularExpression(
        pattern: #"cazzy-protocol:([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})(?:\?v=(\d+))?"#
    )

    /// Every protocol reference in a note's text, in order.
    static func all(in text: String) -> [ProtocolReference] {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range).compactMap { match in
            guard let idRange = Range(match.range(at: 1), in: text),
                  let id = UUID(uuidString: String(text[idRange])) else { return nil }
            var version: Int?
            if let versionRange = Range(match.range(at: 2), in: text) {
                version = Int(text[versionRange])
            }
            return ProtocolReference(protocolID: id, version: version)
        }
    }
}

extension NoteStore {
    struct ProtocolUsage: Identifiable {
        let note: Note
        /// Distinct versions this entry references, in the order they appear.
        let versions: [Int?]
        var id: UUID { note.id }
    }

    /// Notebook entries (not archived) that link to this protocol, newest first.
    func usages(ofProtocol protocolID: UUID) -> [ProtocolUsage] {
        notes
            .filter { !$0.isArchived && $0.content.contains(ProtocolReference.scheme) }
            .compactMap { note in
                var versions: [Int?] = []
                for reference in ProtocolReference.all(in: note.content) where reference.protocolID == protocolID {
                    if !versions.contains(reference.version) { versions.append(reference.version) }
                }
                return versions.isEmpty ? nil : ProtocolUsage(note: note, versions: versions)
            }
            .sorted { $0.note.createdAt > $1.note.createdAt }
    }
}

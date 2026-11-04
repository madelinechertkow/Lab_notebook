import Foundation

/// A notebook entry refers to a protocol with an ordinary Markdown link:
/// `[RNA Extraction v3](cazzy-protocol:<protocol id>?v=3&name=KO%20vs%20WT)`. `v` is the saved
/// version used and `name` an optional label the user gave this particular use (both optional).
/// Nothing extra is stored — the protocol's "Used in notebook entries" list is worked out by
/// scanning note text for these links, so deleting the link from the entry removes the reference.
struct ProtocolReference: Equatable {
    static let scheme = "cazzy-protocol"

    let protocolID: UUID
    /// The saved version referenced, or nil when the protocol had no saved versions yet.
    let version: Int?
    /// What the user called this use of the protocol (e.g. "KO vs WT lysates — blot 2").
    let name: String?

    /// Strict so the name can never end the Markdown link early (no spaces, parentheses, etc.).
    private static let nameAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    var url: String {
        var query: [String] = []
        if let version { query.append("v=\(version)") }
        if let name, !name.isEmpty,
           let encoded = name.addingPercentEncoding(withAllowedCharacters: Self.nameAllowed) {
            query.append("name=\(encoded)")
        }
        let base = "\(Self.scheme):\(protocolID.uuidString)"
        return query.isEmpty ? base : base + "?" + query.joined(separator: "&")
    }

    func markdown(label: String) -> String {
        let escaped = label
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        return "[\(escaped)](\(url))"
    }

    init(protocolID: UUID, version: Int?, name: String? = nil) {
        self.protocolID = protocolID
        self.version = version
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.name = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }

    /// Parses a clicked link; nil for any other kind of URL.
    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        self.init(linkText: url.absoluteString)
    }

    /// Parses `cazzy-protocol:<id>[?v=..&name=..]`.
    private init?(linkText: String) {
        guard linkText.hasPrefix(Self.scheme + ":") else { return nil }
        let rest = String(linkText.dropFirst(Self.scheme.count + 1))
        let parts = rest.split(separator: "?", maxSplits: 1)
        guard let first = parts.first, let id = UUID(uuidString: String(first)) else { return nil }
        var version: Int?
        var name: String?
        if parts.count > 1 {
            for pair in parts[1].split(separator: "&") {
                let keyValue = pair.split(separator: "=", maxSplits: 1)
                guard keyValue.count == 2 else { continue }
                switch keyValue[0] {
                case "v": version = Int(keyValue[1])
                case "name": name = String(keyValue[1]).removingPercentEncoding
                default: break
                }
            }
        }
        self.init(protocolID: id, version: version, name: name)
    }

    private static let pattern = try! NSRegularExpression(
        pattern: #"cazzy-protocol:[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}(?:\?[^)\s]*)?"#
    )

    /// Every protocol reference in a note's text, in order, with the exact link text found.
    static func all(in text: String) -> [(reference: ProtocolReference, link: String)] {
        let range = NSRange(text.startIndex..., in: text)
        return pattern.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let link = String(text[matchRange])
            guard let reference = ProtocolReference(linkText: link) else { return nil }
            return (reference, link)
        }
    }
}

extension NoteStore {
    /// One reference to a protocol from one notebook entry.
    struct ProtocolUsage: Identifiable {
        let note: Note
        let reference: ProtocolReference
        /// The link exactly as written in the entry — used to jump to this spot.
        let link: String
        var id: String { "\(note.id.uuidString)|\(link)" }
    }

    /// References to this protocol from notebook entries (not archived), newest entry first.
    /// The same link repeated within one entry is listed once.
    func usages(ofProtocol protocolID: UUID) -> [ProtocolUsage] {
        notes
            .filter { !$0.isArchived && $0.content.contains(ProtocolReference.scheme) }
            .sorted { $0.createdAt > $1.createdAt }
            .flatMap { note -> [ProtocolUsage] in
                var seen = Set<String>()
                return ProtocolReference.all(in: note.content).compactMap { found in
                    guard found.reference.protocolID == protocolID, seen.insert(found.link).inserted else { return nil }
                    return ProtocolUsage(note: note, reference: found.reference, link: found.link)
                }
            }
    }
}

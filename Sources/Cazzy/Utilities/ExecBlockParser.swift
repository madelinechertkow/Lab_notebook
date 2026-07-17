import Foundation

/// A chunk of a note's markdown content — plain markdown to render as before, an executable
/// code block, or a structured plate-map/gel-map block (identified by a stable ID; their
/// actual data lives in the note's `plateMapResults`/`gelMapResults` dictionaries, not in
/// the fence body).
enum ContentSegment: Identifiable {
    case text(String)
    case exec(id: String, code: String)
    case plateMap(id: String)
    case gelMap(id: String)

    var id: String {
        switch self {
        case .text(let content): return "text-\(content.hashValue)"
        case .exec(let id, _): return "exec-\(id)"
        case .plateMap(let id): return "platemap-\(id)"
        case .gelMap(let id): return "gelmap-\(id)"
        }
    }
}

/// Parses a note's markdown content for ```exec:<id>, ```platemap:<id>, and ```gelmap:<id> fences.
enum ExecBlockParser {
    private static let execMarker = "```exec:"
    private static let plateMapMarker = "```platemap:"
    private static let gelMapMarker = "```gelmap:"
    private static let fenceClose = "```"

    /// Generates a short, human-scannable block ID (not derived from content, so editing
    /// the code doesn't change the block's identity).
    static func newBlockID() -> String {
        String(UUID().uuidString.prefix(6))
    }

    /// Builds the literal markdown template inserted when the user adds a new code block,
    /// plus the character offset within it where the cursor should land (the blank code line).
    static func template(id: String = newBlockID()) -> (text: String, cursorOffset: Int) {
        let openingLine = "\(execMarker)\(id)"
        return ("\(openingLine)\n\n\(fenceClose)", openingLine.count + 1)
    }

    /// Builds the literal markdown template for a plate-map or gel-map block. These carry no
    /// meaningful body text, so the fence is just an empty-bodied marker; the cursor lands
    /// right after it so the user can keep writing below.
    private static func structuredBlockTemplate(marker: String, id: String) -> (text: String, cursorOffset: Int) {
        let text = "\(marker)\(id)\n\(fenceClose)"
        return (text, text.count)
    }

    static func plateMapTemplate(id: String = newBlockID()) -> (text: String, cursorOffset: Int) {
        structuredBlockTemplate(marker: plateMapMarker, id: id)
    }

    static func gelMapTemplate(id: String = newBlockID()) -> (text: String, cursorOffset: Int) {
        structuredBlockTemplate(marker: gelMapMarker, id: id)
    }

    static func parse(_ markdown: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var textBuffer: [String] = []
        var lines = markdown.components(separatedBy: "\n")[...]

        func flushText() {
            guard !textBuffer.isEmpty else { return }
            segments.append(.text(textBuffer.joined(separator: "\n")))
            textBuffer = []
        }

        /// Consumes lines up to (and including) the next closing fence, returning the body
        /// text collected along the way and whether a close was actually found.
        func consumeBlockBody() -> (body: String, closed: Bool) {
            var bodyLines: [String] = []
            var closed = false
            while let line = lines.first {
                lines = lines.dropFirst()
                if line.trimmingCharacters(in: .whitespaces) == fenceClose {
                    closed = true
                    break
                }
                bodyLines.append(line)
            }
            return (bodyLines.joined(separator: "\n"), closed)
        }

        while let line = lines.first {
            lines = lines.dropFirst()
            if line.hasPrefix(execMarker) {
                let id = String(line.dropFirst(execMarker.count)).trimmingCharacters(in: .whitespaces)
                let (code, closed) = consumeBlockBody()
                flushText()
                segments.append(.exec(id: id, code: code))
                if !closed {
                    // Unterminated fence (still being typed) — nothing further to parse as code.
                    break
                }
            } else if line.hasPrefix(plateMapMarker) {
                let id = String(line.dropFirst(plateMapMarker.count)).trimmingCharacters(in: .whitespaces)
                let (_, closed) = consumeBlockBody()
                flushText()
                segments.append(.plateMap(id: id))
                if !closed { break }
            } else if line.hasPrefix(gelMapMarker) {
                let id = String(line.dropFirst(gelMapMarker.count)).trimmingCharacters(in: .whitespaces)
                let (_, closed) = consumeBlockBody()
                flushText()
                segments.append(.gelMap(id: id))
                if !closed { break }
            } else {
                textBuffer.append(line)
            }
        }
        flushText()
        return segments
    }

    /// Splices new code into one ```exec block in place, leaving the rest of the markdown
    /// (surrounding prose, other blocks) byte-for-byte untouched. Used to make exec blocks
    /// editable directly in preview mode without round-tripping through a full re-serialize
    /// of every parsed segment.
    static func replacingExecCode(in markdown: String, blockID: String, newCode: String) -> String {
        var lines = markdown.components(separatedBy: "\n")
        let openingLine = "\(execMarker)\(blockID)"
        guard let openIndex = lines.firstIndex(where: { $0 == openingLine }) else { return markdown }

        var closeIndex: Int?
        for i in (openIndex + 1)..<lines.count where lines[i].trimmingCharacters(in: .whitespaces) == fenceClose {
            closeIndex = i
            break
        }
        guard let closeIndex else { return markdown }

        lines.replaceSubrange((openIndex + 1)..<closeIndex, with: newCode.components(separatedBy: "\n"))
        return lines.joined(separator: "\n")
    }
}

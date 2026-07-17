import Foundation

/// A chunk of a note's markdown content — either plain markdown to render as before,
/// or an executable code block identified by a stable ID.
enum ContentSegment: Identifiable {
    case text(String)
    case exec(id: String, code: String)

    var id: String {
        switch self {
        case .text(let content): return "text-\(content.hashValue)"
        case .exec(let id, _): return "exec-\(id)"
        }
    }
}

/// Parses a note's markdown content for ```exec:<id> ... ``` fences.
enum ExecBlockParser {
    private static let fenceMarker = "```exec:"
    private static let fenceClose = "```"

    /// Generates a short, human-scannable block ID (not derived from content, so editing
    /// the code doesn't change the block's identity).
    static func newBlockID() -> String {
        String(UUID().uuidString.prefix(6))
    }

    /// Builds the literal markdown template inserted when the user adds a new code block,
    /// plus the character offset within it where the cursor should land (the blank code line).
    static func template(id: String = newBlockID()) -> (text: String, cursorOffset: Int) {
        let openingLine = "\(fenceMarker)\(id)"
        return ("\(openingLine)\n\n\(fenceClose)", openingLine.count + 1)
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

        while let line = lines.first {
            lines = lines.dropFirst()
            if let range = line.range(of: fenceMarker), line.hasPrefix(fenceMarker) {
                let id = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                var closed = false
                while let codeLine = lines.first {
                    lines = lines.dropFirst()
                    if codeLine.trimmingCharacters(in: .whitespaces) == fenceClose {
                        closed = true
                        break
                    }
                    codeLines.append(codeLine)
                }
                flushText()
                segments.append(.exec(id: id, code: codeLines.joined(separator: "\n")))
                if !closed {
                    // Unterminated fence (still being typed) — nothing further to parse as code.
                    break
                }
            } else {
                textBuffer.append(line)
            }
        }
        flushText()
        return segments
    }
}

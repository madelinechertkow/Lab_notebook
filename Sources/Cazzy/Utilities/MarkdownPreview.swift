import SwiftUI
import AppKit

struct MarkdownPreview: View {
    @EnvironmentObject var theme: ThemeStore
    let markdown: String
    var executionLanguage: ExecutionLanguage? = nil
    var codeEnvironment: CodeEnvironment? = nil
    var codeBlockResults: [String: CodeBlockResult] = [:]
    var onResult: (CodeBlockResult) -> Void = { _ in }
    var onCodeChange: (String, String) -> Void = { _, _ in }
    var plateMapResults: [String: PlateMapInstance] = [:]
    var onPlateMapChange: (String, PlateMapInstance) -> Void = { _, _ in }
    var gelMapResults: [String: GelMapInstance] = [:]
    var onGelMapChange: (String, GelMapInstance) -> Void = { _, _ in }
    /// Links to exactly this URL — or to it plus a `?query` (so `cazzy-protocol:<id>` matches
    /// every version of that protocol) — are highlighted, and the preview scrolls to the first.
    var highlightLink: String? = nil

    static let highlightScrollID = "highlighted-link"
    static let bottomScrollID = "preview-bottom"

    enum InitialScroll: Equatable {
        case top
        case bottom
        /// Show the block containing this UTF-16 offset of the raw markdown at the top —
        /// used to land on the same spot when switching from Edit to View.
        case sourceOffset(Int)
    }

    /// Where to start when the preview appears. A `.sourceOffset` wins over the highlighted
    /// link; otherwise the highlighted link wins over `.top`/`.bottom`.
    var initialScroll: InitialScroll = .top
    /// Receives where every block currently sits, so the editor can tell which part of the
    /// entry is on screen when switching to Edit.
    var scrollTracker: PreviewScrollTracker? = nil

    var body: some View {
        let segments = ExecBlockParser.parse(markdown)
        let anchors = PreviewAnchors.compute(markdown: markdown, segments: segments)
        // Only the first text segment containing the link carries the scroll target.
        let anchorSegmentID: String? = highlightLink.flatMap { link in
            segments.first { segment in
                if case .text(let content) = segment {
                    return content.contains("(\(link))") || content.contains("(\(link)?")
                }
                return false
            }?.id
        }
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(segments.enumerated()), id: \.offset) { segmentIndex, segment in
                    Group {
                    switch segment {
                    case .text(let content):
                        MarkdownBlocksView(
                            content: content,
                            segmentIndex: segmentIndex,
                            highlightLink: highlightLink,
                            carriesScrollTarget: segment.id == anchorSegmentID
                        )
                    case .exec(let id, let code):
                        ExecBlockView(
                            blockID: id,
                            code: code,
                            language: executionLanguage,
                            activationCommand: codeEnvironment?.activationCommand,
                            result: codeBlockResults[id],
                            onResult: onResult,
                            onCodeChange: { newCode in onCodeChange(id, newCode) }
                        )
                    case .plateMap(let id):
                        PlateMapBlockView(
                            blockID: id,
                            instance: plateMapResults[id] ?? PlateMapInstance(size: .wells96),
                            onChange: { onPlateMapChange(id, $0) }
                        )
                    case .gelMap(let id):
                        if let gelMap = gelMapResults[id] {
                            GelMapBlockView(
                                blockID: id,
                                instance: gelMap,
                                onChange: { onGelMapChange(id, $0) }
                            )
                        } else {
                            EmptyView()
                        }
                    }
                    }
                    // Non-text blocks (code, plate map, gel map) are one scroll anchor each;
                    // text segments mark each of their paragraphs individually.
                    .modifier(PreviewAnchorModifier(
                        anchorID: segment.isText ? nil : PreviewAnchors.segmentID(segmentIndex)
                    ))
                }
                Color.clear
                    .frame(height: 1)
                    .id(Self.bottomScrollID)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .coordinateSpace(name: PreviewAnchors.coordinateSpace)
        .scrollContentBackground(.hidden)
        .onPreferenceChange(PreviewAnchorTopsKey.self) { tops in
            scrollTracker?.update(tops: tops, anchors: anchors)
        }
        .onAppear {
            // Give the blocks a moment to lay out before scrolling.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                switch initialScroll {
                case .sourceOffset(let offset):
                    if let id = anchors.last(where: { $0.offset <= offset })?.id ?? anchors.first?.id {
                        proxy.scrollTo(id, anchor: .top)
                    }
                case .top, .bottom:
                    if anchorSegmentID != nil {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(Self.highlightScrollID, anchor: .center)
                        }
                    } else if initialScroll == .bottom {
                        proxy.scrollTo(Self.bottomScrollID, anchor: .bottom)
                    }
                }
            }
        }
        }
    }
}

// MARK: - Keeping your place between View and Edit
//
// The preview is rendered blocks, the editor is raw Markdown, so "the same spot" means the same
// paragraph. Each preview block gets a scroll anchor and the character offset where it starts
// in the raw text (found by searching for a run of its words, moving forward through the text).
// The tracker remembers which anchor is at the top of the preview, so switching to Edit can
// scroll the text view to that offset — and switching back scrolls the preview to the block
// containing the text view's first visible character.

extension ContentSegment {
    var isText: Bool {
        if case .text = self { return true }
        return false
    }
}

enum PreviewAnchors {
    static let coordinateSpace = "markdown-preview-scroll"

    static func segmentID(_ segmentIndex: Int) -> String { "seg\(segmentIndex)" }
    static func blockID(_ segmentIndex: Int, _ blockID: Int) -> String { "seg\(segmentIndex)-b\(blockID)" }

    /// Every scroll anchor in display order with the UTF-16 offset in `markdown` it starts at.
    static func compute(markdown: String, segments: [ContentSegment]) -> [(id: String, offset: Int)] {
        let source = markdown as NSString
        var anchors: [(id: String, offset: Int)] = []
        var cursor = 0

        func find(_ needle: String, from start: Int) -> Int? {
            guard !needle.isEmpty, start <= source.length else { return nil }
            let range = source.range(of: needle, options: [], range: NSRange(location: start, length: source.length - start))
            return range.location == NSNotFound ? nil : range.location
        }

        for (segmentIndex, segment) in segments.enumerated() {
            switch segment {
            case .text(let content):
                let segmentStart = find(content, from: cursor) ?? cursor
                var blockCursor = segmentStart
                for block in markdownBlocks(from: content) {
                    let key = searchKey(String(block.text.characters))
                    let offset = key.flatMap { find($0, from: blockCursor) } ?? blockCursor
                    anchors.append((blockID(segmentIndex, block.id), offset))
                    blockCursor = offset + (key.map { ($0 as NSString).length } ?? 0)
                }
                cursor = max(blockCursor, segmentStart + (content as NSString).length)
            case .exec(let id, _), .plateMap(let id), .gelMap(let id):
                let offset = find(id, from: cursor).map { max(0, $0 - 12) } ?? cursor
                anchors.append((segmentID(segmentIndex), offset))
                cursor = max(cursor, offset)
            }
        }
        return anchors
    }

    /// The first run of 4+ letters/digits/spaces in a block's displayed text, capped at 24
    /// characters — a piece likely to appear verbatim in the raw Markdown (formatting marks,
    /// link targets and symbol substitutions are all outside such a run).
    private static func searchKey(_ text: String) -> String? {
        var best = ""
        var current = ""
        for character in text {
            if character.isLetter || character.isNumber || character == " " {
                current.append(character)
                if current.count >= 24 { break }
            } else {
                if current.trimmingCharacters(in: .whitespaces).count >= 4 { break }
                current = ""
            }
        }
        best = current.trimmingCharacters(in: .whitespaces)
        return best.count >= 3 ? best : nil
    }
}

/// Holds where each preview block sits right now. A reference type on purpose: it changes on
/// every scroll, and nothing needs to re-render when it does.
final class PreviewScrollTracker: ObservableObject {
    private var tops: [String: CGFloat] = [:]
    private var anchors: [(id: String, offset: Int)] = []

    func update(tops: [String: CGFloat], anchors: [(id: String, offset: Int)]) {
        self.tops = tops
        self.anchors = anchors
    }

    /// Raw-text offset of the block at the top of the visible preview (0 when at the top).
    var topVisibleOffset: Int {
        var best: (top: CGFloat, offset: Int)?
        for anchor in anchors {
            guard let top = tops[anchor.id], top <= 30 else { continue }
            if best == nil || top > best!.top { best = (top, anchor.offset) }
        }
        return best?.offset ?? 0
    }
}

struct PreviewAnchorTopsKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Marks a view as a scroll anchor: gives it an id and reports where its top currently is.
struct PreviewAnchorModifier: ViewModifier {
    let anchorID: String?

    func body(content: Content) -> some View {
        if let anchorID {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: PreviewAnchorTopsKey.self,
                            value: [anchorID: geometry.frame(in: .named(PreviewAnchors.coordinateSpace)).minY]
                        )
                    }
                )
                .id(anchorID)
        } else {
            content
        }
    }
}

// MARK: - Block-level markdown rendering
//
// Foundation's `AttributedString(markdown:)` records block structure (headers, lists,
// quotes, code blocks, tables) as `presentationIntent` metadata on each run, but a single
// `Text` never applies that metadata visually, and the parsed string drops the newlines
// between blocks entirely — so headers, list items, quotes, and paragraphs all rendered as
// one run-on line with no distinguishing style. This splits the parse into one block per
// paragraph-level intent (grouped by the intent's stable `identity`) and renders each block
// according to its kind instead of relying on `Text` to infer it.
//
// Two things `Text` fundamentally can't do get special-cased on top of that block split:
// inline images (`![alt](...)`, detected via `run.imageURL`, rendered as a real `Image`
// instead of text) and `<u>`/`<sup>`/`<sub>` — Markdown has no native syntax for underline,
// superscript, or subscript, and Apple's parser leaves those literal tag characters on
// screen rather than styling them, so they're swapped for sentinel characters before parsing
// and turned into real attributes afterward — see `preprocessInlineStyleTags`/
// `applyInlineStyleMarkers`.

private enum MarkdownBlockKind {
    case header(level: Int)
    case paragraph
    case listItem(ordered: Bool, ordinal: Int, depth: Int)
    case blockQuote
    case codeBlock(language: String?)
    case thematicBreak
    case table(columns: [PresentationIntent.TableColumn], header: [AttributedString], rows: [[AttributedString]])
}

private struct MarkdownBlock: Identifiable {
    let id: Int
    let kind: MarkdownBlockKind
    let text: AttributedString
}

private func markdownBlockKind(for components: [PresentationIntent.IntentType]) -> MarkdownBlockKind {
    for component in components {
        if case .codeBlock(let language) = component.kind { return .codeBlock(language: language) }
    }
    for component in components {
        if case .thematicBreak = component.kind { return .thematicBreak }
    }
    for component in components {
        if case .header(let level) = component.kind { return .header(level: level) }
    }
    if let listItem = components.first(where: {
        if case .listItem = $0.kind { return true } else { return false }
    }), case .listItem(let ordinal) = listItem.kind {
        let depth = components.filter {
            if case .unorderedList = $0.kind { return true }
            if case .orderedList = $0.kind { return true }
            return false
        }.count
        let ordered = components.contains {
            if case .orderedList = $0.kind { return true } else { return false }
        }
        return .listItem(ordered: ordered, ordinal: ordinal, depth: max(depth, 1))
    }
    for component in components {
        if case .blockQuote = component.kind { return .blockQuote }
    }
    return .paragraph
}

// MARK: - <u>, <sup>, <sub> via sentinel markers
//
// Markdown has no native syntax for underline, superscript, or subscript. Apple's parser
// recognizes these as raw inline HTML but leaves the literal tag characters in the text
// rather than styling anything, so each tag pair is swapped for a private-use-area sentinel
// character before parsing (immune to any markdown escaping) and turned into a real
// AttributedString attribute afterward, with the sentinels stripped back out.

private let underlineStartMarker: Character = "\u{E000}"
private let underlineEndMarker: Character = "\u{E001}"
private let superscriptStartMarker: Character = "\u{E002}"
private let superscriptEndMarker: Character = "\u{E003}"
private let subscriptStartMarker: Character = "\u{E004}"
private let subscriptEndMarker: Character = "\u{E005}"

private func preprocessInlineStyleTags(_ text: String) -> String {
    text
        .replacingOccurrences(of: "<u>", with: String(underlineStartMarker), options: .caseInsensitive)
        .replacingOccurrences(of: "</u>", with: String(underlineEndMarker), options: .caseInsensitive)
        .replacingOccurrences(of: "<sup>", with: String(superscriptStartMarker), options: .caseInsensitive)
        .replacingOccurrences(of: "</sup>", with: String(superscriptEndMarker), options: .caseInsensitive)
        .replacingOccurrences(of: "<sub>", with: String(subscriptStartMarker), options: .caseInsensitive)
        .replacingOccurrences(of: "</sub>", with: String(subscriptEndMarker), options: .caseInsensitive)
}

/// Finds each `start`/`end` sentinel pair left by `preprocessInlineStyleTags`, removes the
/// sentinels, and lets `style` attribute the text that was between them. Only matches pairs
/// within the same block (a tag spanning multiple paragraphs/list items won't style) — an
/// accepted limitation given how rarely that's intentional.
private func applyMarkerPairs(
    _ input: AttributedString,
    start: Character,
    end: Character,
    style: (inout AttributedString, Range<AttributedString.Index>) -> Void
) -> AttributedString {
    var result = input
    while let startIndex = result.characters.firstIndex(of: start) {
        result.characters.remove(at: startIndex)
        guard let endIndex = result.characters[startIndex...].firstIndex(of: end) else { continue }
        result.characters.remove(at: endIndex)
        style(&result, startIndex..<endIndex)
    }
    return result
}

private func applyInlineStyleMarkers(_ input: AttributedString) -> AttributedString {
    var result = input
    result = applyMarkerPairs(result, start: underlineStartMarker, end: underlineEndMarker) { text, range in
        text[range].underlineStyle = .single
    }
    result = applyMarkerPairs(result, start: superscriptStartMarker, end: superscriptEndMarker) { text, range in
        text[range].baselineOffset = 6
        text[range].font = .system(size: 10)
    }
    result = applyMarkerPairs(result, start: subscriptStartMarker, end: subscriptEndMarker) { text, range in
        text[range].baselineOffset = -3
        text[range].font = .system(size: 10)
    }
    return result
}

// MARK: - LaTeX-style Greek letters (`\theta`, `$\theta$`, etc.)
//
// Scientists habitually type Greek letters as LaTeX command names, often wrapped in single
// `$...$` math delimiters (e.g. `$\theta$`). CommonMark gives `$` no meaning, and its
// backslash-escape rule only applies to ASCII punctuation (not letters), so Apple's parser
// leaves both untouched and they show up on screen exactly as typed instead of rendering as
// θ. This is plain text substitution done before parsing: a `$...$` pair wrapping a single
// known command has its delimiters stripped along with the command; a bare command found
// elsewhere is swapped for its glyph in place. Longest-name-first avoids a short command
// (`theta`) ever winning over a longer one that shares no boundary with it (`vartheta`).

private let greekLetterCommands: [String: String] = [
    "alpha": "α", "Alpha": "Α",
    "beta": "β", "Beta": "Β",
    "gamma": "γ", "Gamma": "Γ",
    "delta": "δ", "Delta": "Δ",
    "epsilon": "ε", "varepsilon": "ε", "Epsilon": "Ε",
    "zeta": "ζ", "Zeta": "Ζ",
    "eta": "η", "Eta": "Η",
    "theta": "θ", "vartheta": "ϑ", "Theta": "Θ",
    "iota": "ι", "Iota": "Ι",
    "kappa": "κ", "Kappa": "Κ",
    "lambda": "λ", "Lambda": "Λ",
    "mu": "μ", "Mu": "Μ",
    "nu": "ν", "Nu": "Ν",
    "xi": "ξ", "Xi": "Ξ",
    "omicron": "ο", "Omicron": "Ο",
    "pi": "π", "varpi": "ϖ", "Pi": "Π",
    "rho": "ρ", "varrho": "ϱ", "Rho": "Ρ",
    "sigma": "σ", "varsigma": "ς", "Sigma": "Σ",
    "tau": "τ", "Tau": "Τ",
    "upsilon": "υ", "Upsilon": "Υ",
    "phi": "φ", "varphi": "ϕ", "Phi": "Φ",
    "chi": "χ", "Chi": "Χ",
    "psi": "ψ", "Psi": "Ψ",
    "omega": "ω", "Omega": "Ω",
]

private let greekLetterCommandsByDescendingLength = greekLetterCommands.sorted { $0.key.count > $1.key.count }

/// Not private: also used by `Note.preview` (`Note.swift`) so the note-list sidebar snippet
/// shows the same glyphs as the rendered preview, not raw LaTeX-style source.
func replaceGreekLetterCommands(_ text: String) -> String {
    var result = text
    for (command, glyph) in greekLetterCommandsByDescendingLength {
        result = result.replacingOccurrences(
            of: #"\$\\\#(command)\$"#,
            with: glyph,
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\\\#(command)\b"#,
            with: glyph,
            options: .regularExpression
        )
    }
    return result
}

// MARK: - LaTeX-style fractions (`\frac{a}{b}`, `$\frac{a}{b}$`)
//
// Same gap as the Greek letters above: `\frac{260}{280}` has no meaning to CommonMark, so it
// passes through untouched. There's no stacked-fraction rendering available in plain `Text`,
// so this substitutes the visually closest inline equivalent — numerator, a fraction slash,
// denominator — same dollar-stripping behavior as the Greek letters. Runs before the Greek
// letter pass so a numerator/denominator containing its own Greek command (`\frac{\alpha}{\beta}`)
// still gets converted.

/// Not private: also used by `Note.preview` (`Note.swift`), see `replaceGreekLetterCommands`.
func replaceFractionNotation(_ text: String) -> String {
    var result = text
    result = result.replacingOccurrences(
        of: #"\$\\frac\{([^{}]+)\}\{([^{}]+)\}\$"#,
        with: "$1⁄$2",
        options: .regularExpression
    )
    result = result.replacingOccurrences(
        of: #"\\frac\{([^{}]+)\}\{([^{}]+)\}"#,
        with: "$1⁄$2",
        options: .regularExpression
    )
    return result
}

private func markdownBlocks(from text: String) -> [MarkdownBlock] {
    let preprocessed = preprocessInlineStyleTags(
        replaceGreekLetterCommands(
            replaceFractionNotation(
                text
                    .replacingOccurrences(of: "- [ ] ", with: "☐ ")
                    .replacingOccurrences(of: "- [x] ", with: "☑ ")
            )
        )
    )

    guard let full = try? AttributedString(
        markdown: preprocessed,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
    ) else {
        return [MarkdownBlock(id: 0, kind: .paragraph, text: applyInlineStyleMarkers(AttributedString(preprocessed)))]
    }

    var blocks: [MarkdownBlock] = []
    var currentIdentity: Int?
    var currentComponents: [PresentationIntent.IntentType] = []
    var currentText = AttributedString()

    // Table accumulation: cells arrive as separate runs (each with its own identity), so
    // they're gathered into one block per table instead of one block per cell.
    var tableIdentity: Int?
    var tableColumns: [PresentationIntent.TableColumn] = []
    var tableHeaderCells: [Int: AttributedString] = [:]
    var tableRows: [Int: [Int: AttributedString]] = [:]

    func flush() {
        guard currentIdentity != nil else { return }
        blocks.append(MarkdownBlock(id: blocks.count, kind: markdownBlockKind(for: currentComponents), text: applyInlineStyleMarkers(currentText)))
        currentText = AttributedString()
        currentIdentity = nil
    }

    func flushTable() {
        guard tableIdentity != nil else { return }
        let columnCount = tableColumns.count
        let header = (0..<columnCount).map { applyInlineStyleMarkers(tableHeaderCells[$0] ?? AttributedString()) }
        let rows = tableRows.keys.sorted().map { rowIndex in
            (0..<columnCount).map { column in applyInlineStyleMarkers(tableRows[rowIndex]?[column] ?? AttributedString()) }
        }
        blocks.append(MarkdownBlock(id: blocks.count, kind: .table(columns: tableColumns, header: header, rows: rows), text: AttributedString()))
        tableIdentity = nil
        tableColumns = []
        tableHeaderCells = [:]
        tableRows = [:]
    }

    for run in full.runs {
        let components = run.presentationIntent?.components ?? []

        if let tableComponent = components.first(where: { if case .table = $0.kind { return true } else { return false } }) {
            flush()
            if tableIdentity != tableComponent.identity {
                flushTable()
                tableIdentity = tableComponent.identity
                if case .table(let columns) = tableComponent.kind { tableColumns = columns }
            }
            let isHeader = components.contains { if case .tableHeaderRow = $0.kind { return true } else { return false } }
            let rowIndex = components.compactMap { component -> Int? in
                if case .tableRow(let index) = component.kind { return index }
                return nil
            }.first ?? 0
            guard let cellComponent = components.first(where: { if case .tableCell = $0.kind { return true } else { return false } }),
                  case .tableCell(let columnIndex) = cellComponent.kind else { continue }

            let runText = AttributedString(full[run.range])
            if isHeader {
                tableHeaderCells[columnIndex, default: AttributedString()] += runText
            } else {
                tableRows[rowIndex, default: [:]][columnIndex, default: AttributedString()] += runText
            }
            continue
        }
        flushTable()

        let identity = components.first?.identity
        if identity != currentIdentity {
            flush()
            currentIdentity = identity
            currentComponents = components
        }
        currentText += AttributedString(full[run.range])
    }
    flush()
    flushTable()

    return blocks
}

private func markdownBullet(forDepth depth: Int) -> String {
    switch depth {
    case 1: return "•"
    case 2: return "◦"
    default: return "▪"
    }
}

private func markdownHeaderSize(_ level: Int) -> CGFloat {
    switch level {
    case 1: return 22
    case 2: return 19
    case 3: return 17
    default: return 15.5
    }
}

private struct MarkdownBlocksView: View {
    @EnvironmentObject var theme: ThemeStore
    let content: String
    var segmentIndex: Int = 0
    var highlightLink: String? = nil
    var carriesScrollTarget: Bool = false

    var body: some View {
        let blocks = markdownBlocks(from: content)
        let firstMatch = carriesScrollTarget ? blocks.first(where: containsHighlightedLink)?.id : nil
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks) { block in
                Group {
                if containsHighlightedLink(block) {
                    render(block)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(theme.accent.opacity(0.18))
                        )
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(theme.accentDeep)
                                .frame(width: 3)
                        }
                        .padding(.horizontal, -8)
                        .id(block.id == firstMatch ? MarkdownPreview.highlightScrollID : "block-\(block.id)")
                } else {
                    render(block)
                }
                }
                .modifier(PreviewAnchorModifier(anchorID: PreviewAnchors.blockID(segmentIndex, block.id)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func containsHighlightedLink(_ block: MarkdownBlock) -> Bool {
        guard let highlightLink else { return false }
        return block.text.runs.contains { run in
            guard let url = run.link?.absoluteString else { return false }
            return url == highlightLink || url.hasPrefix(highlightLink + "?")
        }
    }

    @ViewBuilder
    private func render(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .header(let level):
            Text(block.text)
                .font(theme.displayFont(markdownHeaderSize(level)))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .padding(.top, level == 1 ? 6 : 2)

        case .paragraph:
            MarkdownParagraphView(text: block.text)

        case .listItem(let ordered, let ordinal, let depth):
            HStack(alignment: .top, spacing: 8) {
                Text(ordered ? "\(ordinal)." : markdownBullet(forDepth: depth))
                    .font(theme.bodyFont(15))
                    .foregroundStyle(theme.textSecondary)
                    .frame(minWidth: 18, alignment: .trailing)
                Text(block.text)
                    .font(theme.bodyFont(15))
                    .foregroundStyle(theme.textPrimary)
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(depth - 1) * 18)

        case .blockQuote:
            HStack(alignment: .top, spacing: 10) {
                Rectangle()
                    .fill(theme.accent.opacity(0.6))
                    .frame(width: 3)
                Text(block.text)
                    .font(theme.bodyFont(15))
                    .italic()
                    .foregroundStyle(theme.textSecondary)
                    .textSelection(.enabled)
            }

        case .codeBlock:
            Text(block.text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.editorBackground)
                )

        case .thematicBreak:
            Divider()
                .padding(.vertical, 4)

        case .table(let columns, let header, let rows):
            MarkdownTableView(columns: columns, header: header, rows: rows)
        }
    }
}

// MARK: - Paragraph rendering (with inline images)
//
// `Text` can't display an image no matter what's in the AttributedString, so a paragraph
// that contains one (`![alt](...)`, surfaced via `run.imageURL`) gets split at the image's
// run boundaries into alternating text/image segments, each rendered with the view that can
// actually show it, stacked in a VStack. A paragraph with no image is unaffected — same
// single `Text` as before.

private enum MarkdownParagraphSegment {
    case text(AttributedString)
    case image(URL, alt: String)
}

private func paragraphSegments(from text: AttributedString) -> [MarkdownParagraphSegment] {
    var segments: [MarkdownParagraphSegment] = []
    var currentText = AttributedString()
    for run in text.runs {
        if let url = run.imageURL {
            if !currentText.characters.isEmpty {
                segments.append(.text(currentText))
                currentText = AttributedString()
            }
            let alt = String(text[run.range].characters)
            segments.append(.image(url, alt: alt))
        } else {
            currentText += AttributedString(text[run.range])
        }
    }
    if !currentText.characters.isEmpty || segments.isEmpty {
        segments.append(.text(currentText))
    }
    return segments
}

private struct MarkdownParagraphView: View {
    @EnvironmentObject var theme: ThemeStore
    let text: AttributedString

    var body: some View {
        let segments = paragraphSegments(from: text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let t):
                    Text(t)
                        .font(theme.bodyFont(15))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                case .image(let url, let alt):
                    MarkdownImageView(url: url, alt: alt)
                }
            }
        }
    }
}

/// Displays a markdown image reference. `cazzy-note-image:` URLs (from the toolbar's Insert
/// Image button, via NoteImageStore) resolve to a local file and load synchronously through
/// AppKit; anything else (a plain file:// path or an http(s) URL typed in by hand) goes
/// through AsyncImage instead.
private struct MarkdownImageView: View {
    let url: URL
    let alt: String

    private var resolvedURL: URL {
        NoteImageStore.resolve(url) ?? url
    }

    var body: some View {
        Group {
            if resolvedURL.isFileURL {
                if let nsImage = NSImage(contentsOf: resolvedURL) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 520)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    unavailableView
                }
            } else {
                AsyncImage(url: resolvedURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 520)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    case .failure:
                        unavailableView
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }

    private var unavailableView: some View {
        Label(alt.isEmpty ? "Image unavailable" : alt, systemImage: "photo.badge.exclamationmark")
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(8)
    }
}

// MARK: - Table rendering

private struct MarkdownTableView: View {
    @EnvironmentObject var theme: ThemeStore
    let columns: [PresentationIntent.TableColumn]
    let header: [AttributedString]
    let rows: [[AttributedString]]

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                ForEach(Array(header.enumerated()), id: \.offset) { index, cell in
                    Text(cell)
                        .font(theme.bodyFont(13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .textSelection(.enabled)
                        .gridColumnAlignment(alignment(for: index))
                }
            }
            Divider().gridCellColumns(max(header.count, 1))
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                        Text(cell)
                            .font(theme.bodyFont(13))
                            .foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled)
                            .gridColumnAlignment(alignment(for: index))
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.cardBackground.opacity(0.5)))
    }

    private func alignment(for columnIndex: Int) -> HorizontalAlignment {
        guard columns.indices.contains(columnIndex) else { return .leading }
        switch columns[columnIndex].alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        @unknown default: return .leading
        }
    }
}

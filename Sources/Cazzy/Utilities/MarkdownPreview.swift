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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(ExecBlockParser.parse(markdown)) { segment in
                    switch segment {
                    case .text(let content):
                        MarkdownBlocksView(content: content)
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .scrollContentBackground(.hidden)
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
// instead of text) and underline (`<u>text</u>` — Markdown has no native underline syntax,
// and Apple's parser leaves the literal `<u>`/`</u>` characters on screen rather than
// styling them, so they're swapped for sentinel characters before parsing and turned into a
// real `.underlineStyle` afterward — see `preprocessUnderline`/`applyUnderlineMarkers`).

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

// MARK: - <u>underline</u> via sentinel markers

private let underlineStartMarker: Character = "\u{E000}"
private let underlineEndMarker: Character = "\u{E001}"

private func preprocessUnderline(_ text: String) -> String {
    text
        .replacingOccurrences(of: "<u>", with: String(underlineStartMarker), options: .caseInsensitive)
        .replacingOccurrences(of: "</u>", with: String(underlineEndMarker), options: .caseInsensitive)
}

/// Turns each sentinel-marker pair left by `preprocessUnderline` back into a real underline
/// on the text between them, then removes the markers. Only matches pairs within the same
/// block (a `<u>` spanning multiple paragraphs/list items won't underline) — an accepted
/// limitation given how rarely that's intentional.
private func applyUnderlineMarkers(_ input: AttributedString) -> AttributedString {
    var result = input
    while let start = result.characters.firstIndex(of: underlineStartMarker) {
        result.characters.remove(at: start)
        guard let end = result.characters[start...].firstIndex(of: underlineEndMarker) else { continue }
        result.characters.remove(at: end)
        result[start..<end].underlineStyle = .single
    }
    return result
}

private func markdownBlocks(from text: String) -> [MarkdownBlock] {
    let preprocessed = preprocessUnderline(
        text
            .replacingOccurrences(of: "- [ ] ", with: "☐ ")
            .replacingOccurrences(of: "- [x] ", with: "☑ ")
    )

    guard let full = try? AttributedString(
        markdown: preprocessed,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
    ) else {
        return [MarkdownBlock(id: 0, kind: .paragraph, text: applyUnderlineMarkers(AttributedString(preprocessed)))]
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
        blocks.append(MarkdownBlock(id: blocks.count, kind: markdownBlockKind(for: currentComponents), text: applyUnderlineMarkers(currentText)))
        currentText = AttributedString()
        currentIdentity = nil
    }

    func flushTable() {
        guard tableIdentity != nil else { return }
        let columnCount = tableColumns.count
        let header = (0..<columnCount).map { applyUnderlineMarkers(tableHeaderCells[$0] ?? AttributedString()) }
        let rows = tableRows.keys.sorted().map { rowIndex in
            (0..<columnCount).map { column in applyUnderlineMarkers(tableRows[rowIndex]?[column] ?? AttributedString()) }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(markdownBlocks(from: content)) { block in
                render(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

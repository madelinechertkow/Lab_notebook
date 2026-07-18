import SwiftUI

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
// quotes, code blocks) as `presentationIntent` metadata on each run, but a single `Text`
// never applies that metadata visually, and the parsed string drops the newlines between
// blocks entirely — so headers, list items, quotes, and paragraphs all rendered as one
// run-on line with no distinguishing style. This splits the parse into one block per
// paragraph-level intent (grouped by the intent's stable `identity`) and renders each
// block according to its kind instead of relying on `Text` to infer it.

private enum MarkdownBlockKind {
    case header(level: Int)
    case paragraph
    case listItem(ordered: Bool, ordinal: Int, depth: Int)
    case blockQuote
    case codeBlock(language: String?)
    case thematicBreak
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

private func markdownBlocks(from text: String) -> [MarkdownBlock] {
    let preprocessed = text
        .replacingOccurrences(of: "- [ ] ", with: "☐ ")
        .replacingOccurrences(of: "- [x] ", with: "☑ ")

    guard let full = try? AttributedString(
        markdown: preprocessed,
        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
    ) else {
        return [MarkdownBlock(id: 0, kind: .paragraph, text: AttributedString(preprocessed))]
    }

    var blocks: [MarkdownBlock] = []
    var currentIdentity: Int?
    var currentComponents: [PresentationIntent.IntentType] = []
    var currentText = AttributedString()

    func flush() {
        guard currentIdentity != nil else { return }
        blocks.append(MarkdownBlock(id: blocks.count, kind: markdownBlockKind(for: currentComponents), text: currentText))
        currentText = AttributedString()
    }

    for run in full.runs {
        let components = run.presentationIntent?.components ?? []
        let identity = components.first?.identity
        if identity != currentIdentity {
            flush()
            currentIdentity = identity
            currentComponents = components
        }
        currentText += AttributedString(full[run.range])
    }
    flush()

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
            Text(block.text)
                .font(theme.bodyFont(15))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)

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
        }
    }
}

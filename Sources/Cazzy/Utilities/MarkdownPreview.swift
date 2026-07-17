import SwiftUI

struct MarkdownPreview: View {
    @EnvironmentObject var theme: ThemeStore
    let markdown: String
    var executionLanguage: ExecutionLanguage? = nil
    var codeBlockResults: [String: CodeBlockResult] = [:]
    var onResult: (CodeBlockResult) -> Void = { _ in }

    private func rendered(_ text: String) -> AttributedString {
        let preprocessed = text
            .replacingOccurrences(of: "- [ ] ", with: "☐ ")
            .replacingOccurrences(of: "- [x] ", with: "☑ ")
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        if let full = try? AttributedString(
            markdown: preprocessed,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full)
        ) {
            return full
        }
        return (try? AttributedString(markdown: preprocessed, options: options)) ?? AttributedString(preprocessed)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(ExecBlockParser.parse(markdown)) { segment in
                    switch segment {
                    case .text(let content):
                        Text(rendered(content))
                            .font(theme.bodyFont(15))
                            .foregroundStyle(theme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case .exec(let id, let code):
                        ExecBlockView(
                            blockID: id,
                            code: code,
                            language: executionLanguage,
                            result: codeBlockResults[id],
                            onResult: onResult
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }
}

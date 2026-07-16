import SwiftUI

struct MarkdownPreview: View {
    @EnvironmentObject var theme: ThemeStore
    let markdown: String

    private var rendered: AttributedString {
        let preprocessed = markdown
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
            Text(rendered)
                .font(theme.bodyFont(15))
                .foregroundStyle(theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
    }
}

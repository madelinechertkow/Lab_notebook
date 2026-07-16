import SwiftUI
import AppKit

final class EditorController: ObservableObject {
    weak var textView: NSTextView?

    func wrapSelection(prefix: String, suffix: String? = nil) {
        guard let textView, let storage = textView.textStorage else { return }
        let suffixText = suffix ?? prefix
        let range = textView.selectedRange()
        let nsString = storage.string as NSString

        if range.length > 0 {
            let selected = nsString.substring(with: range)
            let replacement = prefix + selected + suffixText
            textView.insertText(replacement, replacementRange: range)
            textView.setSelectedRange(NSRange(location: range.location + (prefix as NSString).length,
                                               length: (selected as NSString).length))
        } else {
            textView.insertText(prefix + suffixText, replacementRange: range)
            textView.setSelectedRange(NSRange(location: range.location + (prefix as NSString).length, length: 0))
        }
        textView.didChangeText()
    }

    func prefixCurrentLines(with prefix: String) {
        guard let textView, let storage = textView.textStorage else { return }
        let nsString = storage.string as NSString
        let selRange = textView.selectedRange()
        let lineRange = nsString.lineRange(for: selRange)
        let lineText = nsString.substring(with: lineRange)
        let lines = lineText.components(separatedBy: "\n")

        var rebuilt: [String] = []
        for line in lines {
            if line.isEmpty {
                rebuilt.append(line)
            } else if line.hasPrefix(prefix) {
                rebuilt.append(String(line.dropFirst(prefix.count)))
            } else {
                rebuilt.append(prefix + line)
            }
        }
        let newText = rebuilt.joined(separator: "\n")
        textView.insertText(newText, replacementRange: lineRange)
        textView.setSelectedRange(NSRange(location: lineRange.location, length: (newText as NSString).length))
        textView.didChangeText()
    }
}

struct FormattingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var controller: EditorController
    var font: NSFont = .systemFont(ofSize: 14)
    var textColor: NSColor = .labelColor
    var accentColor: NSColor = .controlAccentColor

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 6, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.insertionPointColor = accentColor

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        controller.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = accentColor
        controller.textView = textView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FormattingTextEditor
        init(_ parent: FormattingTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

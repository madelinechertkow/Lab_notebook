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

    /// Inserts a multi-line block (e.g. a code-fence template) at the cursor, placing the
    /// cursor inside it rather than selecting/wrapping existing text.
    func insertBlock(_ text: String, cursorOffset: Int) {
        guard let textView, let storage = textView.textStorage else { return }
        let range = textView.selectedRange()
        let nsString = storage.string as NSString
        let newline: unichar = 10
        let needsLeadingNewline = range.location > 0 && nsString.character(at: range.location - 1) != newline
        let insertion = (needsLeadingNewline ? "\n" : "") + text + "\n"
        textView.insertText(insertion, replacementRange: range)
        let cursorLocation = range.location + (needsLeadingNewline ? 1 : 0) + cursorOffset
        textView.setSelectedRange(NSRange(location: cursorLocation, length: 0))
        textView.didChangeText()
    }

    /// Inserts text at the cursor (replacing any selection) with the cursor left right after
    /// it — used by the special-character picker, which has no wrapping semantics.
    func insertText(_ text: String) {
        guard let textView else { return }
        let range = textView.selectedRange()
        textView.insertText(text, replacementRange: range)
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
            // Blank separator lines within a multi-line selection stay blank (so a paragraph
            // break doesn't grow a stray bullet); a lone blank line — e.g. a brand-new note —
            // still needs the prefix, or these buttons would never do anything on it.
            if line.isEmpty && lines.count > 1 {
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

/// An `NSTextView` that lets user-defined `SpecialCharacterShortcut`s override AppKit's
/// default key-equivalent handling, so a custom keystroke can insert arbitrary text instead
/// of whatever the OS/keyboard layout would normally produce.
final class ShortcutAwareTextView: NSTextView {
    var shortcuts: [SpecialCharacterShortcut] = []

    override func keyDown(with event: NSEvent) {
        if let match = shortcuts.first(where: { $0.matches(event) }) {
            insertText(match.insertText, replacementRange: selectedRange())
            return
        }
        super.keyDown(with: event)
    }
}

struct FormattingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var controller: EditorController
    var font: NSFont = .systemFont(ofSize: 14)
    var textColor: NSColor = .labelColor
    var accentColor: NSColor = .controlAccentColor
    var shortcuts: [SpecialCharacterShortcut] = []

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ShortcutAwareTextView()
        textView.shortcuts = shortcuts
        textView.delegate = context.coordinator
        textView.layoutManager?.delegate = context.coordinator
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
        // Gives this text view AppKit's own native find bar (same one TextEdit/Xcode use —
        // highlighting, match count, Next/Previous) the first time a find action reaches it,
        // with no custom UI needed. Wired up via performTextFinderAction: from CazzyApp's ⌘F.
        textView.usesFindBar = true
        // Without this, matches only flash briefly (a "find indicator") as you move between
        // them instead of staying highlighted — this keeps every match highlighted the whole
        // time the find bar is active, which is what was asked for.
        textView.isIncrementalSearchingEnabled = true
        // The "current" match during a find is just a regular text selection under the hood,
        // so theming it (rather than leaving AppKit's default system blue) is what makes it
        // match the app's palette instead of looking out of place.
        textView.selectedTextAttributes = [.backgroundColor: accentColor.withAlphaComponent(0.55)]

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        controller.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // Keeps the coordinator's copy of `accentColor` current for its layoutManager
        // delegate callback below, which fires later/async during drawing and would
        // otherwise keep using whatever color was live the one time makeCoordinator() ran.
        context.coordinator.parent = self

        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        // Reassigning `.font` on a plain-text NSTextView (isRichText = false) restyles the
        // whole document and forces a full layout pass, not just the typing attributes. Since
        // updateNSView runs on every keystroke (each character re-renders the SwiftUI view),
        // doing that unconditionally made the scroll position visibly jump while typing.
        // Only touch these when they've actually changed (note switch, theme change).
        if textView.font != font {
            textView.font = font
        }
        if textView.textColor != textColor {
            textView.textColor = textColor
        }
        if textView.insertionPointColor != accentColor {
            textView.insertionPointColor = accentColor
            textView.selectedTextAttributes = [.backgroundColor: accentColor.withAlphaComponent(0.55)]
        }
        (textView as? ShortcutAwareTextView)?.shortcuts = shortcuts
        controller.textView = textView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate, NSLayoutManagerDelegate {
        var parent: FormattingTextEditor
        init(_ parent: FormattingTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        /// Recolors the temporary background AppKit paints behind every find/incremental-
        /// search match (normally a fixed system yellow) to the app's own accent color, so
        /// it matches whichever theme is active instead of clashing with it.
        func layoutManager(
            _ layoutManager: NSLayoutManager,
            shouldUseTemporaryAttributes attrs: [NSAttributedString.Key: Any] = [:],
            forDrawingToScreen toScreen: Bool,
            atCharacterIndex charIndex: Int,
            effectiveRange effectiveCharRange: NSRangePointer?
        ) -> [NSAttributedString.Key: Any]? {
            guard attrs[.backgroundColor] != nil else { return nil }
            var replaced = attrs
            replaced[.backgroundColor] = parent.accentColor.withAlphaComponent(0.28)
            return replaced
        }
    }
}

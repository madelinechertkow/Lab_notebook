import SwiftUI
import AppKit

struct EditorView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let noteID: UUID

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isPreview: Bool = false
    @StateObject private var controller = EditorController()

    private var currentNote: Note? {
        store.notes.first(where: { $0.id == noteID })
    }

    private var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                TextField("Untitled", text: $title)
                    .textFieldStyle(.plain)
                    .font(theme.displayFont(26))
                    .foregroundStyle(theme.textPrimary)
                    .onChange(of: title) { _ in persist() }

                Spacer()

                Button {
                    isPreview.toggle()
                } label: {
                    Image(systemName: isPreview ? "pencil" : "eye")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accentDeep)
                .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            TagRow(tags: $tags, newTag: $newTag, onCommit: persist)
                .padding(.horizontal, 24)
                .padding(.top, 8)

            if !isPreview {
                FormattingToolbar(controller: controller)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }

            Divider().overlay(theme.divider).padding(.top, 10)

            if isPreview {
                MarkdownPreview(markdown: content)
            } else {
                FormattingTextEditor(
                    text: $content,
                    controller: controller,
                    font: nsFont(for: theme.theme.bodyFont, size: 14),
                    textColor: NSColor(theme.textPrimary),
                    accentColor: NSColor(theme.accentDeep)
                )
                .padding(.horizontal, 16)
                .onChange(of: content) { _ in persist() }
            }

            HStack {
                Text("\(wordCount) words")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textTertiary)
                Spacer()
                if let currentNote {
                    Text("Edited \(currentNote.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(theme.bodyFont(11))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .background(theme.editorBackground)
        .onAppear(perform: loadFromNote)
        .onChange(of: noteID) { _ in loadFromNote() }
        .onChange(of: store.undoTick) { _ in loadFromNote() }
    }

    private func loadFromNote() {
        guard let currentNote else { return }
        title = currentNote.title
        content = currentNote.content
        tags = currentNote.tags
    }

    private func persist() {
        guard var updated = currentNote else { return }
        updated.title = title
        updated.content = content
        updated.tags = tags
        store.updateNote(updated)
    }

    private func nsFont(for choice: FontChoice, size: CGFloat) -> NSFont {
        switch choice {
        case .serif:
            return NSFont(name: "New York", size: size) ?? NSFont.systemFont(ofSize: size)
        case .rounded:
            if let descriptor = NSFont.systemFont(ofSize: size).fontDescriptor.withDesign(.rounded) {
                return NSFont(descriptor: descriptor, size: size) ?? NSFont.systemFont(ofSize: size)
            }
            return NSFont.systemFont(ofSize: size)
        case .defaultSystem:
            return NSFont.systemFont(ofSize: size)
        case .monospaced:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .georgia:
            return NSFont(name: "Georgia", size: size) ?? NSFont.systemFont(ofSize: size)
        case .avenirNext:
            return NSFont(name: "Avenir Next", size: size) ?? NSFont.systemFont(ofSize: size)
        case .futura:
            return NSFont(name: "Futura", size: size) ?? NSFont.systemFont(ofSize: size)
        case .palatino:
            return NSFont(name: "Palatino", size: size) ?? NSFont.systemFont(ofSize: size)
        case .optima:
            return NSFont(name: "Optima", size: size) ?? NSFont.systemFont(ofSize: size)
        case .menlo:
            return NSFont(name: "Menlo", size: size) ?? NSFont.systemFont(ofSize: size)
        case .baskerville:
            return NSFont(name: "Baskerville", size: size) ?? NSFont.systemFont(ofSize: size)
        }
    }
}

struct TagRow: View {
    @EnvironmentObject var theme: ThemeStore
    @Binding var tags: [String]
    @Binding var newTag: String
    var onCommit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text(tag)
                        .font(theme.bodyFont(11, weight: .medium))
                    Button {
                        tags.removeAll { $0 == tag }
                        onCommit()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(theme.secondaryAccent.opacity(0.3)))
                .foregroundStyle(theme.accentDeep)
            }

            TextField("+ tag", text: $newTag)
                .textFieldStyle(.plain)
                .font(theme.bodyFont(11))
                .frame(width: 70)
                .onSubmit {
                    let trimmed = newTag.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !tags.contains(trimmed) {
                        tags.append(trimmed)
                    }
                    newTag = ""
                    onCommit()
                }

            Spacer()
        }
    }
}

struct FormattingToolbar: View {
    @EnvironmentObject var theme: ThemeStore
    @ObservedObject var controller: EditorController

    var body: some View {
        HStack(spacing: 8) {
            toolButton("bold", "Bold") { controller.wrapSelection(prefix: "**") }
            toolButton("italic", "Italic") { controller.wrapSelection(prefix: "*") }
            toolButton("chevron.left.slash.chevron.right", "Code") { controller.wrapSelection(prefix: "`") }
            Divider().frame(height: 14)
            toolButton("textformat.size.larger", "Heading") { controller.prefixCurrentLines(with: "## ") }
            toolButton("list.bullet", "Bullet list") { controller.prefixCurrentLines(with: "- ") }
            toolButton("checklist", "Checklist") { controller.prefixCurrentLines(with: "- [ ] ") }
            Spacer()
        }
    }

    private func toolButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white.opacity(0.5)))
        .help(help)
    }
}

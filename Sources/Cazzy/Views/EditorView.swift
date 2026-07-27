import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditorView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var shortcuts: ShortcutStore
    let noteID: UUID

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var isPreview: Bool = false
    @State private var executionLanguage: ExecutionLanguage?
    @State private var codeEnvironmentID: UUID?
    @State private var showingEnvironmentManager = false
    @State private var codeBlockResults: [String: CodeBlockResult] = [:]
    @State private var plateMapResults: [String: PlateMapInstance] = [:]
    @State private var gelMapResults: [String: GelMapInstance] = [:]
    @State private var showingGelImagePicker = false
    @State private var showingImagePicker = false
    @StateObject private var controller = EditorController()

    private var currentNote: Note? {
        store.notes.first(where: { $0.id == noteID })
    }

    private var currentNotebook: Notebook? {
        guard let currentNote else { return nil }
        return store.notebooks.first(where: { $0.id == currentNote.notebookID })
    }

    /// Script execution is a dry-lab-only capability — wet-lab (and uncategorized) notebooks
    /// don't get code blocks at all.
    private var allowsScripts: Bool {
        currentNotebook?.labMode == .dry
    }

    /// Plate maps and gel maps are wet-lab benchwork tools — dry-lab notebooks don't get them.
    private var allowsPlateGelMaps: Bool {
        currentNotebook?.labMode != .dry
    }

    private var selectedCodeEnvironment: CodeEnvironment? {
        guard let codeEnvironmentID else { return nil }
        return store.codeEnvironments.first(where: { $0.id == codeEnvironmentID })
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

                if allowsScripts {
                    Menu {
                        Button("No code execution") { executionLanguage = nil; persist() }
                        Divider()
                        ForEach(ExecutionLanguage.allCases) { language in
                            Button(language.displayName) { executionLanguage = language; persist() }
                        }
                    } label: {
                        Label(executionLanguage?.displayName ?? "No code execution", systemImage: executionLanguage?.symbol ?? "chevron.left.forwardslash.chevron.right")
                            .font(theme.bodyFont(11, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 8)

                    Menu {
                        Button("No environment") { codeEnvironmentID = nil; persist() }
                        if !store.codeEnvironments.isEmpty {
                            Divider()
                            ForEach(store.codeEnvironments) { environment in
                                Button(environment.name) { codeEnvironmentID = environment.id; persist() }
                            }
                        }
                        Divider()
                        Button("Manage Environments…") { showingEnvironmentManager = true }
                    } label: {
                        Label(selectedCodeEnvironment?.name ?? "No environment", systemImage: "terminal")
                            .font(theme.bodyFont(11, weight: .medium))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 8)
                }

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
                FormattingToolbar(
                    controller: controller,
                    allowsScripts: allowsScripts,
                    allowsPlateGelMaps: allowsPlateGelMaps,
                    plateMapTemplates: store.plateMapTemplates,
                    specialCharacters: shortcuts.shortcuts,
                    onInsertPlateMap: insertPlateMap,
                    onInsertGelMap: { showingGelImagePicker = true },
                    onInsertImage: { showingImagePicker = true }
                )
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            Divider().overlay(theme.divider).padding(.top, 10)

            if isPreview {
                MarkdownPreview(
                    markdown: content,
                    executionLanguage: executionLanguage,
                    codeEnvironment: selectedCodeEnvironment,
                    codeBlockResults: codeBlockResults,
                    onResult: { result in
                        codeBlockResults[result.id] = result
                        persist()
                    },
                    onCodeChange: { blockID, newCode in
                        content = ExecBlockParser.replacingExecCode(in: content, blockID: blockID, newCode: newCode)
                        persist()
                    },
                    plateMapResults: plateMapResults,
                    onPlateMapChange: { id, instance in
                        plateMapResults[id] = instance
                        persist()
                    },
                    gelMapResults: gelMapResults,
                    onGelMapChange: { id, instance in
                        gelMapResults[id] = instance
                        persist()
                    }
                )
            } else {
                FormattingTextEditor(
                    text: $content,
                    controller: controller,
                    font: nsFont(for: theme.theme.bodyFont, size: 14),
                    textColor: NSColor(theme.textPrimary),
                    accentColor: NSColor(theme.accentDeep),
                    shortcuts: shortcuts.shortcuts
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
        .onChange(of: store.undoTick) { _ in loadFromNote() }
        .fileImporter(isPresented: $showingGelImagePicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                insertGelMap(from: url)
            }
        }
        .fileImporter(isPresented: $showingImagePicker, allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                insertImage(from: url)
            }
        }
        .sheet(isPresented: $showingEnvironmentManager) {
            CodeEnvironmentManagerView()
        }
    }

    private func loadFromNote() {
        guard let currentNote else { return }
        title = currentNote.title
        content = currentNote.content
        tags = currentNote.tags
        executionLanguage = currentNote.executionLanguage
        codeEnvironmentID = currentNote.codeEnvironmentID
        codeBlockResults = currentNote.codeBlockResults
        plateMapResults = currentNote.plateMapResults
        gelMapResults = currentNote.gelMapResults
    }

    private func persist() {
        guard var updated = currentNote else { return }
        updated.title = title
        updated.content = content
        updated.tags = tags
        updated.executionLanguage = executionLanguage
        updated.codeEnvironmentID = codeEnvironmentID
        updated.codeBlockResults = codeBlockResults
        updated.plateMapResults = plateMapResults
        updated.gelMapResults = gelMapResults
        store.updateNote(updated)
    }

    /// Inserts a new ```platemap block at the cursor and seeds its note-local instance data —
    /// a copy of the template's layout (or a blank plate of the given size), never a live
    /// reference back to the template.
    private func insertPlateMap(template: PlateMapTemplate?, size: PlateSize) {
        let id = ExecBlockParser.newBlockID()
        let block = ExecBlockParser.plateMapTemplate(id: id)
        controller.insertBlock(block.text, cursorOffset: block.cursorOffset)
        plateMapResults[id] = PlateMapInstance(
            size: template?.size ?? size,
            wells: template?.wells ?? [:],
            sourceTemplateName: template?.name
        )
        persist()
    }

    /// Inserts a new ```gelmap block at the cursor and copies the chosen photo into
    /// Application Support/Cazzy/GelImages, seeding the note-local instance with just that
    /// filename — no ladder/lane labels yet, the user adds those from the block's own toolbar.
    private func insertGelMap(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let filename = try? GelImageStore.importImage(from: url) else { return }

        let id = ExecBlockParser.newBlockID()
        let block = ExecBlockParser.gelMapTemplate(id: id)
        controller.insertBlock(block.text, cursorOffset: block.cursorOffset)
        gelMapResults[id] = GelMapInstance(imageFileName: filename)
        persist()
    }

    /// Inserts a plain inline `![alt](...)` markdown image at the cursor, copying the chosen
    /// photo into Application Support/Cazzy/NoteImages first (see NoteImageStore) — unlike the
    /// gel map block, this is just regular content, rendered by MarkdownPreview in Preview mode.
    private func insertImage(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        guard let filename = try? NoteImageStore.importImage(from: url) else { return }

        let alt = url.deletingPathExtension().lastPathComponent
        controller.insertText(NoteImageStore.markdownReference(filename: filename, alt: alt))
        persist()
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
    var allowsScripts: Bool = true
    var allowsPlateGelMaps: Bool = true
    var plateMapTemplates: [PlateMapTemplate] = []
    var specialCharacters: [SpecialCharacterShortcut] = []
    var onInsertPlateMap: (PlateMapTemplate?, PlateSize) -> Void = { _, _ in }
    var onInsertGelMap: () -> Void = {}
    var onInsertImage: () -> Void = {}

    @State private var showingSpecialCharacters = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                toolButton("bold", "Bold") { controller.wrapSelection(prefix: "**") }
                toolButton("italic", "Italic") { controller.wrapSelection(prefix: "*") }
                toolButton("chevron.left.slash.chevron.right", "Code") { controller.wrapSelection(prefix: "`") }
                if allowsScripts {
                    toolButton("play.rectangle", "Insert code block") {
                        let block = ExecBlockParser.template()
                        controller.insertBlock(block.text, cursorOffset: block.cursorOffset)
                    }
                }
                Divider().frame(height: 14)
                toolButton("textformat.size.larger", "Heading") { controller.prefixCurrentLines(with: "## ") }
                toolButton("list.bullet", "Bullet list") { controller.prefixCurrentLines(with: "- ") }
                toolButton("checklist", "Checklist") { controller.prefixCurrentLines(with: "- [ ] ") }
                Divider().frame(height: 14)
                specialCharacterButton
                toolButton("photo", "Insert image") { onInsertImage() }
                if allowsPlateGelMaps {
                    Divider().frame(height: 14)
                    plateMapMenu
                    toolButton("chart.bar.doc.horizontal", "Insert gel map") { onInsertGelMap() }
                }
            }
        }
    }

    private var specialCharacterButton: some View {
        Button {
            showingSpecialCharacters = true
        } label: {
            Image(systemName: "character")
                .font(.system(size: 12))
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.cardBackground.opacity(0.5)))
        .help("Insert special character")
        .popover(isPresented: $showingSpecialCharacters, arrowEdge: .bottom) {
            SpecialCharacterPicker(characters: specialCharacters) { shortcut in
                controller.insertText(shortcut.insertText)
                showingSpecialCharacters = false
            }
            .environmentObject(theme)
        }
    }

    private var plateMapMenu: some View {
        Menu {
            ForEach(PlateSize.allCases) { size in
                Button("Blank \(size.label)") { onInsertPlateMap(nil, size) }
            }
            if !plateMapTemplates.isEmpty {
                Divider()
                ForEach(plateMapTemplates) { template in
                    Button("\(template.name) (\(template.size.label))") { onInsertPlateMap(template, template.size) }
                }
            }
        } label: {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 12))
                .frame(width: 26, height: 22)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(theme.textPrimary)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.cardBackground.opacity(0.5)))
        .help("Insert plate map")
    }

    private func toolButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: 26, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.cardBackground.opacity(0.5)))
        .help(help)
    }
}

/// A grid of the user's configured special characters. Hovering a tile shows its name and
/// keystroke combo (via `.help`); clicking inserts it at the cursor and dismisses the popover.
private struct SpecialCharacterPicker: View {
    @EnvironmentObject var theme: ThemeStore
    var characters: [SpecialCharacterShortcut]
    var onSelect: (SpecialCharacterShortcut) -> Void

    private let columns = Array(repeating: GridItem(.fixed(36), spacing: 4), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Special Characters")
                .font(theme.bodyFont(11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            if characters.isEmpty {
                Text("No special characters configured yet. Add some from Settings → Special Characters.")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 200)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(characters) { shortcut in
                            Button {
                                onSelect(shortcut)
                            } label: {
                                Text(shortcut.insertText)
                                    .font(.system(size: 16))
                                    .frame(width: 36, height: 32)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.textPrimary)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.editorBackground))
                            .help("\(shortcut.label) (\(shortcut.displayCombo))")
                        }
                    }
                }
                .frame(width: 320, height: 320)
            }
        }
        .padding(12)
    }
}

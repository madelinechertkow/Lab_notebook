import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum NotebookContentTab: String, CaseIterable, Identifiable {
    case notes, files
    var id: String { rawValue }
    var label: String {
        switch self {
        case .notes: return "Notes"
        case .files: return "Files"
        }
    }
}

struct NoteListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    var sidebarSelection: SidebarItem?
    @Binding var selectedNoteID: UUID?
    @Binding var searchText: String
    @State private var contentTab: NotebookContentTab = .notes
    @State private var relinkTarget: LinkedFile?
    @State private var isDropTargeting: Bool = false

    private var notebookID: UUID? {
        if case .notebook(let id) = sidebarSelection { return id }
        return nil
    }

    /// Tags are a cross-cutting grouping rather than notebook-scoped, so selecting one
    /// searches across every visible notebook (notebookID stays nil whenever a tag is active).
    private var selectedTag: String? {
        if case .tag(let name) = sidebarSelection { return name }
        return nil
    }

    private var notes: [Note] {
        store.search(searchText, in: notebookID, tag: selectedTag)
    }

    private var archivedNotes: [Note] {
        store.archivedNotes(in: notebookID, tag: selectedTag)
    }

    private var titleText: String {
        if let selectedTag { return "#\(selectedTag)" }
        if let notebookID, let nb = store.notebooks.first(where: { $0.id == notebookID }) {
            return nb.name
        }
        return "All Notes"
    }

    private var showsFileTab: Bool { notebookID != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(titleText)
                    .font(theme.displayFont(20))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if showsFileTab && contentTab == .files {
                    Button(action: importFiles) {
                        Image(systemName: "square.and.arrow.down.on.square")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accentDeep)
                    .help("Import a file (Word doc, PDF, etc.) — it stays linked to its original location")
                } else {
                    Button(action: createNote) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accentDeep)
                    .disabled(store.visibleNotebooks().isEmpty)
                    .help("New note")
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if showsFileTab {
                Picker("", selection: $contentTab) {
                    ForEach(NotebookContentTab.allCases) { tab in
                        Text(tab.label).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            if contentTab == .files, let notebookID {
                Divider().overlay(theme.divider)
                filesList(for: notebookID)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(theme.textSecondary)
                        .font(.system(size: 12))
                    TextField("Search notes", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(theme.bodyFont(13))
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cardBackground.opacity(0.6)))
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

                Divider().overlay(theme.divider)

                notesList
            }
        }
        .background(theme.background)
    }

    // NSAlert instead of SwiftUI's .alert(item:): a confirmation triggered from inside a
    // .contextMenu action doesn't reliably present as a SwiftUI alert on macOS — the menu's
    // own dismissal races with the alert's presentation. Driving it through AppKit directly
    // sidesteps that (see the identical fix for notebook delete in SidebarView.swift).
    private func presentDeleteConfirmation(for note: Note, permanently: Bool) {
        let alert = NSAlert()
        alert.messageText = "\(permanently ? "Permanently delete" : "Delete") \"\(note.title.isEmpty ? "Untitled" : note.title)\"?"
        alert.informativeText = "You can undo this with ⌘Z."
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "Delete")
        deleteButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let wasSelected = selectedNoteID == note.id
        store.deleteNote(note)
        if wasSelected { selectedNoteID = nil }
    }

    private func presentRemoveLinkConfirmation(for file: LinkedFile) {
        let alert = NSAlert()
        alert.messageText = "Remove Link to \"\(file.fileName)\"?"
        alert.informativeText = "This only removes it from the notebook — the original file on disk is untouched."
        alert.alertStyle = .warning
        let removeButton = alert.addButton(withTitle: "Remove")
        removeButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.removeLinkedFile(file)
    }

    @ViewBuilder
    private var notesList: some View {
        if notes.isEmpty && archivedNotes.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(theme.textTertiary)
                Text("No notes yet")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
            }
            Spacer()
        } else {
            List(selection: $selectedNoteID) {
                if !notes.isEmpty {
                    let orderedNotes = notes
                    ForEach(orderedNotes) { note in
                        NoteRow(note: note)
                            .tag(note.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button {
                                    store.archiveNote(note)
                                } label: {
                                    Label("Archive Note", systemImage: "archivebox")
                                }
                                Button(role: .destructive) {
                                    presentDeleteConfirmation(for: note, permanently: false)
                                } label: {
                                    Label("Delete Note…", systemImage: "trash")
                                }
                            }
                    }
                    .onMove { source, destination in
                        store.moveNote(fromOffsets: source, toOffset: destination, in: orderedNotes)
                    }
                    .onDelete(perform: deleteNotes)
                }

                if !archivedNotes.isEmpty {
                    Section {
                        ForEach(archivedNotes) { note in
                            NoteRow(note: note)
                                .tag(note.id)
                                .opacity(0.6)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .contextMenu {
                                    Button {
                                        store.unarchiveNote(note)
                                    } label: {
                                        Label("Unarchive", systemImage: "arrow.uturn.backward")
                                    }
                                    Button(role: .destructive) {
                                        presentDeleteConfirmation(for: note, permanently: true)
                                    } label: {
                                        Label("Delete Permanently…", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text("Archived")
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private func filesList(for notebookID: UUID) -> some View {
        let files = store.linkedFiles(in: notebookID)
        ZStack {
            if files.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 26))
                        .foregroundStyle(theme.textTertiary)
                    Text("No files linked yet")
                        .font(theme.bodyFont(13))
                        .foregroundStyle(theme.textSecondary)
                    Text("Import a Word doc, PDF, or other file — it opens from its original location, so edits made elsewhere are always up to date. You can also drag files in here.")
                        .font(theme.bodyFont(11))
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 220)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(files) { file in
                        LinkedFileRow(file: file)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button {
                                    store.openLinkedFile(file)
                                } label: {
                                    Label("Open", systemImage: "arrow.up.forward.square")
                                }
                                Button {
                                    store.revealLinkedFileInFinder(file)
                                } label: {
                                    Label("Reveal in Finder", systemImage: "folder")
                                }
                                Button {
                                    relink(file)
                                } label: {
                                    Label("Relink…", systemImage: "link")
                                }
                                Button(role: .destructive) {
                                    presentRemoveLinkConfirmation(for: file)
                                } label: {
                                    Label("Remove Link…", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            if isDropTargeting {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.accentDeep, style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(theme.accentDeep.opacity(0.08)))
                    .padding(8)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeting) { providers in
            handleDrop(providers: providers, notebookID: notebookID)
        }
    }

    /// NSItemProvider hands file drops back as either a bridged NSURL or a raw
    /// plist-encoded Data blob depending on the drag source, so both are decoded here.
    private func handleDrop(providers: [NSItemProvider], notebookID: UUID) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                switch item {
                case let u as URL:
                    url = u
                case let data as Data:
                    url = URL(dataRepresentation: data, relativeTo: nil)
                default:
                    url = nil
                }
                guard let url else { return }
                DispatchQueue.main.async {
                    _ = try? store.linkFile(at: url, in: notebookID)
                }
            }
        }
        return true
    }

    private func createNote() {
        guard let targetNotebook = notebookID ?? store.visibleNotebooks().first?.id else { return }
        let note = store.createNote(in: targetNotebook, title: "Untitled")
        selectedNoteID = note.id
    }

    private func deleteNotes(at offsets: IndexSet) {
        let currentNotes = notes
        for index in offsets {
            store.deleteNote(currentNotes[index])
        }
    }

    private func importFiles() {
        guard let notebookID else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Link"
        panel.message = "Choose Word documents or other files to link into this notebook."
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                _ = try? store.linkFile(at: url, in: notebookID)
            }
        }
    }

    private func relink(_ file: LinkedFile) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Relink"
        panel.message = "Choose the new location of \"\(file.fileName)\"."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? store.relinkFile(file, to: url)
        }
    }
}

struct NoteRow: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let note: Note

    private var notebookName: String {
        store.notebooks.first(where: { $0.id == note.notebookID })?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(theme.bodyFont(14, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            if !notebookName.isEmpty {
                Text(notebookName)
                    .font(theme.bodyFont(12))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                ForEach(note.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(theme.bodyFont(9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.secondaryAccent.opacity(0.25)))
                        .foregroundStyle(theme.accentDeep)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .softCard(cornerRadius: 12)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}

/// A row for a `LinkedFile`. Unlike a note, tapping it doesn't select anything in this
/// app — it opens the real file (Word, Preview, etc.) at its original location, since
/// the whole point of linking rather than importing is that this app never becomes the
/// source of truth for the file's content.
struct LinkedFileRow: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let file: LinkedFile

    private var isMissing: Bool {
        store.resolvedURL(for: file) == nil
    }

    private var icon: NSImage {
        if let url = store.resolvedURL(for: file) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .item)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(file.fileName)
                    .font(theme.bodyFont(13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if isMissing {
                    Label("File not found — try Relink", systemImage: "exclamationmark.triangle.fill")
                        .font(theme.bodyFont(10))
                        .foregroundStyle(.orange)
                } else {
                    Text("Added \(file.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(theme.bodyFont(10))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "arrow.up.forward.square")
                .font(.system(size: 12))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .softCard(cornerRadius: 12)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            store.openLinkedFile(file)
        }
        .opacity(isMissing ? 0.6 : 1)
    }
}

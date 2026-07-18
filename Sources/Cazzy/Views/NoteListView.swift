import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    var sidebarSelection: SidebarItem?
    @Binding var selectedNoteID: UUID?
    @State private var searchText: String = ""
    @State private var notePendingDeletion: Note?

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

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(titleText)
                    .font(theme.displayFont(20))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button(action: createNote) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accentDeep)
                .disabled(store.visibleNotebooks().isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

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
                        ForEach(notes) { note in
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
                                        notePendingDeletion = note
                                    } label: {
                                        Label("Delete Note…", systemImage: "trash")
                                    }
                                }
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
                                            notePendingDeletion = note
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
        .background(theme.background)
        .alert(item: $notePendingDeletion) { note in
            Alert(
                title: Text("Delete \"\(note.title.isEmpty ? "Untitled" : note.title)\"?"),
                message: Text("You can undo this with ⌘Z."),
                primaryButton: .destructive(Text("Delete")) {
                    let wasSelected = selectedNoteID == note.id
                    store.deleteNote(note)
                    if wasSelected { selectedNoteID = nil }
                },
                secondaryButton: .cancel()
            )
        }
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
}

struct NoteRow: View {
    @EnvironmentObject var theme: ThemeStore
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title.isEmpty ? "Untitled" : note.title)
                .font(theme.bodyFont(14, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)

            if !note.preview.isEmpty {
                Text(note.preview)
                    .font(theme.bodyFont(12))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
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

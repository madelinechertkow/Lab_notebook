import SwiftUI
import AppKit

enum SidebarItem: Hashable {
    case all
    case notebook(UUID)
    case protocols
    case plateMaps
    case gelMaps
    case tag(String)
}

struct SidebarView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Binding var selection: SidebarItem?
    @Environment(\.openWindow) private var openWindow
    @State private var notebookPendingDeletion: Notebook?
    @State private var notebookBlockedFromArchiving: Notebook?
    @State private var showingNewNotebookPopover = false

    var body: some View {
        List(selection: $selection) {
            Section {
                Label {
                    HStack {
                        Text("All Notes")
                            .font(theme.bodyFont(13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(store.notes(in: nil).count)")
                            .font(theme.bodyFont(11))
                            .foregroundStyle(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(theme.accentDeep)
                }
                .tag(SidebarItem.all)

                Button {
                    openWindow(id: "todo")
                } label: {
                    Label {
                        HStack {
                            Text("To-Do")
                                .font(theme.bodyFont(13, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            let openCount = store.todos.filter { !$0.isDone }.count
                            if openCount > 0 {
                                Text("\(openCount)")
                                    .font(theme.bodyFont(11))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                    } icon: {
                        Image(systemName: "checklist")
                            .foregroundStyle(theme.tertiaryAccent)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    openWindow(id: "calendar")
                } label: {
                    Label {
                        HStack {
                            Text("Calendar")
                                .font(theme.bodyFont(13, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            let todayCount = store.experiments(on: Date()).count
                            if todayCount > 0 {
                                Text("\(todayCount)")
                                    .font(theme.bodyFont(11))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(theme.accent)
                    }
                }
                .buttonStyle(.plain)

                Label {
                    HStack {
                        Text("Protocols")
                            .font(theme.bodyFont(13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(store.protocols.count)")
                            .font(theme.bodyFont(11))
                            .foregroundStyle(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "list.clipboard.fill")
                        .foregroundStyle(theme.secondaryAccent)
                }
                .tag(SidebarItem.protocols)

                Label {
                    HStack {
                        Text("Plate Maps")
                            .font(theme.bodyFont(13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(store.plateMapTemplates.count)")
                            .font(theme.bodyFont(11))
                            .foregroundStyle(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "square.grid.3x3.fill")
                        .foregroundStyle(theme.tertiaryAccent)
                }
                .tag(SidebarItem.plateMaps)

                Label {
                    HStack {
                        Text("Gel Ladders")
                            .font(theme.bodyFont(13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Text("\(store.gelLadderPresets.count)")
                            .font(theme.bodyFont(11))
                            .foregroundStyle(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .foregroundStyle(theme.accent)
                }
                .tag(SidebarItem.gelMaps)
            }

            Section {
                ForEach(Array(store.visibleNotebooks().enumerated()), id: \.element.id) { index, notebook in
                    Label {
                        HStack {
                            Text(notebook.name)
                                .font(theme.bodyFont(13, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Text("\(store.notes(in: notebook.id).count)")
                                .font(theme.bodyFont(11))
                                .foregroundStyle(theme.textSecondary)
                        }
                    } icon: {
                        Image(systemName: notebook.symbol)
                            .foregroundStyle(theme.notebookAccent(index))
                    }
                    .tag(SidebarItem.notebook(notebook.id))
                    .contextMenu {
                        Button {
                            if !store.archiveNotebook(notebook) {
                                notebookBlockedFromArchiving = notebook
                            } else if selection == .notebook(notebook.id) {
                                selection = .all
                            }
                        } label: {
                            Label("Archive Notebook", systemImage: "archivebox")
                        }
                        Button(role: .destructive) {
                            notebookPendingDeletion = notebook
                        } label: {
                            Label("Delete Notebook…", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Notebooks")
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button {
                        showingNewNotebookPopover = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accentDeep)
                    .popover(isPresented: $showingNewNotebookPopover) {
                        NewNotebookPopover(defaultLabMode: store.labModeFilter.defaultLabModeForNewNotebook) { name, symbol, labMode in
                            let created = store.createNotebook(name: name, symbol: symbol, labMode: labMode)
                            selection = .notebook(created.id)
                            showingNewNotebookPopover = false
                        }
                    }
                }
            }

            if !store.archivedNotebooks().isEmpty {
                Section {
                    ForEach(store.archivedNotebooks()) { notebook in
                        Label {
                            HStack {
                                Text(notebook.name)
                                    .font(theme.bodyFont(13, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                Spacer()
                                Text("\(store.notes(in: notebook.id).count)")
                                    .font(theme.bodyFont(11))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        } icon: {
                            Image(systemName: notebook.symbol)
                                .foregroundStyle(theme.textTertiary)
                        }
                        .tag(SidebarItem.notebook(notebook.id))
                        .contextMenu {
                            Button {
                                store.unarchiveNotebook(notebook)
                            } label: {
                                Label("Unarchive", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                notebookPendingDeletion = notebook
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

            if !store.allTags().isEmpty {
                Section {
                    ForEach(store.allTags(), id: \.self) { tag in
                        Label {
                            HStack {
                                Text(tag)
                                    .font(theme.bodyFont(12))
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text("\(store.notes(in: nil, tag: tag).count)")
                                    .font(theme.bodyFont(11))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(theme.secondaryAccent)
                        }
                        .tag(SidebarItem.tag(tag))
                    }
                } header: {
                    Text("Tags")
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.sidebar)
        .alert(item: $notebookPendingDeletion) { notebook in
            guard store.notebooks.count > 1 else {
                return Alert(
                    title: Text("Can't Delete \"\(notebook.name)\""),
                    message: Text("This is your only notebook — new notes need somewhere to go, so at least one has to stay."),
                    dismissButton: .default(Text("OK"))
                )
            }
            let noteCount = store.notes(in: notebook.id).count
            return Alert(
                title: Text("Delete \"\(notebook.name)\"?"),
                message: Text(noteCount > 0
                    ? "This will also delete \(noteCount) note\(noteCount == 1 ? "" : "s") inside it. You can undo this with ⌘Z."
                    : "This notebook is empty. You can undo this with ⌘Z."),
                primaryButton: .destructive(Text("Delete")) {
                    let wasSelected = selection == .notebook(notebook.id)
                    store.deleteNotebook(notebook)
                    if wasSelected { selection = .all }
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $notebookBlockedFromArchiving) { notebook in
            Alert(
                title: Text("Can't Archive \"\(notebook.name)\""),
                message: Text("This is your only active notebook — new notes need somewhere to go, so at least one has to stay unarchived."),
                dismissButton: .default(Text("OK"))
            )
        }
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: store.labModeFilter.symbol)
                        .foregroundStyle(theme.accentDeep)
                    Text("Cazzy")
                        .font(theme.displayFont(20))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                }

                Picker("", selection: Binding(
                    get: { store.labModeFilter },
                    set: { store.setLabModeFilter($0) }
                )) {
                    ForEach(LabModeFilter.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NewNotebookPopover: View {
    let defaultLabMode: LabMode?
    let onCreate: (String, String, LabMode?) -> Void

    @State private var name = ""
    @State private var symbol: String
    @State private var labMode: LabMode?

    /// A small curated set rather than a full SF Symbols browser — matches the icons already
    /// used by `Notebook.defaults()` plus a few more common lab-notebook subjects, including
    /// some science-specific ones (atom, microbe, brain, DNA-adjacent hex grid) for variety.
    private static let symbolChoices = [
        "book.closed.fill", "cross.vial.fill", "chart.xyaxis.line", "terminal.fill",
        "books.vertical.fill", "pencil.and.outline", "person.2.fill", "sparkles",
        "flask.fill", "folder.fill", "tag.fill", "star.fill",
        "atom", "microbe.fill", "brain.head.profile", "waveform.path.ecg",
        "stethoscope", "thermometer", "bolt.fill", "globe.americas.fill",
        "moon.stars.fill", "eyedropper", "circle.hexagongrid.fill", "leaf.fill"
    ]

    init(defaultLabMode: LabMode?, onCreate: @escaping (String, String, LabMode?) -> Void) {
        self.defaultLabMode = defaultLabMode
        self.onCreate = onCreate
        self._symbol = State(initialValue: Self.symbolChoices[0])
        self._labMode = State(initialValue: defaultLabMode)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Notebook")
                .font(.system(size: 13, weight: .semibold))

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(create)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 6) {
                ForEach(Self.symbolChoices, id: \.self) { choice in
                    Button {
                        symbol = choice
                    } label: {
                        Image(systemName: choice)
                            .font(.system(size: 14))
                            .frame(width: 26, height: 26)
                            .background(
                                Circle().fill(symbol == choice ? Color.accentColor.opacity(0.25) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("Lab mode", selection: $labMode) {
                Text("Shared").tag(LabMode?.none)
                Text("Wet Lab").tag(LabMode?.some(.wet))
                Text("Dry Lab").tag(LabMode?.some(.dry))
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Spacer()
                Button("Create", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 240)
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        onCreate(trimmedName, symbol, labMode)
    }
}

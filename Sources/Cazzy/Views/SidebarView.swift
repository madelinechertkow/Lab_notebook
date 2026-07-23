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
                        NotebookSymbolIcon(symbol: notebook.symbol)
                            .foregroundStyle(theme.notebookAccent(index))
                    }
                    .tag(SidebarItem.notebook(notebook.id))
                    .contextMenu {
                        Button {
                            if !store.archiveNotebook(notebook) {
                                presentBlockedArchiveAlert(for: notebook)
                            } else if selection == .notebook(notebook.id) {
                                selection = .all
                            }
                        } label: {
                            Label("Archive Notebook", systemImage: "archivebox")
                        }
                        Button(role: .destructive) {
                            presentDeleteConfirmation(for: notebook)
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
                                presentDeleteConfirmation(for: notebook)
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

    // NSAlert instead of SwiftUI's .alert(item:): a confirmation triggered from inside a
    // .contextMenu action doesn't reliably present as a SwiftUI alert on macOS — the menu's
    // own dismissal races with the alert's presentation and it silently never shows up.
    // Driving it through AppKit directly sidesteps that.
    private func presentDeleteConfirmation(for notebook: Notebook) {
        let alert = NSAlert()
        guard store.canDeleteNotebook(notebook) else {
            alert.messageText = "Can't Delete \"\(notebook.name)\""
            alert.informativeText = "This is your only active notebook — new notes need somewhere to go, so at least one has to stay."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        let noteCount = store.notes(in: notebook.id).count
        alert.messageText = "Delete \"\(notebook.name)\"?"
        alert.informativeText = noteCount > 0
            ? "This will also delete \(noteCount) note\(noteCount == 1 ? "" : "s") inside it. You can undo this with ⌘Z."
            : "This notebook is empty. You can undo this with ⌘Z."
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "Delete")
        deleteButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let wasSelected = selection == .notebook(notebook.id)
        store.deleteNotebook(notebook)
        if wasSelected { selection = .all }
    }

    private func presentBlockedArchiveAlert(for notebook: Notebook) {
        let alert = NSAlert()
        alert.messageText = "Can't Archive \"\(notebook.name)\""
        alert.informativeText = "This is your only active notebook — new notes need somewhere to go, so at least one has to stay unarchived."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private struct NewNotebookPopover: View {
    let defaultLabMode: LabMode?
    let onCreate: (String, String, LabMode?) -> Void

    @State private var name = ""
    @State private var symbol: String
    @State private var labMode: LabMode?

    /// The original curated set, plus the SF Symbols "Health" category in full and a handful
    /// of other requested additions (animals, devices, interface windows, clock).
    private static let symbolChoices = [
        "book.closed.fill", "cross.vial.fill", "chart.xyaxis.line", "terminal.fill",
        "books.vertical.fill", "pencil.and.outline", "person.2.fill", "sparkles",
        "flask.fill", "folder.fill", "tag.fill", "star.fill",
        "atom", "microbe.fill", "brain.head.profile", "waveform.path.ecg",
        "stethoscope", "thermometer", "bolt.fill", "globe.americas.fill",
        "moon.stars.fill", "eyedropper", "circle.hexagongrid.fill", "leaf.fill",
        "cat.fill", "dog.fill", "lizard.fill", "fish.fill",
        "ant.fill", "snowflake", "pc", "macpro.gen3",
        "testtube.2", "macwindow", "text.and.command.macwindow", "keyboard.macwindow",
        "clock.fill", "allergens", "allergens.fill", "apple.meditate",
        "apple.meditate.circle", "apple.meditate.circle.fill", "apple.meditate.square.stack", "apple.meditate.square.stack.fill",
        "bandage", "bandage.fill", "bed.double", "bed.double.badge.checkmark",
        "bed.double.badge.checkmark.fill", "bed.double.circle", "bed.double.circle.fill", "bed.double.fill",
        "blood.pressure.cuff", "blood.pressure.cuff.badge.gauge.with.needle", "blood.pressure.cuff.badge.gauge.with.needle.fill", "blood.pressure.cuff.fill",
        "bolt.heart", "bolt.heart.fill", "brain", "brain.fill",
        "brain.filled.head.profile", "brain.head.profile.fill", "bubbles.and.sparkles", "bubbles.and.sparkles.fill",
        "chart.line.text.clipboard", "chart.line.text.clipboard.fill", "cross", "cross.case",
        "cross.case.circle", "cross.case.circle.fill", "cross.case.fill", "cross.circle",
        "cross.circle.fill", "cross.fill", "cross.vial", "ear",
        "ear.badge.checkmark", "ear.badge.waveform", "ear.fill", "ear.trianglebadge.exclamationmark",
        "eye", "eye.circle", "eye.circle.fill", "eye.fill",
        "eye.slash", "eye.slash.fill", "eye.square", "eye.square.fill",
        "eye.trianglebadge.exclamationmark", "eye.trianglebadge.exclamationmark.fill", "facemask", "facemask.fill",
        "hearingdevice.and.signal.meter", "hearingdevice.and.signal.meter.fill", "hearingdevice.ear", "hearingdevice.ear.fill",
        "heart", "heart.badge.bolt", "heart.badge.bolt.fill", "heart.badge.bolt.slash",
        "heart.badge.bolt.slash.fill", "heart.circle", "heart.circle.fill", "heart.fill",
        "heart.text.clipboard", "heart.text.clipboard.fill", "heart.text.square", "heart.text.square.fill",
        "ivfluid.bag", "ivfluid.bag.fill", "list.bullet.clipboard", "list.bullet.clipboard.fill",
        "list.clipboard", "list.clipboard.fill", "lock.heart", "lock.heart.fill",
        "lungs", "lungs.fill", "medical.thermometer", "medical.thermometer.fill",
        "microbe", "microbe.circle", "microbe.circle.fill", "pencil.and.list.clipboard",
        "pill", "pill.circle", "pill.circle.fill", "pill.fill",
        "pills", "pills.circle", "pills.circle.fill", "pills.fill",
        "sparkle.text.clipboard", "sparkle.text.clipboard.fill", "staroflife", "staroflife.circle",
        "staroflife.circle.fill", "staroflife.fill", "stethoscope.circle", "stethoscope.circle.fill",
        "syringe", "syringe.fill", "thermometer.variable", "thermometer.variable.and.figure",
        "thermometer.variable.and.figure.circle", "thermometer.variable.and.figure.circle.fill", "thermometer.variable.badge.clock", "thermometer.variable.badge.play",
        "vial.viewfinder", "waveform.path.ecg.rectangle", "waveform.path.ecg.rectangle.fill", "waveform.path.ecg.text.clipboard",
        "waveform.path.ecg.text.clipboard.fill"
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

            ScrollView {
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
            }
            .frame(maxHeight: 180)

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

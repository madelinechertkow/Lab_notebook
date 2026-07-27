import SwiftUI
import AppKit

/// Spreadsheet-style tracker for papers, modeled on the columns of a typical lab
/// "Paper Tracker" Excel sheet (identification / methods & data / science / project
/// relevance / citation). Core bibliographic + tracking fields are always-visible,
/// inline-editable table columns; the long narrative fields (methods, summary, etc.)
/// live behind a per-row details drawer, like expanding a cell in Numbers.
struct PaperTrackerView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore

    @State private var searchText: String = ""
    @State private var readStatusFilter: PaperReadStatus?
    @State private var followUpOnly: Bool = false
    @State private var selection: PaperEntry.ID?
    @State private var detailTarget: DetailTarget?

    private struct DetailTarget: Identifiable { let id: UUID }

    private var filteredEntries: [PaperEntry] {
        var base = store.paperEntries
        if let readStatusFilter {
            base = base.filter { $0.readStatus == readStatusFilter }
        }
        if followUpOnly {
            base = base.filter { $0.followUpNeeded }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            base = base.filter { entry in
                entry.firstAuthor.lowercased().contains(query)
                    || entry.lastAuthor.lowercased().contains(query)
                    || entry.title.lowercased().contains(query)
                    || entry.journal.lowercased().contains(query)
                    || entry.cancerType.lowercased().contains(query)
                    || entry.keyGenesTargets.lowercased().contains(query)
                    || entry.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }
        return base.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            filterBar
            Divider().overlay(theme.divider)

            if filteredEntries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 26))
                        .foregroundStyle(theme.textTertiary)
                    Text(store.paperEntries.isEmpty ? "No papers tracked yet" : "No papers match your filters")
                        .font(theme.bodyFont(13))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else {
                table
            }
        }
        .background(theme.background)
        .sheet(item: $detailTarget) { target in
            PaperDetailSheet(entryID: target.id)
        }
    }

    // NSAlert instead of SwiftUI's .alert(item:): a confirmation triggered from inside a
    // .contextMenu action doesn't reliably present as a SwiftUI alert on macOS — the menu's
    // own dismissal races with the alert's presentation. Driving it through AppKit directly
    // sidesteps that (see the identical fix in SidebarView.swift, NoteListView.swift, and
    // ProtocolListView.swift). Used uniformly here (not just the context-menu path) so the
    // toolbar button, right-click menu, and Delete key all share one confirmation.
    private func presentDeleteConfirmation(for entry: PaperEntry) {
        let alert = NSAlert()
        alert.messageText = "Delete \"\(entry.title.isEmpty ? "Untitled Paper" : entry.title)\"?"
        alert.informativeText = "You can undo this with ⌘Z."
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "Delete")
        deleteButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.deletePaperEntry(entry)
    }

    private var header: some View {
        HStack {
            Text("Paper Tracker")
                .font(theme.displayFont(20))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text("\(store.paperEntries.count)")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)
            Button(action: addEntry) {
                Image(systemName: "plus.square.fill")
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
            .help("Add a paper")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12))
                TextField("Search author, title, journal, genes, tags…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(13))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cardBackground.opacity(0.6)))

            Menu {
                Button("All Statuses") { readStatusFilter = nil }
                Divider()
                ForEach(PaperReadStatus.allCases) { status in
                    Button(status.rawValue) { readStatusFilter = status }
                }
            } label: {
                Label(readStatusFilter?.rawValue ?? "All Statuses", systemImage: "line.3.horizontal.decrease.circle")
                    .font(theme.bodyFont(12))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Toggle("Follow-up", isOn: $followUpOnly)
                .toggleStyle(.button)
                .font(theme.bodyFont(12))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    /// SwiftUI's TableColumnBuilder tops out at 10 columns per Table, so a couple of
    /// related fields (First/Last author, Relevance/Follow-up) are paired into one
    /// column each — still independently editable, just stacked vertically.
    private var table: some View {
        Table(filteredEntries, selection: $selection) {
            TableColumn("Added") { entry in
                DatePicker("", selection: dateBinding(for: entry, \.dateAdded), displayedComponents: .date)
                    .labelsHidden()
                    .font(theme.bodyFont(11))
            }
            .width(min: 100, ideal: 105)

            TableColumn("Authors") { entry in
                VStack(alignment: .leading, spacing: 2) {
                    TextField("First author", text: stringBinding(for: entry, \.firstAuthor))
                        .textFieldStyle(.plain)
                        .font(theme.bodyFont(12))
                    TextField("Last author", text: stringBinding(for: entry, \.lastAuthor))
                        .textFieldStyle(.plain)
                        .font(theme.bodyFont(11))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .width(min: 120, ideal: 150)

            TableColumn("Journal") { entry in
                TextField("", text: stringBinding(for: entry, \.journal))
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12))
            }
            .width(min: 100, ideal: 130)

            TableColumn("Year") { entry in
                TextField("", text: stringBinding(for: entry, \.year))
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12))
            }
            .width(min: 44, ideal: 52)

            TableColumn("Title") { entry in
                TextField("", text: stringBinding(for: entry, \.title))
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12, weight: .medium))
            }
            .width(min: 200, ideal: 260)

            TableColumn("Relevance / Follow-up") { entry in
                HStack(spacing: 6) {
                    Picker("", selection: relevanceBinding(for: entry)) {
                        Text("—").tag(PaperRelevance?.none)
                        ForEach(PaperRelevance.allCases) { level in
                            Text(level.rawValue).tag(PaperRelevance?.some(level))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(theme.bodyFont(11))

                    Toggle("Follow-up", isOn: followUpBinding(for: entry))
                        .toggleStyle(.checkbox)
                        .font(theme.bodyFont(10))
                }
            }
            .width(min: 130, ideal: 150)

            TableColumn("Read Status") { entry in
                Picker("", selection: readStatusBinding(for: entry)) {
                    ForEach(PaperReadStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(theme.bodyFont(11))
            }
            .width(min: 96, ideal: 106)

            TableColumn("Tags") { entry in
                TextField("", text: tagsBinding(for: entry))
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12))
            }
            .width(min: 110, ideal: 140)

            TableColumn("Actions") { entry in
                HStack(spacing: 10) {
                    Button {
                        openLink(for: entry)
                    } label: {
                        Image(systemName: "link")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(entry.link.isEmpty ? theme.textTertiary : theme.accentDeep)
                    .disabled(entry.link.isEmpty)
                    .help(entry.link.isEmpty ? "No link saved" : entry.link)

                    Button {
                        detailTarget = DetailTarget(id: entry.id)
                    } label: {
                        Image(systemName: "text.justify")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .help("Methods, summary, notes…")

                    Button {
                        presentDeleteConfirmation(for: entry)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
                    .help("Delete row")
                }
            }
            .width(min: 76, ideal: 76)
        }
        .font(theme.bodyFont(12))
        .contextMenu(forSelectionType: PaperEntry.ID.self) { selectedIDs in
            if let id = selectedIDs.first, let entry = store.paperEntries.first(where: { $0.id == id }) {
                Button(role: .destructive) {
                    presentDeleteConfirmation(for: entry)
                } label: {
                    Label("Delete Row…", systemImage: "trash")
                }
            }
        }
        .onDeleteCommand {
            guard let id = selection, let entry = store.paperEntries.first(where: { $0.id == id }) else { return }
            presentDeleteConfirmation(for: entry)
        }
    }

    private func addEntry() {
        let entry = store.createPaperEntry()
        detailTarget = DetailTarget(id: entry.id)
    }

    private func openLink(for entry: PaperEntry) {
        guard !entry.link.isEmpty else { return }
        var raw = entry.link.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
            raw = "https://" + raw
        }
        guard let url = URL(string: raw) else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Bindings (looked up by id so edits always target the current store state)

    private func stringBinding(for entry: PaperEntry, _ keyPath: WritableKeyPath<PaperEntry, String>) -> Binding<String> {
        Binding(
            get: { store.paperEntries.first(where: { $0.id == entry.id })?[keyPath: keyPath] ?? "" },
            set: { newValue in
                guard let idx = store.paperEntries.firstIndex(where: { $0.id == entry.id }) else { return }
                store.paperEntries[idx][keyPath: keyPath] = newValue
                store.save()
            }
        )
    }

    private func dateBinding(for entry: PaperEntry, _ keyPath: WritableKeyPath<PaperEntry, Date>) -> Binding<Date> {
        Binding(
            get: { store.paperEntries.first(where: { $0.id == entry.id })?[keyPath: keyPath] ?? Date() },
            set: { newValue in
                guard let idx = store.paperEntries.firstIndex(where: { $0.id == entry.id }) else { return }
                store.paperEntries[idx][keyPath: keyPath] = newValue
                store.save()
            }
        )
    }

    private func relevanceBinding(for entry: PaperEntry) -> Binding<PaperRelevance?> {
        Binding(
            get: { store.paperEntries.first(where: { $0.id == entry.id })?.relevance },
            set: { newValue in
                guard let idx = store.paperEntries.firstIndex(where: { $0.id == entry.id }) else { return }
                store.paperEntries[idx].relevance = newValue
                store.save()
            }
        )
    }

    private func readStatusBinding(for entry: PaperEntry) -> Binding<PaperReadStatus> {
        Binding(
            get: { store.paperEntries.first(where: { $0.id == entry.id })?.readStatus ?? .notRead },
            set: { newValue in
                guard let idx = store.paperEntries.firstIndex(where: { $0.id == entry.id }) else { return }
                store.paperEntries[idx].readStatus = newValue
                store.save()
            }
        )
    }

    private func followUpBinding(for entry: PaperEntry) -> Binding<Bool> {
        Binding(
            get: { store.paperEntries.first(where: { $0.id == entry.id })?.followUpNeeded ?? false },
            set: { newValue in
                guard let idx = store.paperEntries.firstIndex(where: { $0.id == entry.id }) else { return }
                store.paperEntries[idx].followUpNeeded = newValue
                store.save()
            }
        )
    }

    private func tagsBinding(for entry: PaperEntry) -> Binding<String> {
        Binding(
            get: { store.paperEntries.first(where: { $0.id == entry.id })?.tags.joined(separator: ", ") ?? "" },
            set: { newValue in
                guard let idx = store.paperEntries.firstIndex(where: { $0.id == entry.id }) else { return }
                let parsed = newValue
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                store.paperEntries[idx].tags = parsed
                store.save()
            }
        )
    }
}

/// Per-row drawer for the long free-text fields that don't work well as always-visible
/// spreadsheet columns, plus the fields (Date Published, Link/DOI, Project Notes) that
/// are useful to edit with room to breathe. Reads/writes the store live by id, so it
/// stays correct even if the row is edited from the table underneath at the same time.
private struct PaperDetailSheet: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    let entryID: UUID
    @State private var newTag: String = ""

    private var entry: PaperEntry {
        store.paperEntries.first(where: { $0.id == entryID }) ?? PaperEntry(id: entryID)
    }

    private var entryBinding: Binding<PaperEntry> {
        Binding(
            get: { entry },
            set: { store.updatePaperEntry($0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(entry.title.isEmpty ? "Untitled Paper" : entry.title)
                    .font(theme.displayFont(16))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(2)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider().overlay(theme.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Identification") {
                        labeledField("Date Published", text: entryBinding.datePublished, placeholder: "e.g. May, 2026")
                        labeledField("Link / DOI", text: entryBinding.link, placeholder: "https://…")
                    }

                    section("Methods & Data") {
                        labeledArea("Methods", text: entryBinding.methods)
                        labeledField("Cell Lines / Animal Models", text: entryBinding.modelsUsed)
                        labeledField("Clinical Samples", text: entryBinding.clinicalSamples)
                        labeledField("Model Organism", text: entryBinding.modelOrganism)
                        labeledField("Sample Size (n)", text: entryBinding.sampleSize)
                        labeledField("Data Availability", text: entryBinding.dataAvailability)
                        labeledField("Software / Tools", text: entryBinding.softwareTools)
                    }

                    section("Science") {
                        labeledField("Cancer Type", text: entryBinding.cancerType)
                        labeledField("Key Genes / Targets", text: entryBinding.keyGenesTargets)
                        labeledArea("Novel Finding", text: entryBinding.novelFinding)
                        labeledArea("Summary", text: entryBinding.summary)
                        labeledField("Figures of Interest", text: entryBinding.figuresOfInterest)
                    }

                    section("Project Relevance") {
                        labeledArea("Project Notes", text: entryBinding.projectNotes)
                        HStack {
                            Text("Tags")
                                .font(theme.bodyFont(11, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 130, alignment: .leading)
                            TagRow(
                                tags: entryBinding.tags,
                                newTag: $newTag,
                                onCommit: { store.updatePaperEntry(entry) }
                            )
                        }
                    }

                    section("Citation") {
                        HStack(alignment: .top) {
                            Text("IEEE Citation")
                                .font(theme.bodyFont(11, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 130, alignment: .leading)
                            Text(entry.ieeeCitation.isEmpty ? "Fill in First Author to generate a citation." : entry.ieeeCitation)
                                .font(theme.bodyFont(12))
                                .foregroundStyle(theme.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 560)
        .background(theme.background)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(theme.bodyFont(10, weight: .bold))
                .foregroundStyle(theme.textTertiary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
    }

    private func labeledField(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        HStack {
            Text(label)
                .font(theme.bodyFont(11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 130, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(theme.bodyFont(12))
        }
    }

    private func labeledArea(_ label: String, text: Binding<String>) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(theme.bodyFont(11, weight: .medium))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 130, alignment: .leading)
            TextEditor(text: text)
                .font(theme.bodyFont(12))
                .frame(height: 60)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.cardBackground.opacity(0.6)))
        }
    }
}

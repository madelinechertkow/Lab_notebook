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
    @Binding var selectedEntryID: PaperEntry.ID?

    @State private var searchText: String = ""
    @State private var readStatusFilter: PaperReadStatus?
    @State private var followUpOnly: Bool = false

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
        Table(filteredEntries, selection: $selectedEntryID) {
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
                        openLink(entry.link)
                    } label: {
                        Image(systemName: "link")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(entry.link.isEmpty ? theme.textTertiary : theme.accentDeep)
                    .disabled(entry.link.isEmpty)
                    .help(entry.link.isEmpty ? "No link saved" : entry.link)

                    Button {
                        selectedEntryID = entry.id
                    } label: {
                        Image(systemName: "text.justify")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .help("View full summary")

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
            guard let id = selectedEntryID, let entry = store.paperEntries.first(where: { $0.id == id }) else { return }
            presentDeleteConfirmation(for: entry)
        }
    }

    private func addEntry() {
        let entry = store.createPaperEntry()
        selectedEntryID = entry.id
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

/// Right-panel summary for a paper — shown in the detail column whenever a row is selected
/// or added, covering every field from the original Paper_Tracker.xlsx (identification
/// through citation) in one place instead of only the handful exposed as table columns.
/// Reads/writes the store live by id, so it stays correct even if the row is edited from
/// the table underneath at the same time.
struct PaperDetailPanel: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let entryID: UUID
    @State private var newTag: String = ""
    @State private var isFetchingMetadata = false
    @State private var fetchErrorMessage: String?

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
            header
            Divider().overlay(theme.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Identification") {
                        labeledField("Date Published", text: entryBinding.datePublished, placeholder: "e.g. May, 2026")
                        linkFieldWithFetch
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
                            Text("Nature Citation")
                                .font(theme.bodyFont(11, weight: .medium))
                                .foregroundStyle(theme.textSecondary)
                                .frame(width: 130, alignment: .leading)
                            Text(entry.natureCitation.isEmpty ? "Fill in First Author to generate a citation." : entry.natureCitation)
                                .font(theme.bodyFont(12))
                                .foregroundStyle(theme.textPrimary)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.editorBackground)
    }

    /// Title, authors, journal, and year up top — the fields the original detail sheet left
    /// out entirely, forcing you back to the (narrow) table columns to see or set them.
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Untitled Paper", text: entryBinding.title)
                .textFieldStyle(.plain)
                .font(theme.displayFont(18))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(2)

            HStack(spacing: 6) {
                TextField("First author", text: entryBinding.firstAuthor)
                    .textFieldStyle(.plain)
                Text("&")
                    .foregroundStyle(theme.textTertiary)
                TextField("Last author", text: entryBinding.lastAuthor)
                    .textFieldStyle(.plain)
            }
            .font(theme.bodyFont(13))
            .foregroundStyle(theme.textSecondary)

            HStack(spacing: 8) {
                TextField("Journal", text: entryBinding.journal)
                    .textFieldStyle(.plain)
                    .italic()
                Text("·").foregroundStyle(theme.textTertiary)
                TextField("Year", text: entryBinding.year)
                    .textFieldStyle(.plain)
                    .frame(width: 46)
                if !entry.link.isEmpty {
                    Spacer()
                    Button {
                        openLink(entry.link)
                    } label: {
                        Image(systemName: "link")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accentDeep)
                    .help(entry.link)
                }
            }
            .font(theme.bodyFont(12, weight: .medium))
            .foregroundStyle(theme.textSecondary)

            HStack(spacing: 12) {
                Picker("", selection: entryBinding.readStatus) {
                    ForEach(PaperReadStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

                Picker("", selection: entryBinding.relevance) {
                    Text("Relevance —").tag(PaperRelevance?.none)
                    ForEach(PaperRelevance.allCases) { level in
                        Text(level.rawValue).tag(PaperRelevance?.some(level))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()

                Toggle("Follow-up", isOn: entryBinding.followUpNeeded)
                    .toggleStyle(.checkbox)
            }
            .font(theme.bodyFont(11))
        }
        .padding(16)
    }

    private var linkFieldWithFetch: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Link / DOI")
                    .font(theme.bodyFont(11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 130, alignment: .leading)
                TextField("https://doi.org/…", text: entryBinding.link)
                    .textFieldStyle(.roundedBorder)
                    .font(theme.bodyFont(12))
                Button(action: fetchMetadata) {
                    if isFetchingMetadata {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Fetch", systemImage: "arrow.down.doc")
                    }
                }
                .disabled(entry.link.trimmingCharacters(in: .whitespaces).isEmpty || isFetchingMetadata)
                .help("Fill in title, authors, journal, and year from this link")
            }
            if let fetchErrorMessage {
                Text(fetchErrorMessage)
                    .font(theme.bodyFont(10))
                    .foregroundStyle(.red)
                    .padding(.leading, 138)
            }
        }
    }

    private func fetchMetadata() {
        let link = entry.link
        let targetID = entryID
        isFetchingMetadata = true
        fetchErrorMessage = nil
        Task {
            do {
                let metadata = try await PaperMetadataFetcher.fetchMetadata(fromLink: link)
                guard var updated = store.paperEntries.first(where: { $0.id == targetID }) else { return }
                if let title = metadata.title { updated.title = title }
                if let journal = metadata.journal { updated.journal = journal }
                if let year = metadata.year { updated.year = year }
                if let datePublished = metadata.datePublished { updated.datePublished = datePublished }
                if let firstAuthor = metadata.firstAuthor { updated.firstAuthor = firstAuthor }
                if let lastAuthor = metadata.lastAuthor { updated.lastAuthor = lastAuthor }
                store.updatePaperEntry(updated)
                isFetchingMetadata = false
            } catch {
                fetchErrorMessage = (error as? PaperMetadataError)?.errorDescription ?? "Couldn't fetch details from that link."
                isFetchingMetadata = false
            }
        }
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

/// Shared by the table's link button and the detail panel's header link button.
private func openLink(_ rawLink: String) {
    guard !rawLink.isEmpty else { return }
    var raw = rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
    if !raw.lowercased().hasPrefix("http://") && !raw.lowercased().hasPrefix("https://") {
        raw = "https://" + raw
    }
    guard let url = URL(string: raw) else { return }
    NSWorkspace.shared.open(url)
}

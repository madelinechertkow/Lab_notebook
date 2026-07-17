import Foundation
import Combine

final class NoteStore: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var notes: [Note] = []
    @Published var todos: [TodoItem] = []
    @Published var protocols: [LabProtocol] = []
    @Published var scheduledExperiments: [ScheduledExperiment] = []
    @Published var plateMapTemplates: [PlateMapTemplate] = []
    @Published var gelLadderPresets: [GelLadderPreset] = []
    @Published var codeEnvironments: [CodeEnvironment] = []
    @Published var labModeFilter: LabModeFilter = .all
    /// App-level preference: automatically mirror scheduled experiments to Apple Calendar.
    @Published var syncToAppleCalendar: Bool = false

    // Cross-window signals (not persisted): windows can't talk to each other directly,
    // so requests are parked on the shared store for the target window to pick up and clear.
    /// Set by the calendar window to ask the main window to open a specific note.
    @Published var pendingOpenNoteID: UUID?
    /// Set by the protocol editor to ask the calendar window to open a prefilled "new experiment" sheet.
    @Published var pendingScheduleProtocolID: UUID?

    /// Bumped whenever undo/redo replaces the published state wholesale. Editor views that
    /// hold local @State copies (note editor, protocol editor) watch this to reload.
    @Published private(set) var undoTick = 0

    private let fileURL: URL

    // Whole-state snapshots make undo trivially correct for every mutation because all
    // writes funnel through save(). Rapid-fire saves (typing persists per keystroke) are
    // coalesced so one undo steps back a whole burst, not one character.
    private var undoStack: [SavedData] = []
    private var redoStack: [SavedData] = []
    private var lastSavedState: SavedData?
    private var lastUndoPushAt: Date?
    private static let undoCoalescingInterval: TimeInterval = 2.0
    private static let undoStackLimit = 100

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Cazzy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("data.json")
        if let raw = UserDefaults.standard.string(forKey: "labModeFilter"), let mode = LabModeFilter(rawValue: raw) {
            self.labModeFilter = mode
        }
        self.syncToAppleCalendar = UserDefaults.standard.bool(forKey: "syncToAppleCalendar")
        load()
    }

    func setLabModeFilter(_ mode: LabModeFilter) {
        labModeFilter = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "labModeFilter")
    }

    func setSyncToAppleCalendar(_ enabled: Bool) {
        syncToAppleCalendar = enabled
        UserDefaults.standard.set(enabled, forKey: "syncToAppleCalendar")
    }

    func visibleNotebooks() -> [Notebook] {
        notebooks.filter { labModeFilter.matches($0.labMode) }
    }

    private struct SavedData: Codable, Equatable {
        var notebooks: [Notebook]
        var notes: [Note]
        var todos: [TodoItem]
        var protocols: [LabProtocol]
        var scheduledExperiments: [ScheduledExperiment]
        var plateMapTemplates: [PlateMapTemplate]
        var gelLadderPresets: [GelLadderPreset]
        var codeEnvironments: [CodeEnvironment]

        enum CodingKeys: String, CodingKey {
            case notebooks, notes, todos, protocols, scheduledExperiments, plateMapTemplates, gelLadderPresets, codeEnvironments
        }

        init(notebooks: [Notebook], notes: [Note], todos: [TodoItem], protocols: [LabProtocol], scheduledExperiments: [ScheduledExperiment], plateMapTemplates: [PlateMapTemplate], gelLadderPresets: [GelLadderPreset], codeEnvironments: [CodeEnvironment]) {
            self.notebooks = notebooks
            self.notes = notes
            self.todos = todos
            self.protocols = protocols
            self.scheduledExperiments = scheduledExperiments
            self.plateMapTemplates = plateMapTemplates
            self.gelLadderPresets = gelLadderPresets
            self.codeEnvironments = codeEnvironments
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            notebooks = try container.decode([Notebook].self, forKey: .notebooks)
            notes = try container.decode([Note].self, forKey: .notes)
            todos = try container.decodeIfPresent([TodoItem].self, forKey: .todos) ?? []
            protocols = try container.decodeIfPresent([LabProtocol].self, forKey: .protocols) ?? []
            scheduledExperiments = try container.decodeIfPresent([ScheduledExperiment].self, forKey: .scheduledExperiments) ?? []
            plateMapTemplates = try container.decodeIfPresent([PlateMapTemplate].self, forKey: .plateMapTemplates) ?? []
            gelLadderPresets = try container.decodeIfPresent([GelLadderPreset].self, forKey: .gelLadderPresets) ?? []
            codeEnvironments = try container.decodeIfPresent([CodeEnvironment].self, forKey: .codeEnvironments) ?? []
        }
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(SavedData.self, from: data) else {
            seedDefaults()
            return
        }
        self.notebooks = decoded.notebooks
        self.notes = decoded.notes
        self.todos = decoded.todos
        self.protocols = decoded.protocols
        self.scheduledExperiments = decoded.scheduledExperiments
        self.plateMapTemplates = decoded.plateMapTemplates
        self.gelLadderPresets = decoded.gelLadderPresets
        self.codeEnvironments = decoded.codeEnvironments
        self.lastSavedState = decoded
    }

    func save() {
        let current = currentState()
        recordUndoSnapshot(before: current)
        persist(current)
    }

    private func currentState() -> SavedData {
        SavedData(notebooks: notebooks, notes: notes, todos: todos, protocols: protocols, scheduledExperiments: scheduledExperiments, plateMapTemplates: plateMapTemplates, gelLadderPresets: gelLadderPresets, codeEnvironments: codeEnvironments)
    }

    private func persist(_ state: SavedData) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
        lastSavedState = state
    }

    // MARK: - Undo / Redo (⌘Z / ⇧⌘Z, app-wide)

    private func recordUndoSnapshot(before current: SavedData) {
        guard let previous = lastSavedState, previous != current else { return }
        redoStack.removeAll()
        let now = Date()
        // Within the coalescing window, the stack keeps the burst's starting state.
        if let lastPush = lastUndoPushAt, now.timeIntervalSince(lastPush) < Self.undoCoalescingInterval { return }
        undoStack.append(previous)
        if undoStack.count > Self.undoStackLimit {
            undoStack.removeFirst()
        }
        lastUndoPushAt = now
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(currentState())
        applyRestoredState(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(currentState())
        applyRestoredState(next)
    }

    private func applyRestoredState(_ state: SavedData) {
        notebooks = state.notebooks
        notes = state.notes
        todos = state.todos
        protocols = state.protocols
        scheduledExperiments = state.scheduledExperiments
        plateMapTemplates = state.plateMapTemplates
        gelLadderPresets = state.gelLadderPresets
        codeEnvironments = state.codeEnvironments
        // Break the coalescing window so the next edit gets its own undo step.
        lastUndoPushAt = nil
        persist(state)
        undoTick += 1
    }

    func notes(in notebookID: UUID?) -> [Note] {
        let filtered: [Note]
        if let notebookID {
            filtered = notes.filter { $0.notebookID == notebookID }
        } else {
            let visibleIDs = Set(visibleNotebooks().map { $0.id })
            filtered = notes.filter { visibleIDs.contains($0.notebookID) }
        }
        return filtered.sorted { $0.updatedAt > $1.updatedAt }
    }

    func search(_ query: String, in notebookID: UUID?) -> [Note] {
        let base = notes(in: notebookID)
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return base }
        let q = query.lowercased()
        return base.filter {
            $0.title.lowercased().contains(q)
                || $0.content.lowercased().contains(q)
                || $0.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    @discardableResult
    func createNote(in notebookID: UUID, title: String = "Untitled", content: String = "") -> Note {
        let note = Note(notebookID: notebookID, title: title, content: content)
        notes.append(note)
        save()
        return note
    }

    func updateNote(_ note: Note) {
        guard let idx = notes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = Date()
        notes[idx] = updated
        save()
    }

    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    func addTodo(_ text: String, weekday: Weekday = .today) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.append(TodoItem(text: trimmed, weekday: weekday))
        save()
    }

    func toggleTodo(_ item: TodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].isDone.toggle()
        save()
    }

    func deleteTodo(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
        save()
    }

    func setTodoWeekday(_ item: TodoItem, weekday: Weekday) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].weekday = weekday
        save()
    }

    func todos(for weekday: Weekday) -> [TodoItem] {
        todos.filter { $0.weekday == weekday }
    }

    func clearCompletedTodos(weekday: Weekday? = nil) {
        if let weekday {
            todos.removeAll { $0.isDone && $0.weekday == weekday }
        } else {
            todos.removeAll { $0.isDone }
        }
        save()
    }

    func allTags() -> [String] {
        let visibleIDs = Set(visibleNotebooks().map { $0.id })
        return Array(Set(notes.filter { visibleIDs.contains($0.notebookID) }.flatMap { $0.tags })).sorted()
    }

    private func seedDefaults() {
        let defaultNotebooks = Notebook.defaults()
        notebooks = defaultNotebooks

        func id(_ name: String) -> UUID {
            defaultNotebooks.first(where: { $0.name == name })!.id
        }

        notes = [
            Note(
                notebookID: id("Lab Notebook"),
                title: "Entry template — [date] [session/experiment name]",
                content: """
                # [Date] — [Session or experiment title]

                **Objective:** What question is today's work trying to answer?

                ## Setup / Methods
                - Materials, instruments, or samples used
                - Parameters or conditions tested
                - Any deviations from the standard protocol

                ## Observations / Results
                - What happened? Include raw numbers, readings, or where the data/figures are saved
                - Anything unexpected

                ## Next steps
                - [ ] Follow-up experiment or analysis
                - [ ] Something to double-check
                - [ ] Data to back up or file away
                """,
                tags: ["template"]
            ),
            Note(
                notebookID: id("Protocols"),
                title: "Protocol template",
                content: """
                # [Protocol name] — v1

                **Purpose:** What this procedure accomplishes and when to use it.

                ## Materials / Equipment
                - Item 1
                - Item 2
                - Item 3

                ## Steps
                - [ ] Step 1
                - [ ] Step 2
                - [ ] Step 3
                - [ ] Step 4

                ## Notes
                `Expected outcome or key parameter to watch`
                """,
                tags: ["protocol"]
            ),
            Note(
                notebookID: id("Analysis Notebook"),
                title: "Entry template — [date] [analysis or run name]",
                content: """
                # [Date] — [Analysis or run name]

                **Objective:** What question is this analysis trying to answer?

                ## Inputs
                - Dataset(s) or source files used
                - Parameters or config for this run

                ## Method
                - Script, notebook, or pipeline used
                - Key steps or transformations applied

                ## Results
                - Summary of output, key numbers, or where plots/figures are saved
                - Anything unexpected

                ## Next steps
                - [ ] Follow-up analysis
                - [ ] Something to re-run with different parameters
                - [ ] Results to write up
                """,
                tags: ["template"]
            ),
            Note(
                notebookID: id("Scripts & Workflows"),
                title: "Script / workflow template",
                content: """
                # [Script or workflow name]

                **Purpose:** What this script/workflow does and when to use it.

                ## Usage
                `command or entry point here`

                ## Inputs
                - Required files, arguments, or environment variables

                ## Outputs
                - What it produces and where

                ## Dependencies
                - Environment, packages, or versions needed

                ## Notes
                - Known issues, edge cases, or things to remember
                """,
                tags: ["workflow"]
            ),
            Note(
                notebookID: id("Literature Notes"),
                title: "Paper summary template",
                content: """
                # [Author et al., Year] — *[Journal]*

                **Title:** Paper title here

                ## Key points
                - Main claim or finding
                - Method or approach used
                - How they validated it

                ## My take
                - Strengths and weaknesses of the approach
                - How this connects to my own work

                ## Questions for group
                - [ ] Something worth raising in journal club or lab meeting
                """,
                tags: ["journal-club"]
            ),
            Note(
                notebookID: id("Meeting Notes"),
                title: "Meeting template",
                content: """
                # [Meeting type] — [date]

                **Attendees:**

                ## Updates
                - What's been done since last time
                - What's currently in progress

                ## Action items
                - [ ] Task 1
                - [ ] Task 2
                - [ ] Task 3
                """,
                tags: ["meeting"]
            ),
            Note(
                notebookID: id("Ideas & Hypotheses"),
                title: "Hypothesis template",
                content: """
                # Hypothesis

                State the idea in one sentence — what do you think is true, and why?

                ## Reasoning
                - What existing evidence or observation motivates this?

                ## Possible test
                - How could this be tested or falsified?

                ## Why it matters
                - What would change if this turned out to be true?
                """,
                tags: ["hypothesis"]
            ),
            Note(
                notebookID: id("Thesis & Writing"),
                title: "Chapter / section outline",
                content: """
                # [Chapter or paper title]

                ## Sections
                1. Background / motivation
                2. Methods
                3. Results
                4. Discussion
                5. Conclusion

                *Draft target: [date]*
                """,
                tags: ["writing"]
            ),
        ]
        save()
    }
}

import Foundation
import Combine

final class NoteStore: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var notes: [Note] = []
    @Published var labModeFilter: LabModeFilter = .all

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Zycas", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("data.json")
        if let raw = UserDefaults.standard.string(forKey: "labModeFilter"), let mode = LabModeFilter(rawValue: raw) {
            self.labModeFilter = mode
        }
        load()
    }

    func setLabModeFilter(_ mode: LabModeFilter) {
        labModeFilter = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "labModeFilter")
    }

    func visibleNotebooks() -> [Notebook] {
        notebooks.filter { labModeFilter.matches($0.labMode) }
    }

    private struct SavedData: Codable {
        var notebooks: [Notebook]
        var notes: [Note]
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(SavedData.self, from: data) else {
            seedDefaults()
            return
        }
        self.notebooks = decoded.notebooks
        self.notes = decoded.notes
    }

    func save() {
        let payload = SavedData(notebooks: notebooks, notes: notes)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
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

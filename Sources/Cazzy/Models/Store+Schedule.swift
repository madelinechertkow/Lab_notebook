import Foundation

extension NoteStore {
    // MARK: - CRUD

    /// Schedules an experiment, materializing recurrence into individual occurrences that
    /// share a `seriesID`. Returns everything that was created (first element is the original).
    @discardableResult
    func scheduleExperiment(_ experiment: ScheduledExperiment, recurrence: ExperimentRecurrence = .none, until endDate: Date? = nil) -> [ScheduledExperiment] {
        var created: [ScheduledExperiment] = []

        if let stepDays = recurrence.stepDays, let endDate {
            let seriesID = UUID()
            var occurrence = experiment
            occurrence.seriesID = seriesID
            var start = experiment.start
            let calendar = Calendar.current
            while start <= calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate {
                occurrence.id = created.isEmpty ? experiment.id : UUID()
                occurrence.start = start
                created.append(occurrence)
                guard let next = calendar.date(byAdding: .day, value: stepDays, to: start) else { break }
                start = next
            }
        } else {
            created = [experiment]
        }

        scheduledExperiments.append(contentsOf: created)
        save()
        return created
    }

    func updateScheduledExperiment(_ experiment: ScheduledExperiment) {
        guard let idx = scheduledExperiments.firstIndex(where: { $0.id == experiment.id }) else { return }
        scheduledExperiments[idx] = experiment
        save()
    }

    /// Deletes one occurrence, or the whole repeating series it belongs to.
    /// Returns the removed experiments so pushed Apple Calendar events can be cleaned up.
    @discardableResult
    func deleteScheduledExperiment(_ experiment: ScheduledExperiment, wholeSeries: Bool = false) -> [ScheduledExperiment] {
        let removed: [ScheduledExperiment]
        if wholeSeries, let seriesID = experiment.seriesID {
            removed = scheduledExperiments.filter { $0.seriesID == seriesID }
            scheduledExperiments.removeAll { $0.seriesID == seriesID }
        } else {
            removed = scheduledExperiments.filter { $0.id == experiment.id }
            scheduledExperiments.removeAll { $0.id == experiment.id }
        }
        save()
        return removed
    }

    // MARK: - Queries

    func experiments(on day: Date) -> [ScheduledExperiment] {
        let calendar = Calendar.current
        return scheduledExperiments
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    func experiments(in interval: DateInterval) -> [ScheduledExperiment] {
        scheduledExperiments
            .filter { $0.interval.intersects(interval) }
            .sorted { $0.start < $1.start }
    }

    /// Notes created on a given day, for jumping from the calendar into that day's notebook entries.
    func notes(createdOn day: Date) -> [Note] {
        let calendar = Calendar.current
        return notes
            .filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Running behind

    /// Shifts an experiment and every later experiment on the same day by the same offset,
    /// for when an earlier step runs long. Returns the experiments that moved (post-shift)
    /// so the caller can update any pushed Apple Calendar events.
    @discardableResult
    func shiftDay(startingAt experiment: ScheduledExperiment, by minutes: Int) -> [ScheduledExperiment] {
        guard minutes != 0 else { return [] }
        let calendar = Calendar.current
        var shifted: [ScheduledExperiment] = []
        for idx in scheduledExperiments.indices {
            let item = scheduledExperiments[idx]
            guard calendar.isDate(item.start, inSameDayAs: experiment.start), item.start >= experiment.start else { continue }
            scheduledExperiments[idx].start = item.start.addingTimeInterval(TimeInterval(minutes * 60))
            shifted.append(scheduledExperiments[idx])
        }
        save()
        return shifted.sorted { $0.start < $1.start }
    }

    // MARK: - Notebook entry linkage

    /// Creates a pre-filled Lab Notebook entry for an experiment and links it back via
    /// `linkedNoteID`. Falls back to the first visible notebook if "Lab Notebook" was renamed.
    @discardableResult
    func createNote(from experiment: ScheduledExperiment) -> Note? {
        guard let notebook = notebooks.first(where: { $0.name == "Lab Notebook" }) ?? notebooks.first else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let linkedProtocol = experiment.protocolID.flatMap { id in protocols.first(where: { $0.id == id }) }

        var content = "# \(dateFormatter.string(from: experiment.start)) — \(experiment.title)\n\n"
        content += "**Scheduled:** \(timeFormatter.string(from: experiment.start))–\(timeFormatter.string(from: experiment.end))\n\n"
        if let linkedProtocol {
            content += "**Protocol:** \(linkedProtocol.name)"
            if linkedProtocol.currentVersionNumber > 0 {
                content += " (v\(linkedProtocol.currentVersionNumber))"
            }
            content += "\n\n"
            if !linkedProtocol.purpose.isEmpty {
                content += "**Purpose:** \(linkedProtocol.purpose)\n\n"
            }
            let numberedSteps = linkedProtocol.steps.filter { $0.kind == .step }
            if !numberedSteps.isEmpty {
                content += "## Steps\n"
                for step in numberedSteps {
                    content += "- [ ] \(step.text)\n"
                }
                content += "\n"
            }
        }
        if !experiment.notes.isEmpty {
            content += "## Planning notes\n\(experiment.notes)\n\n"
        }
        content += "## Observations / Results\n- \n\n## Next steps\n- [ ] \n"

        let note = createNote(in: notebook.id, title: experiment.title, content: content)

        if let idx = scheduledExperiments.firstIndex(where: { $0.id == experiment.id }) {
            scheduledExperiments[idx].linkedNoteID = note.id
            save()
        }
        return note
    }
}

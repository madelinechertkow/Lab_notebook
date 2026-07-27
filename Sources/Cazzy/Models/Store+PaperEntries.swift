import Foundation

extension NoteStore {
    @discardableResult
    func createPaperEntry() -> PaperEntry {
        let entry = PaperEntry()
        paperEntries.append(entry)
        save()
        return entry
    }

    func updatePaperEntry(_ entry: PaperEntry) {
        guard let idx = paperEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.updatedAt = Date()
        paperEntries[idx] = updated
        save()
    }

    func deletePaperEntry(_ entry: PaperEntry) {
        paperEntries.removeAll { $0.id == entry.id }
        save()
    }

    func allPaperTags() -> [String] {
        Array(Set(paperEntries.flatMap { $0.tags })).sorted()
    }
}

import Foundation

extension NoteStore {
    @discardableResult
    func createLadderPreset(name: String = "Untitled Ladder") -> GelLadderPreset {
        let preset = GelLadderPreset(name: name)
        gelLadderPresets.append(preset)
        save()
        return preset
    }

    func updateLadderPreset(_ preset: GelLadderPreset) {
        guard let idx = gelLadderPresets.firstIndex(where: { $0.id == preset.id }) else { return }
        var updated = preset
        updated.updatedAt = Date()
        gelLadderPresets[idx] = updated
        save()
    }

    func deleteLadderPreset(_ preset: GelLadderPreset) {
        gelLadderPresets.removeAll { $0.id == preset.id }
        save()
    }
}

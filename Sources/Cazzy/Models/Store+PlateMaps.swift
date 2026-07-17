import Foundation

extension NoteStore {
    @discardableResult
    func createPlateMapTemplate(name: String = "Untitled Plate Map", size: PlateSize = .wells96) -> PlateMapTemplate {
        let template = PlateMapTemplate(name: name, size: size)
        plateMapTemplates.append(template)
        save()
        return template
    }

    func updatePlateMapTemplate(_ template: PlateMapTemplate) {
        guard let idx = plateMapTemplates.firstIndex(where: { $0.id == template.id }) else { return }
        var updated = template
        updated.updatedAt = Date()
        plateMapTemplates[idx] = updated
        save()
    }

    func deletePlateMapTemplate(_ template: PlateMapTemplate) {
        plateMapTemplates.removeAll { $0.id == template.id }
        save()
    }
}

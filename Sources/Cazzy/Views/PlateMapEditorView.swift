import SwiftUI

struct PlateMapEditorView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let plateMapID: UUID

    @State private var name: String = ""
    @State private var wells: [String: WellAnnotation] = [:]

    private var currentTemplate: PlateMapTemplate? {
        store.plateMapTemplates.first(where: { $0.id == plateMapID })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    TextField("Untitled Plate Map", text: $name)
                        .textFieldStyle(.plain)
                        .font(theme.displayFont(24))
                        .foregroundStyle(theme.textPrimary)
                        .onChange(of: name) { _ in persist() }
                    Spacer()
                    if let currentTemplate {
                        Text(currentTemplate.size.label)
                            .font(theme.bodyFont(12, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.top, 8)
                    }
                }

                Text("This is the default layout new notes start from when they insert this template — editing it here won't change any copies already embedded in existing notes.")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)

                if let size = currentTemplate?.size {
                    PlateMapGridView(size: size, wells: $wells)
                        .onChange(of: wells) { _ in persist() }
                }
            }
            .padding(24)
        }
        .scrollContentBackground(.hidden)
        .background(theme.editorBackground)
        .onAppear(perform: loadFromTemplate)
        .onChange(of: plateMapID) { _ in loadFromTemplate() }
        .onChange(of: store.undoTick) { _ in loadFromTemplate() }
    }

    private func loadFromTemplate() {
        guard let currentTemplate else { return }
        name = currentTemplate.name
        wells = currentTemplate.wells
    }

    private func persist() {
        guard var updated = currentTemplate else { return }
        updated.name = name
        updated.wells = wells
        store.updatePlateMapTemplate(updated)
    }
}

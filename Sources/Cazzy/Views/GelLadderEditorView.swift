import SwiftUI

struct GelLadderEditorView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let ladderID: UUID

    @State private var name: String = ""
    @State private var bands: [GelLadderBand] = []
    @State private var newSizeValue: String = ""
    @State private var newUnit: GelSizeUnit = .bp

    private var currentPreset: GelLadderPreset? {
        store.gelLadderPresets.first(where: { $0.id == ladderID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Untitled Ladder", text: $name)
                .textFieldStyle(.plain)
                .font(theme.displayFont(24))
                .foregroundStyle(theme.textPrimary)
                .onChange(of: name) { _ in persist() }

            Text("Bands are ordered largest to smallest, matching how a ladder reads top-to-bottom on a gel. This list is what gets copied in when you insert this ladder into a gel map block.")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: 8) {
                TextField("Size", text: $newSizeValue)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Picker("", selection: $newUnit) {
                    ForEach(GelSizeUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
                Button("Add Band", action: addBand)
                    .disabled(Double(newSizeValue) == nil)
                Spacer()
            }

            List {
                ForEach(bands) { band in
                    HStack {
                        Text(band.sizeLabel)
                            .font(theme.bodyFont(13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                        Button {
                            bands.removeAll { $0.id == band.id }
                            persist()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                }
                .onMove(perform: moveBands)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 200)
        }
        .padding(24)
        .background(theme.editorBackground)
        .onAppear(perform: loadFromPreset)
        .onChange(of: ladderID) { _ in loadFromPreset() }
        .onChange(of: store.undoTick) { _ in loadFromPreset() }
    }

    private func addBand() {
        guard let value = Double(newSizeValue) else { return }
        bands.append(GelLadderBand(sizeValue: value, unit: newUnit))
        newSizeValue = ""
        persist()
    }

    private func moveBands(from source: IndexSet, to destination: Int) {
        bands.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func loadFromPreset() {
        guard let currentPreset else { return }
        name = currentPreset.name
        bands = currentPreset.bands
    }

    private func persist() {
        guard var updated = currentPreset else { return }
        updated.name = name
        updated.bands = bands
        store.updateLadderPreset(updated)
    }
}

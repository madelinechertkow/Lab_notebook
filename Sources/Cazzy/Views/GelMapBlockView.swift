import SwiftUI
import AppKit

/// Renders one ```gelmap block in note preview: the imported photo with draggable lane-name
/// and ladder-size labels on top. Deliberately simple — labels are placed and read, not
/// calibrated; there's no size-estimation math.
struct GelMapBlockView: View {
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var store: NoteStore
    let blockID: String
    let instance: GelMapInstance
    let onChange: (GelMapInstance) -> Void

    @State private var workingInstance: GelMapInstance
    @State private var editingLane: GelLaneLabel?
    @State private var editingBand: GelPositionedLadderBand?
    @State private var showingAdjustSheet = false

    init(blockID: String, instance: GelMapInstance, onChange: @escaping (GelMapInstance) -> Void) {
        self.blockID = blockID
        self.instance = instance
        self.onChange = onChange
        self._workingInstance = State(initialValue: instance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            imageCanvas
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.divider, lineWidth: 1))
        .padding(.vertical, 6)
        .onChange(of: instance) { workingInstance = $0 }
        .sheet(isPresented: $showingAdjustSheet) {
            GelImageAdjustSheet(imageFileName: workingInstance.imageFileName) { newFilename in
                workingInstance.imageFileName = newFilename
                commit()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(theme.accentDeep)
            Text("Gel Map")
                .font(theme.bodyFont(12, weight: .semibold))
            Spacer()
            Button { showingAdjustSheet = true } label: {
                Label("Adjust", systemImage: "crop.rotate")
                    .font(theme.bodyFont(10))
            }
            .buttonStyle(.plain)
            Button { addLane() } label: {
                Label("Lane", systemImage: "plus.rectangle")
                    .font(theme.bodyFont(10))
            }
            .buttonStyle(.plain)

            Menu {
                Button("Custom size label") { addCustomBand() }
                if !store.gelLadderPresets.isEmpty {
                    Divider()
                    ForEach(store.gelLadderPresets) { preset in
                        Button("From \"\(preset.name)\"") { addLadderPreset(preset) }
                    }
                }
            } label: {
                Label("Ladder", systemImage: "plus.square.on.square")
                    .font(theme.bodyFont(10))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .foregroundStyle(theme.textSecondary)
    }

    @ViewBuilder
    private var imageCanvas: some View {
        if let nsImage = GelImageStore.loadImage(workingInstance.imageFileName) {
            let aspect = nsImage.size.height > 0 ? nsImage.size.width / nsImage.size.height : 1
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)

                    ForEach(workingInstance.laneLabels) { lane in
                        laneChip(lane, size: geo.size)
                    }
                    ForEach(workingInstance.ladderBands) { band in
                        bandChip(band, size: geo.size)
                    }
                }
                .coordinateSpace(name: "gelCanvas")
            }
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
        } else {
            Text("Image unavailable")
                .font(theme.bodyFont(12))
                .foregroundStyle(theme.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    // MARK: - Lane labels

    private func laneChip(_ lane: GelLaneLabel, size: CGSize) -> some View {
        Text(lane.text.isEmpty ? "Lane" : lane.text)
            .font(theme.bodyFont(10, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(theme.accent.opacity(0.85)))
            .foregroundStyle(.white)
            .position(x: lane.xPosition * size.width, y: 14)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("gelCanvas"))
                    .onChanged { value in
                        let x = min(max(value.location.x / size.width, 0), 1)
                        setLane(lane.id) { $0.xPosition = x }
                    }
                    .onEnded { _ in commit() }
            )
            .onTapGesture(count: 2) { editingLane = lane }
            .popover(isPresented: Binding(
                get: { editingLane?.id == lane.id },
                set: { if !$0 { editingLane = nil } }
            )) {
                LaneEditorPopover(
                    text: lane.text,
                    onSave: { newText in
                        setLane(lane.id) { $0.text = newText }
                        commit()
                        editingLane = nil
                    },
                    onDelete: {
                        workingInstance.laneLabels.removeAll { $0.id == lane.id }
                        commit()
                        editingLane = nil
                    }
                )
            }
    }

    private func addLane() {
        let x = 0.12 + 0.08 * Double(workingInstance.laneLabels.count % 10)
        workingInstance.laneLabels.append(GelLaneLabel(xPosition: min(x, 0.95), text: "Lane \(workingInstance.laneLabels.count + 1)"))
        commit()
    }

    private func setLane(_ id: UUID, _ mutate: (inout GelLaneLabel) -> Void) {
        guard let idx = workingInstance.laneLabels.firstIndex(where: { $0.id == id }) else { return }
        mutate(&workingInstance.laneLabels[idx])
    }

    // MARK: - Ladder size labels

    private func bandChip(_ band: GelPositionedLadderBand, size: CGSize) -> some View {
        Text(band.sizeLabel)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(theme.secondaryAccent.opacity(0.85)))
            .foregroundStyle(.white)
            .position(x: 30, y: band.yPosition * size.height)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named("gelCanvas"))
                    .onChanged { value in
                        let y = min(max(value.location.y / size.height, 0), 1)
                        setBand(band.id) { $0.yPosition = y }
                    }
                    .onEnded { _ in commit() }
            )
            .onTapGesture(count: 2) { editingBand = band }
            .popover(isPresented: Binding(
                get: { editingBand?.id == band.id },
                set: { if !$0 { editingBand = nil } }
            )) {
                LaneEditorPopover(
                    text: band.sizeLabel,
                    onSave: { newText in
                        setBand(band.id) { $0.sizeLabel = newText }
                        commit()
                        editingBand = nil
                    },
                    onDelete: {
                        workingInstance.ladderBands.removeAll { $0.id == band.id }
                        commit()
                        editingBand = nil
                    }
                )
            }
    }

    private func addCustomBand() {
        workingInstance.ladderBands.append(GelPositionedLadderBand(yPosition: 0.5, sizeLabel: "Label"))
        commit()
    }

    private func addLadderPreset(_ preset: GelLadderPreset) {
        guard !preset.bands.isEmpty else { return }
        let count = preset.bands.count
        for (index, band) in preset.bands.enumerated() {
            let y = count == 1 ? 0.5 : 0.08 + 0.84 * Double(index) / Double(count - 1)
            workingInstance.ladderBands.append(GelPositionedLadderBand(yPosition: y, sizeLabel: band.sizeLabel))
        }
        commit()
    }

    private func setBand(_ id: UUID, _ mutate: (inout GelPositionedLadderBand) -> Void) {
        guard let idx = workingInstance.ladderBands.firstIndex(where: { $0.id == id }) else { return }
        mutate(&workingInstance.ladderBands[idx])
    }

    private func commit() {
        onChange(workingInstance)
    }
}

private struct LaneEditorPopover: View {
    @State private var text: String
    var onSave: (String) -> Void
    var onDelete: () -> Void

    init(text: String, onSave: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self._text = State(initialValue: text)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Label", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onSave(text) }
            HStack {
                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                }
                Spacer()
                Button("Save") { onSave(text) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 220)
    }
}

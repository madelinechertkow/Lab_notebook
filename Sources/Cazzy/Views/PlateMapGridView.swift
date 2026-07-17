import SwiftUI

/// Shared well-grid component — used both to edit a `PlateMapTemplate`'s default layout in
/// the library and to edit a `PlateMapInstance` embedded in a note. Identical either way:
/// just a size and a binding to the well annotations.
struct PlateMapGridView: View {
    @EnvironmentObject var theme: ThemeStore
    let size: PlateSize
    @Binding var wells: [String: WellAnnotation]

    @State private var editingCoordinate: String?

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: size.columns)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(size.wellCoordinates, id: \.self) { coordinate in
                wellCell(coordinate)
            }
        }
    }

    @ViewBuilder
    private func wellCell(_ coordinate: String) -> some View {
        let annotation = wells[coordinate] ?? WellAnnotation()
        Button {
            editingCoordinate = coordinate
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(annotation.colorHex.map { Color(hex: $0) } ?? theme.editorBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.divider, lineWidth: 1)
                    )
                VStack(spacing: 2) {
                    Text(coordinate)
                        .font(.system(size: 8))
                        .foregroundStyle(theme.textTertiary)
                    if !annotation.label.isEmpty {
                        Text(annotation.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .aspectRatio(1, contentMode: .fit)
        .popover(isPresented: Binding(
            get: { editingCoordinate == coordinate },
            set: { if !$0 { editingCoordinate = nil } }
        )) {
            WellEditorPopover(
                coordinate: coordinate,
                annotation: Binding(
                    get: { wells[coordinate] ?? WellAnnotation() },
                    set: { wells[coordinate] = $0.isEmpty ? nil : $0 }
                )
            )
        }
    }
}

private struct WellEditorPopover: View {
    let coordinate: String
    @Binding var annotation: WellAnnotation
    @State private var colorEnabled: Bool

    init(coordinate: String, annotation: Binding<WellAnnotation>) {
        self.coordinate = coordinate
        self._annotation = annotation
        self._colorEnabled = State(initialValue: annotation.wrappedValue.colorHex != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Well \(coordinate)").font(.headline)

            TextField("Label", text: $annotation.label)
                .textFieldStyle(.roundedBorder)

            Toggle("Color", isOn: $colorEnabled)
                .onChange(of: colorEnabled) { enabled in
                    if !enabled {
                        annotation.colorHex = nil
                    } else if annotation.colorHex == nil {
                        annotation.colorHex = 0xCCCCCC
                    }
                }

            if colorEnabled {
                ColorPicker("Well color", selection: Binding(
                    get: { Color(hex: annotation.colorHex ?? 0xCCCCCC) },
                    set: { annotation.colorHex = $0.toHex() }
                ))
            }

            TextField("Notes", text: $annotation.notes)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
        .frame(width: 240)
    }
}

/// Renders one ```platemap block in note preview — a header (name/size) plus the grid,
/// bound directly to this note's copy of the layout (`Note.plateMapResults[blockID]`).
struct PlateMapBlockView: View {
    @EnvironmentObject var theme: ThemeStore
    let blockID: String
    let instance: PlateMapInstance
    let onChange: (PlateMapInstance) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.accentDeep)
                Text(instance.sourceTemplateName ?? "Plate Map")
                    .font(theme.bodyFont(12, weight: .semibold))
                Spacer()
                Text(instance.size.label)
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
            }

            PlateMapGridView(
                size: instance.size,
                wells: Binding(
                    get: { instance.wells },
                    set: { newWells in
                        var updated = instance
                        updated.wells = newWells
                        onChange(updated)
                    }
                )
            )
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.divider, lineWidth: 1))
        .padding(.vertical, 6)
    }
}

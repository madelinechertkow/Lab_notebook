import SwiftUI
import AppKit

/// Shared well-grid component — used both to edit a `PlateMapTemplate`'s default layout in
/// the library and to edit a `PlateMapInstance` embedded in a note. Identical either way:
/// just a size and a binding to the well annotations.
struct PlateMapGridView: View {
    @EnvironmentObject var theme: ThemeStore
    let size: PlateSize
    @Binding var wells: [String: WellAnnotation]

    /// Wells currently selected for a shared edit. A plain click replaces this with just
    /// that well; ⌘-click toggles a well in/out; ⇧-click selects the rectangle between the
    /// last-touched well and the clicked one — the same conventions as Finder icon view.
    @State private var selection: Set<String> = []
    @State private var anchorCoordinate: String?
    /// Which well's popover is currently open (the visual anchor point); the popover itself
    /// edits every coordinate in `selection`, not just this one.
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
        let isSelected = selection.contains(coordinate)
        Button {
            handleClick(coordinate)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(annotation.colorHex.map { Color(hex: $0) } ?? theme.editorBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? theme.accentDeep : theme.divider, lineWidth: isSelected ? 2.5 : 1)
                    )
                VStack(spacing: 2) {
                    Text(coordinate)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(coordinateColor(annotation))
                    if !annotation.label.isEmpty {
                        Text(annotation.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(labelColor(annotation))
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
            set: { presented in
                if !presented {
                    editingCoordinate = nil
                    selection = []
                }
            }
        )) {
            WellEditorPopover(coordinates: selection.isEmpty ? [coordinate] : selection.sorted(), wells: $wells)
        }
    }

    /// A well's own color, readable against whatever fill it has (or plain text color for
    /// an unfilled well) — labels were reading as near-invisible on some of the darker/more
    /// saturated fills before this.
    private func labelColor(_ annotation: WellAnnotation) -> Color {
        annotation.colorHex.map { Color(hex: $0).readableForeground } ?? theme.textPrimary
    }

    private func coordinateColor(_ annotation: WellAnnotation) -> Color {
        annotation.colorHex.map { Color(hex: $0).readableForeground.opacity(0.75) } ?? theme.textTertiary
    }

    private func handleClick(_ coordinate: String) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), let anchor = anchorCoordinate {
            selection = Self.rectangleRange(from: anchor, to: coordinate, size: size)
            editingCoordinate = nil
        } else if flags.contains(.command) {
            if selection.contains(coordinate) {
                selection.remove(coordinate)
            } else {
                selection.insert(coordinate)
            }
            anchorCoordinate = coordinate
            editingCoordinate = nil
        } else {
            if !(selection.contains(coordinate) && selection.count > 1) {
                selection = [coordinate]
            }
            anchorCoordinate = coordinate
            editingCoordinate = coordinate
        }
    }

    /// All well coordinates in the rectangle spanned by two corners, inclusive.
    private static func rectangleRange(from a: String, to b: String, size: PlateSize) -> Set<String> {
        guard let start = parse(a), let end = parse(b) else { return [b] }
        let rows = min(start.row, end.row)...max(start.row, end.row)
        let cols = min(start.col, end.col)...max(start.col, end.col)
        var result: Set<String> = []
        for row in rows {
            let rowLetter = String(UnicodeScalar(65 + row)!)
            for col in cols {
                result.insert("\(rowLetter)\(col + 1)")
            }
        }
        return result
    }

    private static func parse(_ coordinate: String) -> (row: Int, col: Int)? {
        guard let first = coordinate.first, let rowAscii = first.asciiValue else { return nil }
        guard let col = Int(coordinate.dropFirst()) else { return nil }
        return (Int(rowAscii) - 65, col - 1)
    }
}

/// Edits one or more wells at once — every field applies identically to all `coordinates`,
/// so selecting a block of wells and setting a label/color names and colors them together.
private struct WellEditorPopover: View {
    let coordinates: [String]
    @Binding var wells: [String: WellAnnotation]

    private var title: String {
        coordinates.count == 1 ? "Well \(coordinates[0])" : "\(coordinates.count) Wells (\(coordinates.first!)–\(coordinates.last!))"
    }

    /// Seeds from the first selected well and writes through to every selected well on
    /// every keystroke — no separate "apply" step.
    private var labelBinding: Binding<String> {
        Binding(
            get: { coordinates.first.flatMap { wells[$0]?.label } ?? "" },
            set: { newValue in applyToAll { $0.label = newValue } }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { coordinates.first.flatMap { wells[$0]?.notes } ?? "" },
            set: { newValue in applyToAll { $0.notes = newValue } }
        )
    }

    private var hasColor: Bool {
        coordinates.first.flatMap { wells[$0]?.colorHex } != nil
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: (coordinates.first.flatMap { wells[$0]?.colorHex }) ?? 0xCCCCCC) },
            set: { newColor in applyToAll { $0.colorHex = newColor.toHex() } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)

            TextField("Label", text: labelBinding)
                .textFieldStyle(.roundedBorder)

            HStack {
                ColorPicker("Color", selection: colorBinding)
                if hasColor {
                    Button("Clear") {
                        applyToAll { $0.colorHex = nil }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }

            TextField("Notes", text: notesBinding)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
        .frame(width: 260)
    }

    private func applyToAll(_ transform: (inout WellAnnotation) -> Void) {
        for coordinate in coordinates {
            var annotation = wells[coordinate] ?? WellAnnotation()
            transform(&annotation)
            wells[coordinate] = annotation.isEmpty ? nil : annotation
        }
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

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

    /// Drag-to-paint: pressing on a well and dragging across others copies that source
    /// well's color (and, while Shift is held, its label too) onto every well the pointer
    /// passes over. The painted wells are previewed live and written in one go on release,
    /// so a whole drag is a single edit. Notes are never copied.
    @State private var dragSource: String?
    @State private var dragPainted: Set<String> = []
    @State private var lastDragPoint: CGPoint?
    @State private var cellFrames: [String: CGRect] = [:]
    /// Whether Shift is held during the current drag — tracked live, so pressing or
    /// releasing Shift mid-drag updates the preview, and the state at release is what's saved.
    @State private var dragCopiesLabel = false

    private static let gridSpace = "plateMapGrid"

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: size.columns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("Drag from a well to copy its color to other wells. Hold ⇧ Shift while dragging to copy its label too.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(size.wellCoordinates, id: \.self) { coordinate in
                    wellCell(coordinate)
                }
            }
            .coordinateSpace(name: Self.gridSpace)
            .onPreferenceChange(WellFramesKey.self) { cellFrames = $0 }
        }
    }

    /// What a well should look like right now — its saved annotation, or, while it's being
    /// dragged over, the annotation it will get when the drag ends.
    private func displayedAnnotation(_ coordinate: String) -> WellAnnotation {
        let saved = wells[coordinate] ?? WellAnnotation()
        guard dragPainted.contains(coordinate), let source = dragSource else { return saved }
        return painted(saved, from: wells[source] ?? WellAnnotation())
    }

    private func painted(_ target: WellAnnotation, from source: WellAnnotation) -> WellAnnotation {
        var result = target
        if let color = source.colorHex { result.colorHex = color }
        if dragCopiesLabel && !source.label.isEmpty { result.label = source.label }
        return result
    }

    @ViewBuilder
    private func wellCell(_ coordinate: String) -> some View {
        let annotation = displayedAnnotation(coordinate)
        let isSelected = selection.contains(coordinate) || dragSource == coordinate
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
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: WellFramesKey.self,
                    value: [coordinate: proxy.frame(in: .named(Self.gridSpace))]
                )
            }
        )
        .onTapGesture { handleClick(coordinate) }
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.gridSpace))
                .onChanged { value in dragChanged(from: coordinate, value: value) }
                .onEnded { _ in dragEnded() }
        )
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

    private func dragChanged(from source: String, value: DragGesture.Value) {
        if dragSource == nil {
            dragSource = source
            dragPainted = []
            lastDragPoint = value.startLocation
            editingCoordinate = nil
            selection = []
        }
        // Sample along the segment since the last event so a fast drag doesn't skip wells.
        let from = lastDragPoint ?? value.location
        let to = value.location
        let steps = max(1, Int(hypot(to.x - from.x, to.y - from.y) / 4))
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let point = CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t)
            if let hit = cellFrames.first(where: { $0.value.contains(point) })?.key, hit != source {
                dragPainted.insert(hit)
            }
        }
        lastDragPoint = to
        dragCopiesLabel = NSEvent.modifierFlags.contains(.shift)
    }

    private func dragEnded() {
        defer {
            dragSource = nil
            dragPainted = []
            lastDragPoint = nil
            dragCopiesLabel = false
        }
        guard let sourceCoordinate = dragSource, !dragPainted.isEmpty else { return }
        let source = wells[sourceCoordinate] ?? WellAnnotation()
        // A source with nothing to copy leaves every well untouched (never clears anything).
        guard source.colorHex != nil || (dragCopiesLabel && !source.label.isEmpty) else { return }
        var updated = wells
        for coordinate in dragPainted {
            let result = painted(updated[coordinate] ?? WellAnnotation(), from: source)
            updated[coordinate] = result.isEmpty ? nil : result
        }
        wells = updated
        anchorCoordinate = sourceCoordinate
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

/// Each well's frame in the grid's coordinate space, so a drag location maps to a well.
private struct WellFramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
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
                Text("Color")
                WellColorWell(color: colorBinding)
                    .frame(width: 44, height: 24)
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

/// The popover's color swatch. A native `NSColorWell` rather than SwiftUI's `ColorPicker`
/// so that, if the system Colors window is already open when a well is clicked, the window
/// switches over to that well right away — no need to click the swatch first.
private struct WellColorWell: NSViewRepresentable {
    @Binding var color: Color

    func makeCoordinator() -> Coordinator { Coordinator(color: $color) }

    func makeNSView(context: Context) -> AutoActivatingColorWell {
        let well = AutoActivatingColorWell()
        well.color = NSColor(color)
        well.target = context.coordinator
        well.action = #selector(Coordinator.colorChanged(_:))
        well.coordinator = context.coordinator
        return well
    }

    func updateNSView(_ well: AutoActivatingColorWell, context: Context) {
        context.coordinator.color = $color
        let current = NSColor(color)
        if well.color != current {
            context.coordinator.isSyncing = true
            well.color = current
            context.coordinator.isSyncing = false
        }
    }

    final class Coordinator: NSObject {
        var color: Binding<Color>
        /// True while the swatch is being set up or synced programmatically, so only a
        /// color the user actually picks is written to the wells (merely clicking an
        /// uncolored well must never give it a color).
        var isSyncing = false

        init(color: Binding<Color>) { self.color = color }

        @objc func colorChanged(_ sender: NSColorWell) {
            guard !isSyncing else { return }
            color.wrappedValue = Color(nsColor: sender.color)
        }
    }
}

private final class AutoActivatingColorWell: NSColorWell {
    weak var coordinator: WellColorWell.Coordinator?
    private var didAutoActivate = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didAutoActivate, NSColorPanel.shared.isVisible else { return }
        didAutoActivate = true
        // Defer a tick so the popover has finished presenting before the panel retargets.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            self.coordinator?.isSyncing = true
            self.activate(true)
            self.coordinator?.isSyncing = false
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

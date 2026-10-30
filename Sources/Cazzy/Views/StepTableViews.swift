import SwiftUI

/// Editable grid under a step in the protocol editor: a title, a header row, then data rows,
/// all free text. Columns and rows are added/removed with the small controls around the grid.
struct StepTableEditor: View {
    @EnvironmentObject var theme: ThemeStore
    @Binding var table: StepTable
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "tablecells")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.accentDeep)
                TextField("Table title (optional)", text: $table.title, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(11, weight: .semibold))
                    .lineLimit(1...3)
                Spacer(minLength: 0)
                Button(action: onRemove) {
                    Label("Remove table", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textTertiary)
                .help("Remove this table from the step")
            }

            VStack(spacing: 0) {
                gridRow(cells: $table.columns, isHeader: true) {
                    columnControls
                }
                ForEach(table.rows.indices, id: \.self) { rowIndex in
                    Divider().overlay(theme.divider)
                    gridRow(cells: $table.rows[rowIndex], isHeader: false) {
                        Button {
                            table.rows.remove(at: rowIndex)
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textTertiary)
                        .help("Remove this row")
                    }
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(theme.divider, lineWidth: 1)
            )

            Button {
                table.rows.append(Array(repeating: "", count: table.columns.count))
            } label: {
                Label("Add row", systemImage: "plus")
                    .font(theme.bodyFont(11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
        }
        .padding(.top, 4)
    }

    private func gridRow<Trailing: View>(cells: Binding<[String]>, isHeader: Bool, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 8) {
            ForEach(cells.wrappedValue.indices, id: \.self) { column in
                TextField(isHeader ? "Column \(column + 1)" : "", text: cells[column], axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(11, weight: isHeader ? .semibold : .regular))
                    .foregroundStyle(isHeader ? theme.textSecondary : theme.textPrimary)
                    .lineLimit(1...3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            trailing()
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var columnControls: some View {
        HStack(spacing: 4) {
            Button {
                guard table.columns.count > 1 else { return }
                table.columns.removeLast()
                for index in table.rows.indices { table.rows[index].removeLast() }
            } label: {
                Image(systemName: "minus.square")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textTertiary)
            .disabled(table.columns.count <= 1)
            .help("Remove the last column")
            Button {
                table.columns.append("")
                for index in table.rows.indices { table.rows[index].append("") }
            } label: {
                Image(systemName: "plus.square")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
            .help("Add a column")
        }
    }
}

/// Read-only rendering of a step's table — used by the protocol's View mode.
struct StepTableDisplay: View {
    @EnvironmentObject var theme: ThemeStore
    let table: StepTable
    var fontSize: CGFloat = 13

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !table.title.isEmpty {
                Text(table.title)
                    .font(theme.bodyFont(fontSize - 1, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    ForEach(table.columns.indices, id: \.self) { column in
                        Text(table.columns[column])
                            .font(theme.bodyFont(fontSize - 1, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                Divider().overlay(theme.divider)
                ForEach(table.rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(table.columns.indices, id: \.self) { column in
                            Text(table.rows[row][column])
                                .font(theme.bodyFont(fontSize))
                                .foregroundStyle(theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.cardBackground)
            )
        }
    }
}

/// Sheet that works out a dilution and inserts the result as the step's table.
struct DilutionCalculatorSheet: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    let onInsert: (StepTable) -> Void

    private enum Mode: String, CaseIterable, Identifiable {
        case single = "Single dilution"
        case serial = "Serial dilution"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .single
    @State private var factor = ""
    @State private var totalVolume = ""
    @State private var stockName = ""
    @State private var diluent = ""
    @State private var startConcentration = ""
    @State private var tubes = 6
    @State private var volumePerTube = ""

    private var result: StepTable? {
        switch mode {
        case .single:
            return DilutionMath.single(factorText: factor, totalVolume: totalVolume, stockName: stockName, diluent: diluent)
        case .serial:
            return DilutionMath.serial(startConcentration: startConcentration, factorText: factor, tubes: tubes, volumePerTube: volumePerTube, diluent: diluent)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dilution Calculator")
                .font(theme.displayFont(18))
                .foregroundStyle(theme.textPrimary)

            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Form {
                switch mode {
                case .single:
                    TextField("What's being diluted", text: $stockName, prompt: Text("e.g. Primary antibody"))
                    TextField("Dilution", text: $factor, prompt: Text("e.g. 1:1000"))
                    TextField("Total volume", text: $totalVolume, prompt: Text("e.g. 10 mL"))
                    TextField("Dilute in", text: $diluent, prompt: Text("e.g. 5% BSA in PBST"))
                case .serial:
                    TextField("Starting concentration", text: $startConcentration, prompt: Text("e.g. 10 µM (optional)"))
                    TextField("Dilution each step", text: $factor, prompt: Text("e.g. 1:2"))
                    Stepper("Number of tubes: \(tubes)", value: $tubes, in: 2...24)
                    TextField("Final volume per tube", text: $volumePerTube, prompt: Text("e.g. 100 µL"))
                    TextField("Dilute in", text: $diluent, prompt: Text("e.g. media"))
                }
            }
            .formStyle(.grouped)
            .frame(minHeight: 200)

            Group {
                if let result {
                    ScrollView {
                        StepTableDisplay(table: result, fontSize: 12)
                    }
                    .frame(maxHeight: 220)
                } else {
                    Text("Enter a dilution (like 1:1000) and a volume (like 10 mL or 100 µL) to see the amounts.")
                        .font(theme.bodyFont(11))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add to Step") {
                    if let result { onInsert(result) }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(result == nil)
            }
        }
        .padding(20)
        .frame(width: 520)
        .background(theme.editorBackground)
    }
}

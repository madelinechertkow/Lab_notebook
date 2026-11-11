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

/// Edit-mode setup for a step's live dilution calculator: what's being diluted, the dilution,
/// what it goes into, and an optional volume to start from in View mode.
struct LiveDilutionEditor: View {
    @EnvironmentObject var theme: ThemeStore
    @Binding var dilution: LiveDilution
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "drop.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.accentDeep)
                Text("Live dilution calculator — usable in View mode")
                    .font(theme.bodyFont(11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Spacer(minLength: 0)
                Button(action: onRemove) {
                    Label("Remove calculator", systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textTertiary)
                .help("Remove the dilution calculator from this step")
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                field("What's diluted", text: $dilution.stockName, prompt: "e.g. Primary antibody")
                field("Dilution", text: $dilution.factor, prompt: "e.g. 1:1000")
                field("Dilute in", text: $dilution.diluent, prompt: "e.g. 5% BSA in PBST")
                field("Starting volume", text: $dilution.defaultVolume, prompt: "e.g. 10 mL (optional)")
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(theme.divider, lineWidth: 1)
            )

            Group {
                if DilutionMath.factor(dilution.factor) == nil {
                    Text("Enter the dilution as 1:1000 (or 1:2, 1:50…).")
                } else if let amounts = dilution.amounts(for: dilution.defaultVolume) {
                    Text("Preview: \(BufferMath.formatVolume(amounts.stock)) \(dilution.stockLabel) + \(BufferMath.formatVolume(amounts.diluent)) \(dilution.diluentLabel)")
                } else {
                    Text("In View mode, type the volume you need and the amounts are worked out.")
                }
            }
            .font(theme.bodyFont(10))
            .foregroundStyle(theme.textTertiary)
        }
        .padding(.top, 4)
    }

    private func field(_ label: String, text: Binding<String>, prompt: String) -> some View {
        GridRow {
            Text(label)
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)
                .gridColumnAlignment(.trailing)
            TextField("", text: text, prompt: Text(prompt))
                .textFieldStyle(.plain)
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textPrimary)
        }
    }
}

/// View-mode dilution calculator: the volume is typed at the bench and the amounts update live.
/// Nothing typed here is saved to the protocol.
struct LiveDilutionCalculator: View {
    @EnvironmentObject var theme: ThemeStore
    let dilution: LiveDilution
    var fontSize: CGFloat = 14

    private static let units = ["µL", "mL", "L"]

    @State private var amount: String = ""
    @State private var unit: String = "mL"
    @State private var didPrefill = false

    private var volumeText: String {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        // A bare number uses the picked unit; "500 µL" typed in full wins over the picker.
        if let number = BufferMath.leadingNumber(trimmed), number.rest.isEmpty { return "\(trimmed) \(unit)" }
        return trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(dilution.summary, systemImage: "drop.triangle")
                .font(theme.bodyFont(fontSize - 1, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: 8) {
                Text("Final volume")
                    .font(theme.bodyFont(fontSize - 1))
                    .foregroundStyle(theme.textSecondary)
                TextField("", text: $amount, prompt: Text("e.g. 10"))
                    .textFieldStyle(.roundedBorder)
                    .font(theme.bodyFont(fontSize))
                    .frame(width: 90)
                Picker("", selection: $unit) {
                    ForEach(Self.units, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            if let result = dilution.amounts(for: volumeText) {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    row(dilution.stockLabel, BufferMath.formatVolume(result.stock), bold: true)
                    row(dilution.diluentLabel, BufferMath.formatVolume(result.diluent), bold: true)
                    Divider().overlay(theme.divider)
                    row("Total", BufferMath.formatVolume(result.total), bold: false)
                }
            } else if DilutionMath.factor(dilution.factor) == nil {
                Text("This calculator has no dilution set yet — add one (like 1:1000) in Edit mode.")
                    .font(theme.bodyFont(fontSize - 2))
                    .foregroundStyle(theme.textTertiary)
            } else {
                Text("Type the volume you want to make to see how much of each to add.")
                    .font(theme.bodyFont(fontSize - 2))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.accentDeep.opacity(0.35), lineWidth: 1)
        )
        .onAppear(perform: prefill)
    }

    private func row(_ name: String, _ value: String, bold: Bool) -> some View {
        GridRow {
            Text(name)
                .font(theme.bodyFont(fontSize))
                .foregroundStyle(theme.textPrimary)
            Text(value)
                .font(theme.bodyFont(fontSize, weight: bold ? .bold : .regular))
                .foregroundStyle(bold ? theme.accentDeep : theme.textSecondary)
                .monospacedDigit()
        }
    }

    /// Splits the protocol's starting volume ("10 mL") into the number field and unit picker.
    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        guard let parsed = BufferMath.leadingNumber(dilution.defaultVolume) else { return }
        let rest = parsed.rest.trimmingCharacters(in: .whitespaces).lowercased()
            .replacingOccurrences(of: "μ", with: "µ").replacingOccurrences(of: "u", with: "µ")
        if let match = Self.units.first(where: { $0.lowercased() == rest }) {
            unit = match
            amount = BufferMath.formatNumber(parsed.value)
        } else {
            amount = dilution.defaultVolume
        }
    }
}

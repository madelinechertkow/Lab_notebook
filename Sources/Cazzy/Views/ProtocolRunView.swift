import SwiftUI

/// The protocol's View mode: everything you need at the bench and none of the editing controls,
/// in larger type. Buffers, materials and steps can be ticked off as you go; ticks are kept
/// only while Cazzy is open (they're a working aid, not part of the protocol).
struct ProtocolRunView: View {
    @EnvironmentObject var theme: ThemeStore
    let protocolItem: LabProtocol
    @Binding var checked: Set<UUID>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !protocolItem.purpose.isEmpty {
                    Text(protocolItem.purpose)
                        .font(theme.bodyFont(15))
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !protocolItem.buffers.isEmpty {
                    buffersSection
                }
                if !protocolItem.reagents.isEmpty {
                    materialsSection
                }
                if !protocolItem.steps.isEmpty {
                    procedureSection
                }
                if protocolItem.purpose.isEmpty && protocolItem.buffers.isEmpty && protocolItem.reagents.isEmpty && protocolItem.steps.isEmpty {
                    Text("This protocol is empty — click Edit to add to it.")
                        .font(theme.bodyFont(14))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
    }

    // MARK: - Sections

    private func heading(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(theme.displayFont(19))
            .foregroundStyle(theme.textPrimary)
    }

    private var buffersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Buffers & Solutions", systemImage: "drop")
            ForEach(protocolItem.buffers) { buffer in
                HStack(alignment: .top, spacing: 12) {
                    checkbox(buffer.id)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(buffer.name.isEmpty ? "Untitled buffer" : buffer.name)
                                .font(theme.bodyFont(16, weight: .semibold))
                            if !buffer.finalVolume.isEmpty {
                                Text("makes \(buffer.finalVolume)")
                                    .font(theme.bodyFont(13))
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        if !buffer.components.isEmpty {
                            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                                GridRow {
                                    Color.clear.frame(width: 6, height: 1)
                                    Text("Component")
                                    Text("Stock")
                                    Text("Final")
                                    Text("Add")
                                }
                                .font(theme.bodyFont(12, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                                ForEach(buffer.components) { component in
                                    GridRow {
                                        Text("•")
                                            .fontWeight(.bold)
                                            .foregroundStyle(theme.accentDeep)
                                        Text(component.name)
                                        Text(component.stockConcentration)
                                        Text(component.finalConcentration)
                                        Text(buffer.displayAmount(for: component))
                                            .fontWeight(.semibold)
                                    }
                                    .font(theme.bodyFont(14))
                                }
                            }
                        }
                        if !buffer.finalVolume.isEmpty || !buffer.solvent.isEmpty {
                            Label(bringToVolumeLine(buffer), systemImage: "arrow.turn.down.right")
                                .font(theme.bodyFont(15, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(theme.accentDeep.opacity(0.12))
                                )
                                .padding(.top, 4)
                        }
                        if !buffer.instructions.isEmpty {
                            Text(buffer.instructions)
                                .font(theme.bodyFont(13))
                                .foregroundStyle(theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .foregroundStyle(theme.textPrimary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .softCard(cornerRadius: 10)
                .opacity(checked.contains(buffer.id) ? 0.5 : 1)
            }
        }
    }

    private func bringToVolumeLine(_ buffer: BufferRecipe) -> String {
        var line = "Then bring to \(buffer.finalVolume.isEmpty ? "volume" : buffer.finalVolume)"
        if !buffer.solvent.isEmpty { line += " with \(buffer.solvent)" }
        if let solventVolume = buffer.solventVolume { line += " (≈ \(solventVolume))" }
        return line + "."
    }

    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading("Materials & Reagents", systemImage: "cross.vial")
            let groups: [(title: String?, reagents: [Reagent])] = protocolItem.reagents.isUncategorized
                ? [(nil, protocolItem.reagents)]
                : protocolItem.reagents.groupedByCategory.map { ($0.category.title, $0.reagents) }
            ForEach(groups, id: \.title) { group in
                VStack(alignment: .leading, spacing: 6) {
                    if let title = group.title {
                        Text(title)
                            .font(theme.bodyFont(12, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                            .padding(.top, 4)
                    }
                    ForEach(group.reagents) { reagent in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            checkbox(reagent.id)
                            Text(reagent.name)
                                .font(theme.bodyFont(14, weight: .medium))
                            let amount = [reagent.amount, reagent.unit].filter { !$0.isEmpty }.joined(separator: " ")
                            if !amount.isEmpty {
                                Text(amount)
                                    .font(theme.bodyFont(14))
                            }
                            if !reagent.notes.isEmpty {
                                Text(reagent.notes)
                                    .font(theme.bodyFont(13))
                                    .foregroundStyle(theme.textTertiary)
                            }
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(theme.textPrimary)
                        .opacity(checked.contains(reagent.id) ? 0.5 : 1)
                    }
                }
            }
        }
    }

    private var procedureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading("Procedure", systemImage: "list.number")
            let numbers = protocolItem.steps.stepNumbers
            ForEach(Array(protocolItem.steps.enumerated()), id: \.element.id) { index, step in
                switch step.kind {
                case .section:
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.text.isEmpty ? "Section" : step.text)
                            .font(theme.displayFont(17))
                            .foregroundStyle(theme.textPrimary)
                        Rectangle()
                            .fill(theme.accentDeep.opacity(0.4))
                            .frame(height: 1.5)
                    }
                    .padding(.top, 10)
                case .note, .warning, .pause:
                    callout(step)
                case .step:
                    stepRow(step, number: numbers[index])
                }
            }
        }
    }

    private func stepRow(_ step: ProtocolStep, number: Int) -> some View {
        let isDone = checked.contains(step.id)
        let flagColor: Color? = switch step.importance {
        case .critical: .red
        case .important: .orange
        case .normal: nil
        }
        return HStack(alignment: .top, spacing: 12) {
            checkbox(step.id)
            Text("\(number).")
                .font(theme.bodyFont(16, weight: .bold))
                .foregroundStyle(theme.accentDeep)
                .frame(minWidth: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: 6) {
                Text(step.text)
                    .font(theme.bodyFont(16))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                let details = stepDetails(step)
                if !details.isEmpty || flagColor != nil {
                    HStack(spacing: 12) {
                        ForEach(details, id: \.self) { detail in
                            Text(detail)
                        }
                        if let flagColor {
                            Label(step.importance == .critical ? "CRITICAL" : "IMPORTANT", systemImage: "flag.fill")
                                .foregroundStyle(flagColor)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
                }
                if !step.notes.isEmpty {
                    Text(step.notes)
                        .font(theme.bodyFont(13))
                        .italic()
                        .foregroundStyle(theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let table = step.table {
                    StepTableDisplay(table: table, fontSize: 14)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(flagColor?.opacity(0.10) ?? theme.cardBackground)
        )
        .opacity(isDone ? 0.5 : 1)
    }

    private func stepDetails(_ step: ProtocolStep) -> [String] {
        var details: [String] = []
        if let minutes = step.durationMinutes { details.append("⏱ \(DurationText.format(minutes))") }
        if let temperature = step.temperatureCelsius { details.append("🌡 \(String(format: "%g", temperature)) °C") }
        return details
    }

    private func callout(_ step: ProtocolStep) -> some View {
        let color: Color = switch step.kind {
        case .warning: .orange
        case .pause: .teal
        default: .blue
        }
        let label = switch step.kind {
        case .warning: "WARNING"
        case .pause: "⏸ PAUSE POINT — safe to stop here"
        default: "NOTE"
        }
        return HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(theme.bodyFont(11, weight: .heavy))
                    .foregroundStyle(color)
                    .tracking(0.5)
                Text(step.text)
                    .font(theme.bodyFont(15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            Spacer(minLength: 0)
        }
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func checkbox(_ id: UUID) -> some View {
        let isOn = checked.contains(id)
        return Button {
            if isOn { checked.remove(id) } else { checked.insert(id) }
        } label: {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(isOn ? theme.accentDeep : theme.textTertiary)
        }
        .buttonStyle(.plain)
        .help(isOn ? "Mark as not done" : "Mark as done")
    }
}

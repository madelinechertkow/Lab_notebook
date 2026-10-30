import SwiftUI

/// One buffer recipe in the protocol editor: name + volume to make, a component table
/// (stock → final concentration, amount to add), the solvent to bring it to volume, and
/// preparation notes. Leaving a component's amount blank shows the C₁V₁ = C₂V₂ amount from
/// `BufferMath` as the placeholder, so the common case needs no arithmetic.
struct BufferRecipeCard: View {
    @EnvironmentObject var theme: ThemeStore
    @Binding var buffer: BufferRecipe
    let onDelete: () -> Void

    private let stockWidth: CGFloat = 70
    private let finalWidth: CGFloat = 70
    private let amountWidth: CGFloat = 80

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Buffer name (e.g. 1× PBS, Lysis buffer)", text: $buffer.name)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("Makes")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textTertiary)
                TextField("500 mL", text: $buffer.finalVolume)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12, weight: .medium))
                    .frame(width: 70)
                    .help("Total volume to make — amounts are calculated from this")
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .help("Remove this buffer")
            }

            componentTable

            // Set apart in its own tinted box so it reads as the step after the components,
            // not as one more row of the table.
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accentDeep)
                Text("Then bring to \(buffer.finalVolume.isEmpty ? "volume" : buffer.finalVolume) with")
                    .font(theme.bodyFont(12, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                TextField("Milli-Q water", text: $buffer.solvent)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12, weight: .semibold))
                if let solventVolume = buffer.solventVolume {
                    Text("(≈ \(solventVolume))")
                        .font(theme.bodyFont(12))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.accentDeep.opacity(0.12))
            )
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Preparation")
                    .font(theme.bodyFont(11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextField("e.g. Adjust pH to 7.4 with HCl, filter (0.22 µm), store at 4 °C", text: $buffer.instructions, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12))
                    .lineLimit(1...6)
            }
        }
        .padding(12)
        .softCard(cornerRadius: 10)
    }

    private var componentTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 8)
                Text("Component").frame(maxWidth: .infinity, alignment: .leading)
                Text("Stock").frame(width: stockWidth, alignment: .leading)
                Text("Final").frame(width: finalWidth, alignment: .leading)
                Text("Amount to add").frame(width: amountWidth, alignment: .leading)
                Color.clear.frame(width: 10)
            }
            .font(theme.bodyFont(10, weight: .semibold))
            .foregroundStyle(theme.textTertiary)

            ForEach($buffer.components) { $component in
                HStack(spacing: 8) {
                    Text("•")
                        .font(theme.bodyFont(14, weight: .bold))
                        .foregroundStyle(theme.accentDeep)
                        .frame(width: 8)
                    TextField("Tris-HCl pH 7.5", text: $component.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("1 M", text: $component.stockConcentration)
                        .frame(width: stockWidth)
                    TextField("50 mM", text: $component.finalConcentration)
                        .frame(width: finalWidth)
                    // Blank → the calculated amount shows as the placeholder (and is what
                    // prints / backs up); typing anything overrides it, e.g. "2.92 g" of a powder.
                    TextField(calculatedAmount(component) ?? "amount", text: $component.amount)
                        .frame(width: amountWidth)
                        .help(calculatedAmount(component).map { "Calculated: \($0). Type to override." }
                            ?? "Enter stock, final, and the volume to make to calculate this, or type an amount (e.g. 2.92 g).")
                    Button {
                        buffer.components.removeAll { $0.id == component.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: 10)
                }
                .textFieldStyle(.plain)
                .font(theme.bodyFont(12))
                .padding(.vertical, 3)
                Divider().overlay(theme.divider)
            }

            Button {
                buffer.components.append(BufferComponent())
            } label: {
                Label("Add component", systemImage: "plus")
                    .font(theme.bodyFont(11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
            .padding(.top, 2)
        }
    }

    private func calculatedAmount(_ component: BufferComponent) -> String? {
        BufferMath.amountToAdd(stock: component.stockConcentration, final: component.finalConcentration, totalVolume: buffer.finalVolume)
    }
}

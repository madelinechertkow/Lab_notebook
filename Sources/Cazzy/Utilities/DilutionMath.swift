import Foundation

/// Builds the `StepTable` for a dilution, so the numbers are worked out once and the result is
/// an ordinary table the user can still edit. Returns nil for input it can't make sense of.
enum DilutionMath {
    /// "1:1000", "1000", "1/1000" → 1000.
    static func factor(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let last = trimmed.split(whereSeparator: { $0 == ":" || $0 == "/" }).last.map(String.init) ?? trimmed
        guard let value = Double(last.trimmingCharacters(in: .whitespaces)), value > 1 else { return nil }
        return value
    }

    /// One dilution: how much stock and diluent make `totalVolume` at 1:`factor`.
    static func single(factorText: String, totalVolume: String, stockName: String, diluent: String) -> StepTable? {
        guard let factor = factor(factorText), let total = BufferMath.volumeInLiters(totalVolume) else { return nil }
        let stock = total / factor
        let stockLabel = stockName.isEmpty ? "Stock" : stockName
        let diluentLabel = diluent.isEmpty ? "Diluent" : diluent
        return StepTable(
            title: "1:\(BufferMath.formatNumber(factor)) dilution — makes \(BufferMath.formatVolume(total))",
            columns: ["Component", "Amount"],
            rows: [
                [stockLabel, BufferMath.formatVolume(stock)],
                [diluentLabel, BufferMath.formatVolume(total - stock)],
                ["Total", BufferMath.formatVolume(total)],
            ]
        )
    }

    /// A serial dilution where every tube ends up holding `volumePerTube`: each tube after the
    /// first gets `volumePerTube` of diluent, then `volumePerTube / (factor − 1)` is carried over
    /// from the tube before (which leaves 1:factor), mixed, and the same amount moved on. Tube 1
    /// therefore starts with volume + transfer of the starting solution, and the carry-over from
    /// the last tube is discarded.
    static func serial(startConcentration: String, factorText: String, tubes: Int, volumePerTube: String, diluent: String) -> StepTable? {
        guard let factor = factor(factorText),
              tubes >= 2, tubes <= 96,
              let volume = BufferMath.volumeInLiters(volumePerTube) else { return nil }
        let transfer = volume / (factor - 1)
        let start = BufferMath.leadingNumber(startConcentration)
        let diluentLabel = diluent.isEmpty ? "diluent" : diluent

        var rows: [[String]] = []
        for tube in 1...tubes {
            let concentration: String
            if let start {
                let value = start.value / pow(factor, Double(tube - 1))
                concentration = [BufferMath.formatNumber(value), start.rest].filter { !$0.isEmpty }.joined(separator: " ")
            } else {
                concentration = tube == 1 ? "1×" : "1:\(BufferMath.formatNumber(pow(factor, Double(tube - 1))))"
            }
            if tube == 1 {
                rows.append(["1", concentration, "\(BufferMath.formatVolume(volume + transfer)) starting solution", "—"])
            } else {
                rows.append(["\(tube)", concentration, "\(BufferMath.formatVolume(transfer)) from tube \(tube - 1)", "\(BufferMath.formatVolume(volume)) \(diluentLabel)"])
            }
        }
        return StepTable(
            title: "1:\(BufferMath.formatNumber(factor)) serial dilution — mix each tube before moving on; discard \(BufferMath.formatVolume(transfer)) from tube \(tubes) so every tube holds \(BufferMath.formatVolume(volume))",
            columns: ["Tube", "Concentration", "Add", "Diluent"],
            rows: rows
        )
    }
}

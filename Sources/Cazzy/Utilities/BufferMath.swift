import Foundation

/// C₁V₁ = C₂V₂ for buffer recipes: given a stock and a final concentration plus the total
/// volume being made, works out how much stock to add. Everything is parsed from the free text
/// the user typed ("1 M", "50mM", "10X", "0.5 mg/mL", "500 mL"), and any input it doesn't
/// understand — or stock/final in incompatible units — just yields nil, so the user can always
/// type the amount by hand instead.
enum BufferMath {
    private enum Family {
        case molar, times, percent, massPerVolume, unitsPerVolume
    }

    /// Multipliers to a base unit per family (M, X, %, g/L, U/mL). Keys are lowercased with µ/μ
    /// normalised to "u" — case-insensitive is safe here because no two units in this table
    /// differ only by case once you're already reading a concentration.
    private static let concentrationUnits: [String: (Family, Double)] = [
        "m": (.molar, 1), "mm": (.molar, 1e-3), "um": (.molar, 1e-6), "nm": (.molar, 1e-9), "pm": (.molar, 1e-12),
        "mol/l": (.molar, 1), "mmol/l": (.molar, 1e-3),
        "x": (.times, 1),
        "%": (.percent, 1),
        "g/l": (.massPerVolume, 1), "g/ml": (.massPerVolume, 1000),
        "mg/ml": (.massPerVolume, 1), "mg/l": (.massPerVolume, 1e-3),
        "ug/ml": (.massPerVolume, 1e-3), "ug/ul": (.massPerVolume, 1), "ug/l": (.massPerVolume, 1e-6),
        "ng/ul": (.massPerVolume, 1e-3), "ng/ml": (.massPerVolume, 1e-6),
        "u/ml": (.unitsPerVolume, 1), "u/ul": (.unitsPerVolume, 1000), "u/l": (.unitsPerVolume, 1e-3),
    ]

    /// To liters.
    private static let volumeUnits: [String: Double] = [
        "l": 1, "ml": 1e-3, "ul": 1e-6, "nl": 1e-9,
    ]

    /// Volume of stock to add, formatted ("25 mL", "2.5 µL"), or nil if it can't be worked out.
    static func amountToAdd(stock: String, final: String, totalVolume: String) -> String? {
        guard let (stockFamily, stockValue) = concentration(stock),
              let (finalFamily, finalValue) = concentration(final),
              stockFamily == finalFamily,
              stockValue > 0, finalValue > 0, finalValue <= stockValue,
              let liters = volumeInLiters(totalVolume)
        else { return nil }
        return formatVolume(liters * finalValue / stockValue)
    }

    /// Total volume minus the component volumes — how much water/solvent to add. nil unless
    /// every non-empty amount is a liquid volume (a powder in grams makes this unknowable).
    static func remainingVolume(total: String, components amounts: [String]) -> String? {
        guard let totalLiters = volumeInLiters(total) else { return nil }
        var used = 0.0
        for amount in amounts where !amount.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let liters = volumeInLiters(amount) else { return nil }
            used += liters
        }
        let remaining = totalLiters - used
        return remaining > 0 ? formatVolume(remaining) : nil
    }

    static func volumeInLiters(_ text: String) -> Double? {
        guard let (value, unit) = split(text), let multiplier = volumeUnits[unit] else { return nil }
        return value * multiplier
    }

    private static func concentration(_ text: String) -> (Family, Double)? {
        guard let (value, unit) = split(text), let (family, multiplier) = concentrationUnits[unit] else { return nil }
        return (family, value * multiplier)
    }

    /// "50 mM" → (50, "mm"). Leading number, then the rest as a normalised unit string.
    private static func split(_ text: String) -> (Double, String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var numberEnd = trimmed.startIndex
        for index in trimmed.indices {
            let character = trimmed[index]
            guard character.isNumber || character == "." || character == "," else { break }
            numberEnd = trimmed.index(after: index)
        }
        let numberText = trimmed[..<numberEnd].replacingOccurrences(of: ",", with: ".")
        guard let value = Double(numberText) else { return nil }
        let unit = trimmed[numberEnd...]
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "µ", with: "u")
            .replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        return (value, unit)
    }

    /// "10 µM" → (10, "µM"): the leading number, and the rest exactly as typed (for display).
    static func leadingNumber(_ text: String) -> (value: Double, rest: String)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let numberEnd = trimmed.firstIndex { !($0.isNumber || $0 == "." || $0 == ",") } ?? trimmed.endIndex
        guard let value = Double(trimmed[..<numberEnd].replacingOccurrences(of: ",", with: ".")) else { return nil }
        return (value, trimmed[numberEnd...].trimmingCharacters(in: .whitespaces))
    }

    /// Up to 3 significant figures, no grouping separator: 0.123, 12.3, 1230.
    static func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = 3
        formatter.minimumSignificantDigits = 1
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Picks L / mL / µL so the number reads naturally, to at most 3 significant figures.
    static func formatVolume(_ liters: Double) -> String {
        let (value, unit): (Double, String)
        if liters >= 1 {
            (value, unit) = (liters, "L")
        } else if liters >= 1e-3 {
            (value, unit) = (liters * 1e3, "mL")
        } else {
            (value, unit) = (liters * 1e6, "µL")
        }
        return "\(formatNumber(value)) \(unit)"
    }
}

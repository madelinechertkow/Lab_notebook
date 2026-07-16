import SwiftUI
import AppKit

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    func toHex() -> UInt32 {
        let nsColor = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor.black
        let r = UInt32((nsColor.redComponent * 255).rounded())
        let g = UInt32((nsColor.greenComponent * 255).rounded())
        let b = UInt32((nsColor.blueComponent * 255).rounded())
        return (r << 16) | (g << 8) | b
    }
}

enum FontChoice: String, CaseIterable, Identifiable, Codable {
    case serif, rounded, defaultSystem, monospaced
    case georgia, avenirNext, futura, palatino, optima, menlo, baskerville

    var id: String { rawValue }

    var label: String {
        switch self {
        case .serif: return "System Serif"
        case .rounded: return "System Rounded"
        case .defaultSystem: return "System Default"
        case .monospaced: return "System Monospaced"
        case .georgia: return "Georgia"
        case .avenirNext: return "Avenir Next"
        case .futura: return "Futura"
        case .palatino: return "Palatino"
        case .optima: return "Optima"
        case .menlo: return "Menlo"
        case .baskerville: return "Baskerville"
        }
    }

    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .serif: return .system(size: size, weight: weight, design: .serif)
        case .rounded: return .system(size: size, weight: weight, design: .rounded)
        case .defaultSystem: return .system(size: size, weight: weight, design: .default)
        case .monospaced: return .system(size: size, weight: weight, design: .monospaced)
        case .georgia: return .custom("Georgia", size: size).weight(weight)
        case .avenirNext: return .custom("Avenir Next", size: size).weight(weight)
        case .futura: return .custom("Futura", size: size).weight(weight)
        case .palatino: return .custom("Palatino", size: size).weight(weight)
        case .optima: return .custom("Optima", size: size).weight(weight)
        case .menlo: return .custom("Menlo", size: size).weight(weight)
        case .baskerville: return .custom("Baskerville", size: size).weight(weight)
        }
    }
}

// MARK: - Color math for deriving a full theme from a handful of source colors

private func hexComponents(_ hex: UInt32) -> (r: Double, g: Double, b: Double) {
    (Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF))
}

private func componentsToHex(_ r: Double, _ g: Double, _ b: Double) -> UInt32 {
    let ri = UInt32(max(0, min(255, r)).rounded())
    let gi = UInt32(max(0, min(255, g)).rounded())
    let bi = UInt32(max(0, min(255, b)).rounded())
    return (ri << 16) | (gi << 8) | bi
}

private func mixHex(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
    let ca = hexComponents(a)
    let cb = hexComponents(b)
    return componentsToHex(
        ca.r + (cb.r - ca.r) * t,
        ca.g + (cb.g - ca.g) * t,
        ca.b + (cb.b - ca.b) * t
    )
}

private func hsbComponents(_ hex: UInt32) -> (h: Double, s: Double, b: Double) {
    let c = hexComponents(hex)
    let r = c.r / 255, g = c.g / 255, b = c.b / 255
    let maxV = max(r, g, b), minV = min(r, g, b)
    let delta = maxV - minV
    var h: Double = 0
    if delta != 0 {
        if maxV == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxV == g { h = (b - r) / delta + 2 }
        else { h = (r - g) / delta + 4 }
        h *= 60
        if h < 0 { h += 360 }
    }
    let sat = maxV == 0 ? 0 : delta / maxV
    return (h, sat, maxV)
}

struct AppTheme: Codable, Equatable {
    var name: String

    var accentHex: UInt32
    var accentDeepHex: UInt32
    var secondaryAccentHex: UInt32
    var tertiaryAccentHex: UInt32

    var backgroundHex: UInt32
    var sidebarHex: UInt32
    var cardBackgroundHex: UInt32
    var editorBackgroundHex: UInt32

    var textPrimaryHex: UInt32
    var textSecondaryHex: UInt32
    var textTertiaryHex: UInt32
    var dividerHex: UInt32

    var displayFont: FontChoice
    var bodyFont: FontChoice

    /// Derives a full, legible theme from five source colors (e.g. a Coolors.co palette).
    /// Picks the darkest color for text, the lightest for backgrounds, and the three
    /// most saturated of the remaining colors for accents.
    static func generated(name: String, hexes: [UInt32], displayFont: FontChoice, bodyFont: FontChoice) -> AppTheme {
        precondition(hexes.count == 5)
        let byBrightness = hexes.sorted { hsbComponents($0).b < hsbComponents($1).b }
        let darkest = byBrightness[0]
        let lightest = byBrightness[4]
        let middleThree = Array(byBrightness[1...3])
        let bySaturation = middleThree.sorted { hsbComponents($0).s > hsbComponents($1).s }

        var textPrimary = darkest
        if hsbComponents(textPrimary).b > 0.35 {
            textPrimary = mixHex(textPrimary, 0x000000, 0.45)
        }

        var lightBase = lightest
        if hsbComponents(lightBase).b < 0.75 {
            lightBase = mixHex(lightBase, 0xFFFFFF, 0.35)
        }

        let background = mixHex(lightBase, 0xFFFFFF, 0.5)
        let sidebar = mixHex(lightest, 0xFFFFFF, 0.4)
        let cardBackground = mixHex(lightBase, 0xFFFFFF, 0.82)
        let editorBackground = mixHex(lightBase, 0xFFFFFF, 0.76)

        let accent = bySaturation[0]
        let secondaryAccent = bySaturation[1]
        let tertiaryAccent = bySaturation[2]
        let accentDeep = mixHex(accent, 0x000000, 0.22)

        let textSecondary = mixHex(textPrimary, background, 0.42)
        let textTertiary = mixHex(textPrimary, background, 0.66)
        let divider = mixHex(secondaryAccent, background, 0.85)

        return AppTheme(
            name: name,
            accentHex: accent, accentDeepHex: accentDeep, secondaryAccentHex: secondaryAccent, tertiaryAccentHex: tertiaryAccent,
            backgroundHex: background, sidebarHex: sidebar,
            cardBackgroundHex: cardBackground, editorBackgroundHex: editorBackground,
            textPrimaryHex: textPrimary, textSecondaryHex: textSecondary, textTertiaryHex: textTertiary, dividerHex: divider,
            displayFont: displayFont, bodyFont: bodyFont
        )
    }

    static let presets: [AppTheme] = [
        generated(name: "Merlot & Moss", hexes: [0x6a0136, 0xbfab25, 0xb81365, 0x026c7c, 0x055864], displayFont: .serif, bodyFont: .defaultSystem),
        generated(name: "Cosmic Candy", hexes: [0x1b065e, 0xff47da, 0xff87ab, 0xfcc8c2, 0xf5eccd], displayFont: .rounded, bodyFont: .rounded),
        generated(name: "Neon Orchid", hexes: [0x2f2d2e, 0xdadff7, 0x792359, 0xd72483, 0xfd3e81], displayFont: .defaultSystem, bodyFont: .rounded),
        generated(name: "Desert Slate", hexes: [0x628395, 0x96897b, 0xdbad6a, 0xcf995f, 0xd0ce7c], displayFont: .baskerville, bodyFont: .defaultSystem),
        generated(name: "Carnival", hexes: [0x540d6e, 0xee4266, 0xffd23f, 0x3bceac, 0x0ead69], displayFont: .futura, bodyFont: .rounded),
        generated(name: "Harvest Dusk", hexes: [0xe3b505, 0x95190c, 0x610345, 0x107e7d, 0x044b7f], displayFont: .palatino, bodyFont: .defaultSystem),
        generated(name: "Antique Rose", hexes: [0xbfb48f, 0x564e58, 0x904e55, 0xf2efe9, 0x252627], displayFont: .georgia, bodyFont: .defaultSystem),
        generated(name: "Regatta", hexes: [0x06aed5, 0x086788, 0xf0c808, 0xfff1d0, 0xdd1c1a], displayFont: .avenirNext, bodyFont: .defaultSystem),
        generated(name: "Jewel Tone", hexes: [0xffbc42, 0xd81159, 0x8f2d56, 0x218380, 0x73d2de], displayFont: .serif, bodyFont: .rounded),
        generated(name: "Mossy Mint", hexes: [0x1d1e18, 0x6b8f71, 0xaad2ba, 0xd9fff5, 0xb9f5d8], displayFont: .optima, bodyFont: .defaultSystem),
        generated(name: "Twilight Blush", hexes: [0x190b28, 0x685762, 0x9b9987, 0xefa9ae, 0xe55381], displayFont: .serif, bodyFont: .rounded),
        generated(name: "Coastal Linen", hexes: [0xebe9e9, 0xf3f8f2, 0x3581b8, 0xfcb07e, 0xdee2d6], displayFont: .defaultSystem, bodyFont: .defaultSystem),
        generated(name: "Cotton Candy", hexes: [0xbaf2bb, 0xbaf2d8, 0xbad7f2, 0xf2bac9, 0xf2e2ba], displayFont: .rounded, bodyFont: .rounded),
        generated(name: "Peach Blossom", hexes: [0xf2ccc3, 0xe78f8e, 0xffe6e8, 0xacd8aa, 0xf48498], displayFont: .serif, bodyFont: .rounded),
    ]

    static let `default` = presets[13]
}

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
        generated(name: "Velvet Ember", hexes: [0x22162b, 0x451f55, 0x724e91, 0xe54f6d, 0xf8c630], displayFont: .serif, bodyFont: .defaultSystem),
        generated(name: "Marina Sunset", hexes: [0x8ecae6, 0x219ebc, 0x023047, 0xffb703, 0xfb8500], displayFont: .avenirNext, bodyFont: .defaultSystem),
        generated(name: "Olive Grove", hexes: [0x606c38, 0x283618, 0xfefae0, 0xdda15e, 0xbc6c25], displayFont: .georgia, bodyFont: .defaultSystem),
        generated(name: "Tidal Autumn", hexes: [0x264653, 0x2a9d8f, 0xe9c46a, 0xf4a261, 0xe76f51], displayFont: .futura, bodyFont: .rounded),
        generated(name: "Smoked Amber", hexes: [0x04151f, 0x183a37, 0xefd6ac, 0xc44900, 0x432534], displayFont: .palatino, bodyFont: .defaultSystem),
        generated(name: "Wine & Blush", hexes: [0x461220, 0x8c2f39, 0xb23a48, 0xfcb9b2, 0xfed0bb], displayFont: .serif, bodyFont: .rounded),
        generated(name: "Dusty Sunset", hexes: [0xfaa275, 0xff8c61, 0xce6a85, 0x985277, 0x5c374c], displayFont: .rounded, bodyFont: .rounded),
        generated(name: "Sage & Rust", hexes: [0xd4e09b, 0xf6f4d2, 0xcbdfbd, 0xf19c79, 0xa44a3f], displayFont: .optima, bodyFont: .defaultSystem),
        generated(name: "Brick & Violet", hexes: [0xfff8f0, 0x9e2b25, 0x51355a, 0x2a0c4e, 0xf5f8de], displayFont: .defaultSystem, bodyFont: .defaultSystem),
        generated(name: "Orchid Meadow", hexes: [0x805d93, 0xf49fbc, 0xffd3ba, 0x9ebd6e, 0x169873], displayFont: .rounded, bodyFont: .rounded),
        generated(name: "Terracotta Mist", hexes: [0xde6b48, 0xe5b181, 0xf4b9b2, 0xdaedbd, 0x7dbbc3], displayFont: .georgia, bodyFont: .defaultSystem),
        generated(name: "Deep Current", hexes: [0x78c0e0, 0x449dd1, 0x192bc2, 0x150578, 0x0e0e52], displayFont: .menlo, bodyFont: .monospaced),
        generated(name: "Taupe & Linen", hexes: [0xf7f0f5, 0xdecbb7, 0x8f857d, 0x5c5552, 0x433633], displayFont: .baskerville, bodyFont: .defaultSystem),
        generated(name: "Blue Hour", hexes: [0x1d3461, 0x1f487e, 0x376996, 0x6290c8, 0x829cbc], displayFont: .avenirNext, bodyFont: .rounded),
        generated(name: "Fern Garden", hexes: [0xe9f5db, 0xcfe1b9, 0xb5c99a, 0x97a97c, 0x718355], displayFont: .defaultSystem, bodyFont: .defaultSystem),
        generated(name: "Golden Hour", hexes: [0xffd289, 0xfacc6b, 0xffd131, 0xf5b82e, 0xf4ac32], displayFont: .futura, bodyFont: .rounded),
        generated(name: "Amethyst Dream", hexes: [0xf4effa, 0x2f184b, 0x532b88, 0x9b72cf, 0xc8b1e4], displayFont: .serif, bodyFont: .rounded),
        generated(name: "Mint Meadow", hexes: [0xdaf2d7, 0xe4fde1, 0xc6edc3, 0xa7dca5, 0x90cf8e], displayFont: .rounded, bodyFont: .rounded),
        generated(name: "Lavender Fields", hexes: [0xe1d8f7, 0xd7c8f3, 0xd0bef2, 0xc0a7eb, 0xb596e5], displayFont: .optima, bodyFont: .defaultSystem),
        generated(name: "Cinnamon & Clay", hexes: [0xe6ccb2, 0xddb892, 0xb08968, 0x7f5539, 0x9c6644], displayFont: .georgia, bodyFont: .defaultSystem),
        generated(name: "Deep Teal", hexes: [0x03312e, 0x037171, 0x009f93, 0x00b9ae, 0x02c3bd], displayFont: .menlo, bodyFont: .defaultSystem),
    ]

    static let `default` = presets[13]
}

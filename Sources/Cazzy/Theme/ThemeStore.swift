import SwiftUI
import AppKit
import Combine

/// What actually gets persisted: which palette, which mode, and the (possibly
/// user-color-picker-edited) light/dark instances for that palette — so an edit made while
/// looking at the dark variant survives switching to light and back, or an Auto-mode
/// day/night flip.
private struct ThemePersistence: Codable {
    var paletteName: String
    var mode: ThemeMode
    var lightTheme: AppTheme
    var darkTheme: AppTheme
}

final class ThemeStore: ObservableObject {
    /// The currently-rendered theme (light or dark instance of `paletteName`, per `mode`).
    /// Setting this directly (e.g. via a `ColorPicker` binding in Settings) edits whichever
    /// instance is currently active and persists it back into `lightTheme`/`darkTheme`.
    @Published var theme: AppTheme {
        didSet {
            if resolvedIsDark { darkTheme = theme } else { lightTheme = theme }
            save()
        }
    }

    @Published private(set) var paletteName: String
    @Published var mode: ThemeMode {
        didSet { theme = resolvedIsDark ? darkTheme : lightTheme }
    }

    /// Fed by `syncSystemAppearance()` (reads `@Environment(\.colorScheme)`) whenever a
    /// window's real system appearance is observable — only consulted when `mode == .auto`.
    @Published var systemIsDark: Bool {
        didSet {
            guard mode == .auto, oldValue != systemIsDark else { return }
            theme = systemIsDark ? darkTheme : lightTheme
        }
    }

    private var lightTheme: AppTheme
    private var darkTheme: AppTheme
    private let fileURL: URL

    private var resolvedIsDark: Bool {
        switch mode {
        case .light: return false
        case .dark: return true
        case .auto: return systemIsDark
        }
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Cazzy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("theme.json")

        let savedData = try? Data(contentsOf: fileURL)
        let initialSystemIsDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let loaded = Self.loadPersistedState(from: savedData)

        paletteName = loaded.paletteName
        mode = loaded.mode
        lightTheme = loaded.lightTheme
        darkTheme = loaded.darkTheme
        systemIsDark = initialSystemIsDark

        let startDark = loaded.mode == .dark || (loaded.mode == .auto && initialSystemIsDark)
        theme = startDark ? loaded.darkTheme : loaded.lightTheme
    }

    private static func loadPersistedState(from savedData: Data?) -> (paletteName: String, mode: ThemeMode, lightTheme: AppTheme, darkTheme: AppTheme) {
        if let savedData, let decoded = try? JSONDecoder().decode(ThemePersistence.self, from: savedData) {
            return (decoded.paletteName, decoded.mode, decoded.lightTheme, decoded.darkTheme)
        }
        // Pre-palette/mode format: one flat `AppTheme`, possibly one of the "<Name> Dark"
        // presets from the first dark-mode pass. Recover a palette name + mode from it, and
        // fill in whichever variant wasn't previously chosen from `AppTheme.palettes`.
        if let savedData, let legacy = try? JSONDecoder().decode(AppTheme.self, from: savedData) {
            if legacy.name.hasSuffix(" Dark") {
                let base = String(legacy.name.dropLast(" Dark".count))
                let light = AppTheme.palettes.first { $0.name == base }?.light ?? AppTheme.defaultPalette.light
                return (base, .dark, light, legacy)
            } else {
                let dark = AppTheme.palettes.first { $0.name == legacy.name }?.dark ?? AppTheme.defaultPalette.dark
                return (legacy.name, .light, legacy, dark)
            }
        }
        let palette = AppTheme.defaultPalette
        return (palette.name, .light, palette.light, palette.dark)
    }

    private func save() {
        let persistence = ThemePersistence(paletteName: paletteName, mode: mode, lightTheme: lightTheme, darkTheme: darkTheme)
        guard let data = try? JSONEncoder().encode(persistence) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Switches to a different palette, resetting both its light and dark instances to that
    /// palette's generated defaults (any manual color-picker edits to the previous palette
    /// are not carried over — same behavior as picking a preset always had).
    func selectPalette(_ name: String) {
        guard let palette = AppTheme.palettes.first(where: { $0.name == name }) else { return }
        paletteName = palette.name
        lightTheme = palette.light
        darkTheme = palette.dark
        theme = resolvedIsDark ? darkTheme : lightTheme
    }

    func resetToDefault() {
        mode = .light
        selectPalette(AppTheme.defaultPaletteName)
    }

    // MARK: - Colors

    var accent: Color { Color(hex: theme.accentHex) }
    var accentDeep: Color { Color(hex: theme.accentDeepHex) }
    var secondaryAccent: Color { Color(hex: theme.secondaryAccentHex) }
    var tertiaryAccent: Color { Color(hex: theme.tertiaryAccentHex) }

    var background: Color { Color(hex: theme.backgroundHex) }
    var cardBackground: Color { Color(hex: theme.cardBackgroundHex) }
    var editorBackground: Color { Color(hex: theme.editorBackgroundHex) }

    // Secondary/tertiary text used to be lighter tints of textPrimary, but that made
    // captions, timestamps, and placeholder-ish labels hard to read against some themes'
    // backgrounds (worst in the Protocols views, which lean on tertiary heavily). All
    // three now resolve to the same color so every label stays legible everywhere.
    var textPrimary: Color { Color(hex: theme.textPrimaryHex) }
    var textSecondary: Color { textPrimary }
    var textTertiary: Color { textPrimary }
    var divider: Color { Color(hex: theme.dividerHex) }

    var sidebar: Color { Color(hex: theme.sidebarHex) }

    func notebookAccent(_ index: Int) -> Color {
        let palette = [accent, secondaryAccent, tertiaryAccent, accentDeep]
        return palette[index % palette.count]
    }

    // MARK: - Fonts

    func displayFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        theme.displayFont.font(size: size, weight: weight)
    }

    func bodyFont(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        theme.bodyFont.font(size: size, weight: weight)
    }
}

/// Keeps `ThemeStore.systemIsDark` in sync with the Mac's real system appearance, for
/// resolving `.auto` mode. Reads `@Environment(\.colorScheme)` rather than polling
/// `NSApp.effectiveAppearance` because in `.auto` mode `CazzyApp` deliberately doesn't force
/// `.preferredColorScheme`, so this environment value already reflects the true OS setting —
/// forcing a scheme in explicit light/dark mode would otherwise just echo our own override
/// back here, but that's harmless since `systemIsDark` is only consulted while mode is `.auto`.
///
/// Takes `theme` as a direct `@ObservedObject` parameter rather than `@EnvironmentObject` —
/// during macOS's automatic window-restoration on launch (reopening windows left open from
/// the previous run), this modifier's `.onAppear` can fire before `.environmentObject(_:)`
/// has attached further up the same chain, and `@EnvironmentObject` crashes hard on a miss.
/// Passing the instance in directly sidesteps that lookup entirely.
private struct SystemAppearanceSync: ViewModifier {
    @ObservedObject var theme: ThemeStore
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .onAppear { theme.systemIsDark = colorScheme == .dark }
            .onChange(of: colorScheme) { newValue in
                theme.systemIsDark = newValue == .dark
            }
    }
}

extension View {
    func syncSystemAppearance(with theme: ThemeStore) -> some View {
        modifier(SystemAppearanceSync(theme: theme))
    }
}

struct SoftCardBackground: ViewModifier {
    @EnvironmentObject var theme: ThemeStore
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(theme.cardBackground)
                    .shadow(color: theme.accentDeep.opacity(0.08), radius: 8, x: 0, y: 3)
            )
    }
}

extension View {
    func softCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(SoftCardBackground(cornerRadius: cornerRadius))
    }
}

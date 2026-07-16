import SwiftUI
import Combine

final class ThemeStore: ObservableObject {
    @Published var theme: AppTheme {
        didSet { save() }
    }

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Cazzy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("theme.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppTheme.self, from: data) {
            theme = decoded
        } else {
            theme = AppTheme.default
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(theme) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func apply(_ preset: AppTheme) {
        theme = preset
    }

    // MARK: - Colors

    var accent: Color { Color(hex: theme.accentHex) }
    var accentDeep: Color { Color(hex: theme.accentDeepHex) }
    var secondaryAccent: Color { Color(hex: theme.secondaryAccentHex) }
    var tertiaryAccent: Color { Color(hex: theme.tertiaryAccentHex) }

    var background: Color { Color(hex: theme.backgroundHex) }
    var cardBackground: Color { Color(hex: theme.cardBackgroundHex) }
    var editorBackground: Color { Color(hex: theme.editorBackgroundHex) }

    var textPrimary: Color { Color(hex: theme.textPrimaryHex) }
    var textSecondary: Color { Color(hex: theme.textSecondaryHex) }
    var textTertiary: Color { Color(hex: theme.textTertiaryHex) }
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

import SwiftUI
import AppKit

/// A horizontal `ScrollView` replacement that forces the thin, auto-hiding "overlay" scroller
/// style on its `NSScrollView` — plain SwiftUI `ScrollView` has no way to opt out of the
/// chunky "legacy" scroller some users have set in System Settings, since that's controlled
/// per-`NSScrollView` instance, not by a SwiftUI modifier.
private struct ThinHorizontalScroll<Content: View>: NSViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = hostingView

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hostingView.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
        ])
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let hostingView = nsView.documentView as? NSHostingView<Content> else { return }
        hostingView.rootView = content
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var shortcuts: ShortcutStore
    @State private var showingShortcutManager = false

    var body: some View {
        Form {
            Section("Calendar") {
                Toggle("Automatically add scheduled experiments to Apple Calendar", isOn: Binding(
                    get: { store.syncToAppleCalendar },
                    set: { store.setSyncToAppleCalendar($0) }
                ))
                Text("New experiments are mirrored to your default calendar so they show up on your other devices. Individual experiments can still be added or removed from the calendar via their popover.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Appearance") {
                Picker("Mode", selection: $theme.mode) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                if theme.mode == .auto {
                    Text("Follows your Mac's system appearance (Light/Dark/Auto in System Settings → Appearance).")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Presets") {
                ThinHorizontalScroll {
                    HStack(spacing: 16) {
                        ForEach(AppTheme.palettes) { palette in
                            PresetSwatch(palette: palette, isSelected: theme.paletteName == palette.name) {
                                theme.selectPalette(palette.name)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .padding(.horizontal, 2)
                }
                .frame(height: 94)
            }

            Section("Colors") {
                ColorPicker("Accent", selection: binding(\.accentHex))
                ColorPicker("Secondary accent", selection: binding(\.secondaryAccentHex))
                ColorPicker("Background", selection: binding(\.backgroundHex))
                ColorPicker("Sidebar", selection: binding(\.sidebarHex))
                ColorPicker("Text", selection: binding(\.textPrimaryHex))
            }

            Section("Special Characters") {
                Button("Edit Special Character Shortcuts…") {
                    showingShortcutManager = true
                }
                Text("Customize which keystrokes insert symbols like µ, °, ∂, or Ω while writing notes. Defaults match the standard macOS Option-key combinations.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Fonts") {
                Picker("Headings", selection: $theme.theme.displayFont) {
                    ForEach(FontChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                Text("The quick brown fox jumps")
                    .font(theme.displayFont(17))
                    .foregroundStyle(theme.textPrimary)

                Picker("Body text", selection: $theme.theme.bodyFont) {
                    ForEach(FontChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                Text("The quick brown fox jumps over the lazy dog.")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textPrimary)
            }

            Section {
                Button("Reset to Default") {
                    theme.resetToDefault()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 620)
        .sheet(isPresented: $showingShortcutManager) {
            ShortcutManagerView()
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AppTheme, UInt32>) -> Binding<Color> {
        Binding<Color>(
            get: { Color(hex: theme.theme[keyPath: keyPath]) },
            set: { theme.theme[keyPath: keyPath] = $0.toHex() }
        )
    }
}

private struct PresetSwatch: View {
    let palette: ThemePalette
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Light half on top, dark half on bottom — the swatch now represents a
                    // palette (both variants), not one fixed instance, so it shows the pair.
                    HalfCircle(top: true).fill(Color(hex: palette.light.backgroundHex))
                    HalfCircle(top: false).fill(Color(hex: palette.dark.backgroundHex))
                    Circle()
                        .trim(from: 0, to: 0.35)
                        .stroke(Color(hex: palette.light.accentHex), lineWidth: 6)
                        .rotationEffect(.degrees(-90))
                    Circle()
                        .trim(from: 0, to: 0.35)
                        .stroke(Color(hex: palette.dark.accentHex), lineWidth: 6)
                        .rotationEffect(.degrees(90))
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color(hex: palette.light.accentDeepHex))
                            .padding(4)
                            .background(Circle().fill(Color(hex: palette.light.backgroundHex).opacity(0.85)))
                    }
                }
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color(hex: palette.light.accentDeepHex) : Color.clear, lineWidth: 2)
                        .frame(width: 47, height: 47)
                )
                Text(palette.name)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HalfCircle: Shape {
    let top: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        if top {
            path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        } else {
            path.addArc(center: center, radius: radius, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        }
        path.closeSubpath()
        return path
    }
}

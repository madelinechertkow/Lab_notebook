import SwiftUI
import AppKit

final class CazzyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Test-only: with a copy of the data (CAZZY_DATA_DIR) and CAZZY_RENDER_TEST_DIR set,
        // write every protocol's PDF + Markdown there and quit. Never runs on the real data.
        if CazzyDataLocation.testOverride != nil,
           let outPath = ProcessInfo.processInfo.environment["CAZZY_RENDER_TEST_DIR"] {
            let store = NoteStore()
            let out = URL(fileURLWithPath: outPath, isDirectory: true)
            for (index, protocolItem) in store.protocols.enumerated() {
                let base = out.appendingPathComponent("protocol-\(index)")
                try? ProtocolPDFRenderer.pdfData(for: protocolItem).write(to: base.appendingPathExtension("pdf"))
                try? protocolItem.markdownBody.write(to: base.appendingPathExtension("md"), atomically: true, encoding: .utf8)
                print("protocol-\(index): \(protocolItem.name) — used in \(store.usages(ofProtocol: protocolItem.id).count) entries")
            }
            print("recovery notice: \(store.dataRecoveryNotice ?? "none")")
            exit(0)
        }
        // Swift Package executables run directly (e.g. `swift run`, or the raw debug binary)
        // aren't launched via LaunchServices as a real .app bundle, so without this the
        // window renders but never becomes key and can't receive keystrokes. A properly
        // bundled/codesigned Cazzy.app is already activated normally by LaunchServices, so
        // this is skipped there.
        guard Bundle.main.bundleURL.pathExtension != "app" else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    // Deliberately no applicationShouldHandleReopen override: a properly bundled WindowGroup
    // app already reopens its last-closed window on a Dock click via AppKit's own default
    // handling. A custom override here (opening the window ourselves whenever
    // hasVisibleWindows read false) was running *in addition to* that default behavior rather
    // than replacing it, which is what was producing two windows from a single click.
}

/// Sends a standard Cocoa find action to whichever view is first responder — normally the
/// note editor's NSTextView. SwiftUI's Commands are closure-based and can't target an
/// Objective-C selector directly, so this goes through `NSApp.sendAction`, the same
/// mechanism a NIB-based "Find…" menu item uses (the action reads `tag` off `sender` to
/// know which `NSTextFinder.Action` to perform).
private func performTextFinderAction(_ action: NSTextFinder.Action) {
    let sender = NSMenuItem()
    sender.tag = action.rawValue
    NSApp.sendAction(#selector(NSTextView.performTextFinderAction(_:)), to: nil, from: sender)
}

@main
struct CazzyApp: App {
    @NSApplicationDelegateAdaptor(CazzyAppDelegate.self) private var appDelegate
    @StateObject private var store = NoteStore()
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var shortcutStore = ShortcutStore()
    @StateObject private var appleCalendar = AppleCalendarService()

    var body: some Scene {
        // The id lets the calendar window raise the main window when opening a note.
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .environmentObject(shortcutStore)
                .frame(minWidth: 900, minHeight: 600)
                .syncSystemAppearance(with: themeStore)
                .preferredColorScheme(forcedColorScheme)
                // Double-clicking a .cazzyprotocol file in Finder lands here (the file type is
                // registered in Packaging/Info.plist). Reuse the open main window for it.
                .onOpenURL { url in
                    guard url.isFileURL, url.pathExtension.lowercased() == ProtocolPackage.fileExtension else { return }
                    store.pendingImportProtocolURL = url
                }
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        .handlesExternalEvents(matching: ["*"])
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 700)
        .commands {
            // Universal undo: every data change funnels through NoteStore.save(), so these
            // replace the per-text-field undo with whole-app undo of notes, todos,
            // protocols, and scheduled experiments alike.
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { store.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Redo") { store.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
            }
            // Find within the currently-open entry — routes to AppKit's own NSTextFinder on
            // whichever NSTextView is focused (see `usesFindBar` in FormattingTextEditor),
            // the same native find bar TextEdit and Xcode use, so highlighting, match count,
            // and Next/Previous all come for free.
            CommandGroup(after: .textEditing) {
                Button("Find") { performTextFinderAction(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") { performTextFinderAction(.nextMatch) }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { performTextFinderAction(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            // App-wide text zoom, mirroring the ⌘+/⌘- convention Safari, Mail, etc. use.
            // Declared once here (rather than per-window) since a single process has one
            // shared menu bar — the same reason Undo/Redo above already reaches every window.
            CommandGroup(after: .toolbar) {
                Button("Increase Font Size") { themeStore.increaseFontScale() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Decrease Font Size") { themeStore.decreaseFontScale() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { themeStore.resetFontScale() }
                    .keyboardShortcut("0", modifiers: .command)
            }
        }

        WindowGroup(id: "todo") {
            TodoListView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .frame(minWidth: 300, minHeight: 360)
                .syncSystemAppearance(with: themeStore)
                .preferredColorScheme(forcedColorScheme)
        }
        .defaultSize(width: 360, height: 480)
        .handlesExternalEvents(matching: [])

        WindowGroup(id: "calendar") {
            CalendarView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .environmentObject(appleCalendar)
                .frame(minWidth: 900, minHeight: 560)
                .syncSystemAppearance(with: themeStore)
                .preferredColorScheme(forcedColorScheme)
        }
        .defaultSize(width: 1050, height: 720)
        .handlesExternalEvents(matching: [])

        Settings {
            SettingsView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .environmentObject(shortcutStore)
                .environmentObject(appleCalendar)
        }
    }

    /// `nil` in `.auto` mode so the window naturally follows the real system appearance
    /// (which is exactly what `.auto` should do); an explicit override otherwise so native
    /// chrome matches the user's chosen light/dark theme regardless of the system setting.
    private var forcedColorScheme: ColorScheme? {
        themeStore.mode == .auto ? nil : (themeStore.theme.isDark ? .dark : .light)
    }
}

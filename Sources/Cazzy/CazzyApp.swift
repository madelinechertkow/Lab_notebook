import SwiftUI
import AppKit

final class CazzyAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Swift Package executables aren't launched via LaunchServices as a real .app bundle,
        // so without this the window renders but never becomes key and can't receive keystrokes.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct CazzyApp: App {
    @NSApplicationDelegateAdaptor(CazzyAppDelegate.self) private var appDelegate
    @StateObject private var store = NoteStore()
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var appleCalendar = AppleCalendarService()

    var body: some Scene {
        // The id lets the calendar window raise the main window when opening a note.
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .frame(minWidth: 900, minHeight: 600)
        }
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
        }

        WindowGroup(id: "todo") {
            TodoListView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .frame(minWidth: 300, minHeight: 360)
        }
        .defaultSize(width: 360, height: 480)

        WindowGroup(id: "calendar") {
            CalendarView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .environmentObject(appleCalendar)
                .frame(minWidth: 900, minHeight: 560)
        }
        .defaultSize(width: 1050, height: 720)

        Settings {
            SettingsView()
                .environmentObject(themeStore)
        }
    }
}

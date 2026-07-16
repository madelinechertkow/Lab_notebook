import SwiftUI

@main
struct CazzyApp: App {
    @StateObject private var store = NoteStore()
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 700)

        WindowGroup(id: "todo") {
            TodoListView()
                .environmentObject(store)
                .environmentObject(themeStore)
                .frame(minWidth: 300, minHeight: 360)
        }
        .defaultSize(width: 360, height: 480)

        Settings {
            SettingsView()
                .environmentObject(themeStore)
        }
    }
}

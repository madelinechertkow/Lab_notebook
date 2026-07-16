import SwiftUI

@main
struct ZycasApp: App {
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

        Settings {
            SettingsView()
                .environmentObject(themeStore)
        }
    }
}

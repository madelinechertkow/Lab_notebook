import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @State private var sidebarSelection: SidebarItem? = .all
    @State private var selectedNoteID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } content: {
            NoteListView(sidebarSelection: sidebarSelection, selectedNoteID: $selectedNoteID)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300)
        } detail: {
            if let selectedNoteID, store.notes.contains(where: { $0.id == selectedNoteID }) {
                EditorView(noteID: selectedNoteID)
            } else {
                EmptyStateView()
            }
        }
        .tint(theme.accentDeep)
        .onChange(of: sidebarSelection) { _ in
            selectedNoteID = nil
        }
        .onChange(of: store.labModeFilter) { _ in
            if case .notebook(let id) = sidebarSelection,
               !store.visibleNotebooks().contains(where: { $0.id == id }) {
                sidebarSelection = .all
            }
        }
    }
}

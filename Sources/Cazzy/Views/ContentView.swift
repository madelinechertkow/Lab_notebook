import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @State private var sidebarSelection: SidebarItem? = .all
    @State private var selectedNoteID: UUID?
    @State private var selectedProtocolID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } content: {
            if sidebarSelection == .protocols {
                ProtocolListView(selectedProtocolID: $selectedProtocolID)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            } else {
                NoteListView(sidebarSelection: sidebarSelection, selectedNoteID: $selectedNoteID)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            }
        } detail: {
            if sidebarSelection == .protocols {
                if let selectedProtocolID, store.protocols.contains(where: { $0.id == selectedProtocolID }) {
                    ProtocolEditorView(protocolID: selectedProtocolID)
                } else {
                    EmptyStateView()
                }
            } else if let selectedNoteID, store.notes.contains(where: { $0.id == selectedNoteID }) {
                EditorView(noteID: selectedNoteID)
            } else {
                EmptyStateView()
            }
        }
        .tint(theme.accentDeep)
        .onChange(of: sidebarSelection) { _ in
            selectedNoteID = nil
            selectedProtocolID = nil
        }
        .onChange(of: store.labModeFilter) { _ in
            if case .notebook(let id) = sidebarSelection,
               !store.visibleNotebooks().contains(where: { $0.id == id }) {
                sidebarSelection = .all
            }
        }
    }
}

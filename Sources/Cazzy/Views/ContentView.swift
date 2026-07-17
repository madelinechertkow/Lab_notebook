import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @State private var sidebarSelection: SidebarItem? = .all
    @State private var selectedNoteID: UUID?
    @State private var selectedProtocolID: UUID?
    @State private var selectedPlateMapID: UUID?
    @State private var selectedLadderID: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $sidebarSelection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } content: {
            if sidebarSelection == .protocols {
                ProtocolListView(selectedProtocolID: $selectedProtocolID)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            } else if sidebarSelection == .plateMaps {
                PlateMapListView(selectedPlateMapID: $selectedPlateMapID)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            } else if sidebarSelection == .gelMaps {
                GelLadderListView(selectedLadderID: $selectedLadderID)
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
            } else if sidebarSelection == .plateMaps {
                if let selectedPlateMapID, store.plateMapTemplates.contains(where: { $0.id == selectedPlateMapID }) {
                    PlateMapEditorView(plateMapID: selectedPlateMapID)
                } else {
                    EmptyStateView()
                }
            } else if sidebarSelection == .gelMaps {
                if let selectedLadderID, store.gelLadderPresets.contains(where: { $0.id == selectedLadderID }) {
                    GelLadderEditorView(ladderID: selectedLadderID)
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
            selectedPlateMapID = nil
            selectedLadderID = nil
        }
        .onChange(of: store.labModeFilter) { _ in
            if case .notebook(let id) = sidebarSelection,
               !store.visibleNotebooks().contains(where: { $0.id == id }) {
                sidebarSelection = .all
            }
        }
        .onReceive(store.$pendingOpenNoteID) { noteID in
            // The calendar window asks the main window to show a note this way.
            guard let noteID, let note = store.notes.first(where: { $0.id == noteID }) else { return }
            store.pendingOpenNoteID = nil
            sidebarSelection = store.visibleNotebooks().contains(where: { $0.id == note.notebookID })
                ? .notebook(note.notebookID)
                : .all
            // The selection onChange above clears the note id, so set it after this turn.
            DispatchQueue.main.async {
                selectedNoteID = noteID
            }
        }
    }
}

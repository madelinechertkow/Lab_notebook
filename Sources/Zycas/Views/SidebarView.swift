import SwiftUI
import AppKit

enum SidebarItem: Hashable {
    case all
    case notebook(UUID)
}

func openZycasPreferences() {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}

struct SidebarView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Section {
                Label {
                    HStack {
                        Text("All Notes")
                        Spacer()
                        Text("\(store.notes(in: nil).count)")
                            .font(theme.bodyFont(11))
                            .foregroundStyle(theme.textSecondary)
                    }
                } icon: {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(theme.accentDeep)
                }
                .tag(SidebarItem.all)
            }

            Section("Notebooks") {
                ForEach(Array(store.visibleNotebooks().enumerated()), id: \.element.id) { index, notebook in
                    Label {
                        HStack {
                            Text(notebook.name)
                            Spacer()
                            Text("\(store.notes(in: notebook.id).count)")
                                .font(theme.bodyFont(11))
                                .foregroundStyle(theme.textSecondary)
                        }
                    } icon: {
                        Image(systemName: notebook.symbol)
                            .foregroundStyle(theme.notebookAccent(index))
                    }
                    .tag(SidebarItem.notebook(notebook.id))
                }
            }

            if !store.allTags().isEmpty {
                Section("Tags") {
                    ForEach(store.allTags(), id: \.self) { tag in
                        Label {
                            Text(tag)
                                .font(theme.bodyFont(12))
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(theme.secondaryAccent)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.sidebarGradient)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: store.labModeFilter.symbol)
                        .foregroundStyle(theme.accentDeep)
                    Text("Zycas")
                        .font(theme.displayFont(20))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Button {
                        openZycasPreferences()
                    } label: {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .help("Customize appearance")
                }

                Picker("", selection: Binding(
                    get: { store.labModeFilter },
                    set: { store.setLabModeFilter($0) }
                )) {
                    ForEach(LabModeFilter.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

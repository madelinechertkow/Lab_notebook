import SwiftUI
import AppKit

enum SidebarItem: Hashable {
    case all
    case notebook(UUID)
}

func openCazzyPreferences() {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
}

struct SidebarView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Binding var selection: SidebarItem?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        List(selection: $selection) {
            Section {
                Label {
                    HStack {
                        Text("All Notes")
                            .font(theme.bodyFont(13, weight: .medium))
                            .foregroundStyle(theme.textPrimary)
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

                Button {
                    openWindow(id: "todo")
                } label: {
                    Label {
                        HStack {
                            Text("To-Do")
                                .font(theme.bodyFont(13, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            let openCount = store.todos.filter { !$0.isDone }.count
                            if openCount > 0 {
                                Text("\(openCount)")
                                    .font(theme.bodyFont(11))
                                    .foregroundStyle(theme.textSecondary)
                            }
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                    } icon: {
                        Image(systemName: "checklist")
                            .foregroundStyle(theme.tertiaryAccent)
                    }
                }
                .buttonStyle(.plain)
            }

            Section {
                ForEach(Array(store.visibleNotebooks().enumerated()), id: \.element.id) { index, notebook in
                    Label {
                        HStack {
                            Text(notebook.name)
                                .font(theme.bodyFont(13, weight: .medium))
                                .foregroundStyle(theme.textPrimary)
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
            } header: {
                Text("Notebooks")
                    .foregroundStyle(theme.textSecondary)
            }

            if !store.allTags().isEmpty {
                Section {
                    ForEach(store.allTags(), id: \.self) { tag in
                        Label {
                            Text(tag)
                                .font(theme.bodyFont(12))
                                .foregroundStyle(theme.textPrimary)
                        } icon: {
                            Image(systemName: "tag.fill")
                                .foregroundStyle(theme.secondaryAccent)
                        }
                    }
                } header: {
                    Text("Tags")
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(theme.sidebar)
        .safeAreaInset(edge: .top) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: store.labModeFilter.symbol)
                        .foregroundStyle(theme.accentDeep)
                    Text("Cazzy")
                        .font(theme.displayFont(20))
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Button {
                        openCazzyPreferences()
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

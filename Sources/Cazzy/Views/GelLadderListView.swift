import SwiftUI

struct GelLadderListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Binding var selectedLadderID: UUID?
    @State private var searchText: String = ""

    private var filteredPresets: [GelLadderPreset] {
        let base = store.gelLadderPresets.sorted { $0.updatedAt > $1.updatedAt }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(query)
                || $0.tags.contains(where: { $0.lowercased().contains(query) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Gel Ladders")
                    .font(theme.displayFont(20))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button(action: createLadder) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accentDeep)
                .help("New ladder preset")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12))
                TextField("Search ladders", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(13))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cardBackground.opacity(0.6)))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().overlay(theme.divider)

            if filteredPresets.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 26))
                        .foregroundStyle(theme.textTertiary)
                    Text("No ladder presets yet")
                        .font(theme.bodyFont(13))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else {
                List(selection: $selectedLadderID) {
                    ForEach(filteredPresets) { preset in
                        GelLadderRow(preset: preset)
                            .tag(preset.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deletePresets)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background)
    }

    private func createLadder() {
        let preset = store.createLadderPreset()
        selectedLadderID = preset.id
    }

    private func deletePresets(at offsets: IndexSet) {
        let presets = filteredPresets
        for index in offsets {
            let preset = presets[index]
            if selectedLadderID == preset.id { selectedLadderID = nil }
            store.deleteLadderPreset(preset)
        }
    }
}

private struct GelLadderRow: View {
    @EnvironmentObject var theme: ThemeStore
    let preset: GelLadderPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(preset.name.isEmpty ? "Untitled Ladder" : preset.name)
                .font(theme.bodyFont(14, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
            Text(preset.bands.isEmpty ? "No bands yet" : preset.bands.map(\.sizeLabel).joined(separator: ", "))
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

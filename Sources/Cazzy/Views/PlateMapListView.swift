import SwiftUI

struct PlateMapListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Binding var selectedPlateMapID: UUID?
    @State private var searchText: String = ""
    @State private var showingNewTemplateSheet = false

    private var filteredTemplates: [PlateMapTemplate] {
        let base = store.plateMapTemplates.sorted { $0.updatedAt > $1.updatedAt }
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
                Text("Plate Maps")
                    .font(theme.displayFont(20))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button {
                    showingNewTemplateSheet = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accentDeep)
                .help("New plate map template")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12))
                TextField("Search plate maps", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(13))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.6)))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().overlay(theme.divider)

            if filteredTemplates.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 26))
                        .foregroundStyle(theme.textTertiary)
                    Text("No plate map templates yet")
                        .font(theme.bodyFont(13))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else {
                List(selection: $selectedPlateMapID) {
                    ForEach(filteredTemplates) { template in
                        PlateMapRow(template: template)
                            .tag(template.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteTemplates)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background)
        .sheet(isPresented: $showingNewTemplateSheet) {
            NewPlateMapSheet { name, size in
                let template = store.createPlateMapTemplate(name: name, size: size)
                selectedPlateMapID = template.id
            }
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        let templates = filteredTemplates
        for index in offsets {
            let template = templates[index]
            if selectedPlateMapID == template.id { selectedPlateMapID = nil }
            store.deletePlateMapTemplate(template)
        }
    }
}

private struct PlateMapRow: View {
    @EnvironmentObject var theme: ThemeStore
    let template: PlateMapTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(template.name.isEmpty ? "Untitled Plate Map" : template.name)
                    .font(theme.bodyFont(14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(template.size.label)
                    .font(theme.bodyFont(10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }

            HStack(spacing: 6) {
                Text(template.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                let filledCount = template.wells.values.filter { !$0.isEmpty }.count
                if filledCount > 0 {
                    Text("\(filledCount) wells filled")
                        .font(theme.bodyFont(10))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NewPlateMapSheet: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var size: PlateSize = .wells96
    var onCreate: (String, PlateSize) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Plate Map Template")
                .font(theme.displayFont(15))
                .foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: 5) {
                Text("Name").font(theme.bodyFont(11)).foregroundStyle(theme.textSecondary)
                TextField("e.g. Standard qPCR Layout", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Size").font(theme.bodyFont(11)).foregroundStyle(theme.textSecondary)
                Picker("", selection: $size) {
                    ForEach(PlateSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    onCreate(trimmed.isEmpty ? "Untitled Plate Map" : trimmed, size)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(theme.background)
    }
}

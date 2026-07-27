import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProtocolListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Binding var selectedProtocolID: UUID?
    @State private var searchText: String = ""
    @State private var mergeContext: MergeContext?
    @State private var importErrorMessage: String?
    @State private var infoBanner: String?

    private struct MergeContext: Identifiable {
        let id: UUID
        let local: LabProtocol
        let imported: LabProtocol
    }

    private var filteredProtocols: [LabProtocol] {
        let base = store.protocols.sorted { $0.updatedAt > $1.updatedAt }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.name.lowercased().contains(query)
                || $0.purpose.lowercased().contains(query)
                || $0.tags.contains(where: { $0.lowercased().contains(query) })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let infoBanner {
                Text(infoBanner)
                    .font(theme.bodyFont(11, weight: .medium))
                    .foregroundStyle(theme.accentDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(theme.secondaryAccent.opacity(0.18))
            }

            HStack {
                Text("Protocols")
                    .font(theme.displayFont(20))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button(action: importProtocolFile) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
                .help("Import a shared protocol")

                Button(action: createProtocol) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accentDeep)
                .help("New protocol")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.textSecondary)
                    .font(.system(size: 12))
                TextField("Search protocols", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(13))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.cardBackground.opacity(0.6)))
            .padding(.horizontal, 16)
            .padding(.bottom, 10)

            Divider().overlay(theme.divider)

            if filteredProtocols.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "list.clipboard")
                        .font(.system(size: 26))
                        .foregroundStyle(theme.textTertiary)
                    Text("No protocols yet")
                        .font(theme.bodyFont(13))
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            } else {
                List(selection: $selectedProtocolID) {
                    ForEach(filteredProtocols) { protocolItem in
                        ProtocolRow(protocolItem: protocolItem)
                            .tag(protocolItem.id)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button(role: .destructive) {
                                    presentDeleteConfirmation(for: protocolItem)
                                } label: {
                                    Label("Delete Protocol…", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete(perform: deleteProtocols)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background)
        .sheet(item: $mergeContext) { context in
            ProtocolMergeView(
                local: context.local,
                imported: context.imported,
                onApply: { mergedSnapshot in
                    applyMerge(mergedSnapshot, protocolID: context.local.id)
                },
                onCancel: {
                    mergeContext = nil
                }
            )
        }
        .alert(
            "Couldn't import protocol",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // NSAlert instead of SwiftUI's .alert(item:): a confirmation triggered from inside a
    // .contextMenu action doesn't reliably present as a SwiftUI alert on macOS — the menu's
    // own dismissal races with the alert's presentation. Driving it through AppKit directly
    // sidesteps that (see the identical fix in SidebarView.swift and NoteListView.swift).
    private func presentDeleteConfirmation(for protocolItem: LabProtocol) {
        let alert = NSAlert()
        alert.messageText = "Delete \"\(protocolItem.name.isEmpty ? "Untitled Protocol" : protocolItem.name)\"?"
        alert.informativeText = protocolItem.versions.isEmpty
            ? "You can undo this with ⌘Z."
            : "This will also delete all \(protocolItem.versions.count) saved version\(protocolItem.versions.count == 1 ? "" : "s"). You can undo this with ⌘Z."
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "Delete")
        deleteButton.hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if selectedProtocolID == protocolItem.id {
            selectedProtocolID = nil
        }
        store.deleteProtocol(protocolItem)
    }

    private func createProtocol() {
        let protocolItem = store.createProtocol()
        selectedProtocolID = protocolItem.id
    }

    private func deleteProtocols(at offsets: IndexSet) {
        let current = filteredProtocols
        for index in offsets {
            if selectedProtocolID == current[index].id {
                selectedProtocolID = nil
            }
            store.deleteProtocol(current[index])
        }
    }

    private func importProtocolFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: ProtocolPackage.fileExtension) ?? .json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let result = try store.importProtocol(from: url)
                switch result {
                case .newProtocol(let imported):
                    selectedProtocolID = imported.id
                case .conflict(let local, let imported):
                    let diff = ProtocolMerge.diff(local: local.draftSnapshot, imported: imported.draftSnapshot)
                    if diff.hasConflicts {
                        mergeContext = MergeContext(id: local.id, local: local, imported: imported)
                    } else {
                        // Fast-forward: only unchanged items and additions, nothing to adjudicate.
                        let merged = ProtocolMerge.resolve(
                            diff,
                            nameChoice: .local,
                            purposeChoice: .local,
                            reagentChoices: [:],
                            includedReagentIDs: diff.defaultIncludedReagentIDs,
                            stepChoices: [:],
                            includedStepIDs: diff.defaultIncludedStepIDs
                        )
                        applyMerge(merged, protocolID: local.id)
                        showBanner("Merged \"\(local.name)\" automatically — no conflicting edits found.")
                    }
                }
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func applyMerge(_ snapshot: ProtocolVersionSnapshot, protocolID: UUID) {
        guard var protocolItem = store.protocols.first(where: { $0.id == protocolID }) else {
            mergeContext = nil
            return
        }
        protocolItem.name = snapshot.name
        protocolItem.purpose = snapshot.purpose
        protocolItem.reagents = snapshot.reagents
        protocolItem.steps = snapshot.steps
        protocolItem.tags = snapshot.tags
        store.updateProtocolDraft(protocolItem)
        selectedProtocolID = protocolID
        mergeContext = nil
    }

    private func showBanner(_ message: String) {
        infoBanner = message
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if infoBanner == message { infoBanner = nil }
        }
    }
}

private struct ProtocolRow: View {
    @EnvironmentObject var theme: ThemeStore
    let protocolItem: LabProtocol

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(protocolItem.name.isEmpty ? "Untitled Protocol" : protocolItem.name)
                    .font(theme.bodyFont(14, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if protocolItem.currentVersionNumber > 0 {
                    Text("v\(protocolItem.currentVersionNumber)")
                        .font(theme.bodyFont(10, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                }
            }

            if !protocolItem.purpose.isEmpty {
                Text(protocolItem.purpose)
                    .font(theme.bodyFont(12))
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                Text(protocolItem.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                Text("\(protocolItem.steps.count) steps")
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                ForEach(protocolItem.tags.prefix(2), id: \.self) { tag in
                    Text(tag)
                        .font(theme.bodyFont(9, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.secondaryAccent.opacity(0.25)))
                        .foregroundStyle(theme.accentDeep)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .softCard(cornerRadius: 12)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }
}

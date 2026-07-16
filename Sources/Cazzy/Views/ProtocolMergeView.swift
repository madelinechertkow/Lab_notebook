import SwiftUI

/// Sheet for reconciling two diverged versions of the same protocol (matched by id during
/// import). Presented only when `ProtocolMerge.Result.hasConflicts` is true — a pure
/// fast-forward (only unchanged items and additions) is applied automatically by the caller.
struct ProtocolMergeView: View {
    @EnvironmentObject var theme: ThemeStore
    let local: LabProtocol
    let imported: LabProtocol
    let onApply: (ProtocolVersionSnapshot) -> Void
    let onCancel: () -> Void

    @State private var result: ProtocolMerge.Result
    @State private var nameChoice: MergeChoice = .local
    @State private var purposeChoice: MergeChoice = .local
    @State private var reagentChoices: [UUID: MergeChoice] = [:]
    @State private var stepChoices: [UUID: MergeChoice] = [:]
    @State private var includedReagentIDs: Set<UUID>
    @State private var includedStepIDs: Set<UUID>

    init(local: LabProtocol, imported: LabProtocol, onApply: @escaping (ProtocolVersionSnapshot) -> Void, onCancel: @escaping () -> Void) {
        self.local = local
        self.imported = imported
        self.onApply = onApply
        self.onCancel = onCancel
        let diffResult = ProtocolMerge.diff(local: local.draftSnapshot, imported: imported.draftSnapshot)
        _result = State(initialValue: diffResult)
        _includedReagentIDs = State(initialValue: diffResult.defaultIncludedReagentIDs)
        _includedStepIDs = State(initialValue: diffResult.defaultIncludedStepIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Merge Protocol Versions")
                    .font(theme.displayFont(18))
                    .foregroundStyle(theme.textPrimary)
                Text("\"\(local.name.isEmpty ? "Untitled Protocol" : local.name)\" was edited separately on both sides. Resolve the differences below.")
                    .font(theme.bodyFont(12))
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider().overlay(theme.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let nameConflict = result.nameConflict {
                        conflictField(title: "Name", local: nameConflict.local, imported: nameConflict.imported, choice: $nameChoice)
                    }
                    if let purposeConflict = result.purposeConflict {
                        conflictField(title: "Purpose", local: purposeConflict.local, imported: purposeConflict.imported, choice: $purposeChoice)
                    }
                    itemSection(
                        title: "Reagents",
                        diffs: result.reagentDiffs,
                        choices: $reagentChoices,
                        included: $includedReagentIDs,
                        label: { "\($0.name) — \($0.amount) \($0.unit)".trimmingCharacters(in: .whitespaces) }
                    )
                    itemSection(
                        title: "Steps",
                        diffs: result.stepDiffs,
                        choices: $stepChoices,
                        included: $includedStepIDs,
                        label: { $0.text }
                    )
                }
                .padding(20)
            }

            Divider().overlay(theme.divider)

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                Button("Apply Merge") {
                    let merged = ProtocolMerge.resolve(
                        result,
                        nameChoice: nameChoice,
                        purposeChoice: purposeChoice,
                        reagentChoices: reagentChoices,
                        includedReagentIDs: includedReagentIDs,
                        stepChoices: stepChoices,
                        includedStepIDs: includedStepIDs
                    )
                    onApply(merged)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentDeep)
            }
            .padding(16)
        }
        .frame(width: 560, height: 620)
        .background(theme.background)
    }

    private func conflictField(title: String, local: String, imported: String, choice: Binding<MergeChoice>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(theme.bodyFont(13, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Picker("", selection: choice) {
                Text("Keep mine: \(local)").tag(MergeChoice.local)
                Text("Use imported: \(imported)").tag(MergeChoice.imported)
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private func itemSection<T: Identifiable & Equatable>(
        title: String,
        diffs: [ProtocolMerge.ItemDiff<T>],
        choices: Binding<[UUID: MergeChoice]>,
        included: Binding<Set<UUID>>,
        label: @escaping (T) -> String
    ) -> some View where T.ID == UUID {
        if !diffs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(theme.bodyFont(13, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                ForEach(diffs, id: \.id) { diff in
                    mergeItemRow(diff: diff, choices: choices, included: included, label: label)
                }
            }
        }
    }

    @ViewBuilder
    private func mergeItemRow<T: Identifiable & Equatable>(
        diff: ProtocolMerge.ItemDiff<T>,
        choices: Binding<[UUID: MergeChoice]>,
        included: Binding<Set<UUID>>,
        label: @escaping (T) -> String
    ) -> some View where T.ID == UUID {
        switch diff {
        case .unchanged(let item):
            HStack {
                Text(label(item))
                    .font(theme.bodyFont(12))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                statusTag("unchanged")
            }
            .padding(8)
            .softCard(cornerRadius: 8)

        case .localOnly(let item):
            HStack {
                Toggle(isOn: includeBinding(item.id, in: included)) {
                    Text(label(item))
                        .font(theme.bodyFont(12))
                        .foregroundStyle(theme.textPrimary)
                }
                Spacer()
                statusTag("only in mine")
            }
            .padding(8)
            .softCard(cornerRadius: 8)

        case .importedOnly(let item):
            HStack {
                Toggle(isOn: includeBinding(item.id, in: included)) {
                    Text(label(item))
                        .font(theme.bodyFont(12))
                        .foregroundStyle(theme.textPrimary)
                }
                Spacer()
                statusTag("only in imported")
            }
            .padding(8)
            .softCard(cornerRadius: 8)

        case .conflict(let localItem, let importedItem):
            VStack(alignment: .leading, spacing: 6) {
                statusTag("conflict")
                Picker("", selection: choiceBinding(localItem.id, in: choices)) {
                    Text("Mine: \(label(localItem))").tag(MergeChoice.local)
                    Text("Imported: \(label(importedItem))").tag(MergeChoice.imported)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            .padding(8)
            .softCard(cornerRadius: 8)
        }
    }

    private func statusTag(_ text: String) -> some View {
        Text(text)
            .font(theme.bodyFont(9, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(theme.secondaryAccent.opacity(0.25)))
            .foregroundStyle(theme.accentDeep)
    }

    private func includeBinding(_ id: UUID, in set: Binding<Set<UUID>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(id) },
            set: { newValue in
                if newValue { set.wrappedValue.insert(id) } else { set.wrappedValue.remove(id) }
            }
        )
    }

    private func choiceBinding(_ id: UUID, in dict: Binding<[UUID: MergeChoice]>) -> Binding<MergeChoice> {
        Binding(
            get: { dict.wrappedValue[id] ?? .local },
            set: { dict.wrappedValue[id] = $0 }
        )
    }
}

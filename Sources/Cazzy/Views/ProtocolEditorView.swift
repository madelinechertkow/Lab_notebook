import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ProtocolEditorView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let protocolID: UUID

    @State private var name: String = ""
    @State private var purpose: String = ""
    @State private var reagents: [Reagent] = []
    @State private var steps: [ProtocolStep] = []
    @State private var tags: [String] = []
    @State private var newTag: String = ""
    @State private var manualTotalMinutes: Int?
    @Environment(\.openWindow) private var openWindow

    @State private var showingSaveVersionPopover = false
    @State private var changeNoteDraft = ""
    @State private var showingVersionHistory = false
    @State private var versionPendingRestore: ProtocolVersion?
    @State private var exportErrorMessage: String?
    @State private var draggedStepID: UUID?

    private var currentProtocol: LabProtocol? {
        store.protocols.first(where: { $0.id == protocolID })
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.divider).padding(.top, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    purposeSection
                    reagentsSection
                    stepsSection
                    if showingVersionHistory {
                        versionHistorySection
                    }
                }
                .padding(20)
            }
        }
        .background(theme.editorBackground)
        .onAppear(perform: loadFromProtocol)
        .onChange(of: protocolID) { _ in loadFromProtocol() }
        .onChange(of: store.undoTick) { _ in loadFromProtocol() }
        .alert(
            "Couldn't export protocol",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: {
            Text(exportErrorMessage ?? "")
        }
        .alert(item: $versionPendingRestore) { version in
            Alert(
                title: Text("Restore v\(version.versionNumber)?"),
                message: Text("This replaces the current draft with v\(version.versionNumber). Your version history is kept either way — nothing is deleted."),
                primaryButton: .default(Text("Restore")) {
                    store.restoreVersion(version, in: protocolID)
                    loadFromProtocol()
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                TextField("Untitled Protocol", text: $name)
                    .textFieldStyle(.plain)
                    .font(theme.displayFont(24))
                    .foregroundStyle(theme.textPrimary)
                    .onChange(of: name) { _ in persist() }
                Spacer()
                if let currentProtocol, currentProtocol.currentVersionNumber > 0 {
                    Text("v\(currentProtocol.currentVersionNumber)")
                        .font(theme.bodyFont(12, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.top, 6)
                }
            }

            TagRow(tags: $tags, newTag: $newTag, onCommit: persist)

            HStack(spacing: 10) {
                actionButton("clock.arrow.circlepath", "Save New Version") {
                    changeNoteDraft = ""
                    showingSaveVersionPopover = true
                }
                .popover(isPresented: $showingSaveVersionPopover) {
                    saveVersionPopover
                }

                actionButton("archivebox", showingVersionHistory ? "Hide History" : "Version History") {
                    showingVersionHistory.toggle()
                }

                actionButton("calendar.badge.plus", "Schedule…") {
                    store.pendingScheduleProtocolID = protocolID
                    openWindow(id: "calendar")
                }

                Spacer()

                actionButton("printer", "Print") {
                    if let currentProtocol {
                        ProtocolPrinter.print(currentProtocol)
                    }
                }

                actionButton("square.and.arrow.up", "Export…", action: exportProtocolFile)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func actionButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                Text(label)
                    .font(theme.bodyFont(11, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.white.opacity(0.5)))
    }

    private var saveVersionPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Save New Version")
                .font(theme.bodyFont(13, weight: .semibold))
                .foregroundStyle(theme.textPrimary)
            TextField("What changed? (optional)", text: $changeNoteDraft)
                .textFieldStyle(.roundedBorder)
                .frame(width: 240)
            HStack {
                Spacer()
                Button("Save") {
                    store.saveNewVersion(for: protocolID, changeNote: changeNoteDraft)
                    showingSaveVersionPopover = false
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accentDeep)
            }
        }
        .padding(16)
    }

    // MARK: - Purpose

    private var purposeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Purpose", systemImage: "text.alignleft")
            TextEditor(text: Binding(
                get: { purpose },
                set: { purpose = $0; persist() }
            ))
            .font(theme.bodyFont(13))
            .foregroundStyle(theme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 50, maxHeight: 90)
            .padding(8)
            .softCard(cornerRadius: 10)
        }
    }

    // MARK: - Reagents

    private var reagentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("Materials & Reagents", systemImage: "cross.vial")
                Spacer()
                addButton { addReagent() }
            }
            if reagents.isEmpty {
                emptyRow("No reagents yet")
            } else {
                ForEach(reagents.indices, id: \.self) { index in
                    ReagentRow(reagent: $reagents[index]) {
                        removeReagent(at: index)
                    }
                }
            }
        }
        .onChange(of: reagents) { _ in persist() }
    }

    private func addReagent() {
        reagents.append(Reagent(name: ""))
        persist()
    }

    private func removeReagent(at index: Int) {
        guard reagents.indices.contains(index) else { return }
        reagents.remove(at: index)
        persist()
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("Steps", systemImage: "list.number")
                Spacer()
                Menu {
                    Button("Add Step") { addStep(kind: .step) }
                    Button("Add Note") { addStep(kind: .note) }
                    Button("Add Warning") { addStep(kind: .warning) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accentDeep)
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            if steps.isEmpty {
                emptyRow("No steps yet")
            } else {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    // Only actual procedure steps get a number — notes/warnings are callouts.
                    let ordinal = steps[...index].filter { $0.kind == .step }.count
                    StepRow(
                        step: $steps[index],
                        number: ordinal,
                        draggedStepID: $draggedStepID,
                        onDelete: { removeStep(at: index) }
                    )
                    .onDrop(of: [.text], delegate: StepDropDelegate(targetID: step.id, steps: $steps, draggedStepID: $draggedStepID, onFinished: persist))
                }
            }
            totalTimeRow
        }
        .onChange(of: steps) { _ in
            // While a drag is live, reordering is purely in-memory + animated; writing to disk
            // on every row it passes over is what made dragging feel choppy. The drop delegate
            // calls `persist()` itself exactly once when the drag actually ends.
            guard draggedStepID == nil else { return }
            persist()
        }
    }

    /// Shows the auto-summed step time and an optional manual override used when the
    /// protocol is scheduled on the calendar. `manualTotalMinutes` is canonical; the
    /// hours/minutes fields are two views onto it (same pattern as StepRow durations).
    private var totalTimeRow: some View {
        let stepSum = steps.filter { $0.kind == .step }.compactMap(\.durationMinutes).reduce(0, +)
        return HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 11))
                .foregroundStyle(theme.accentDeep)
            Text(stepSum > 0 ? "Total from steps: \(Self.formatMinutes(stepSum))" : "No step timings yet")
                .font(theme.bodyFont(12))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            Text("Override for scheduling:")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textTertiary)
            TextField("h", text: overrideHoursText)
                .textFieldStyle(.plain)
                .font(theme.bodyFont(12))
                .multilineTextAlignment(.trailing)
                .frame(width: 26)
            Text("hr")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textTertiary)
            TextField("m", text: overrideMinutesText)
                .textFieldStyle(.plain)
                .font(theme.bodyFont(12))
                .multilineTextAlignment(.trailing)
                .frame(width: 26)
            Text("min")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(8)
        .softCard(cornerRadius: 8)
    }

    private var overrideHoursText: Binding<String> {
        Binding(
            get: {
                guard let total = manualTotalMinutes, total >= 60 else { return "" }
                return String(total / 60)
            },
            set: { newValue in
                let hours = max(0, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0)
                let minutesPart = (manualTotalMinutes ?? 0) % 60
                let total = hours * 60 + minutesPart
                manualTotalMinutes = total == 0 ? nil : total
                persist()
            }
        )
    }

    private var overrideMinutesText: Binding<String> {
        Binding(
            get: {
                guard let total = manualTotalMinutes else { return "" }
                let minutes = total % 60
                return minutes == 0 && total < 60 ? "" : String(minutes)
            },
            set: { newValue in
                let minutes = max(0, min(59, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0))
                let hoursPart = (manualTotalMinutes ?? 0) / 60
                let total = hoursPart * 60 + minutes
                manualTotalMinutes = total == 0 ? nil : total
                persist()
            }
        )
    }

    static func formatMinutes(_ total: Int) -> String {
        DurationText.format(total)
    }

    private func addStep(kind: StepKind = .step) {
        steps.append(ProtocolStep(text: "", kind: kind))
        persist()
    }

    private func removeStep(at index: Int) {
        guard steps.indices.contains(index) else { return }
        steps.remove(at: index)
        persist()
    }

    // MARK: - Version history

    private var versionHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Version History", systemImage: "archivebox")
            let versions = (currentProtocol?.versions ?? []).sorted { $0.versionNumber > $1.versionNumber }
            if versions.isEmpty {
                emptyRow("No saved versions yet — use \"Save New Version\" to start tracking history.")
            } else {
                ForEach(versions) { version in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("v\(version.versionNumber) — \(version.savedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(theme.bodyFont(12, weight: .semibold))
                                .foregroundStyle(theme.textPrimary)
                            if !version.changeNote.isEmpty {
                                Text(version.changeNote)
                                    .font(theme.bodyFont(11))
                                    .foregroundStyle(theme.textSecondary)
                            }
                        }
                        Spacer()
                        Button("Restore") {
                            versionPendingRestore = version
                        }
                        .buttonStyle(.plain)
                        .font(theme.bodyFont(11, weight: .medium))
                        .foregroundStyle(theme.accentDeep)
                    }
                    .padding(10)
                    .softCard(cornerRadius: 10)
                }
            }
        }
    }

    // MARK: - Shared row helpers

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(theme.accentDeep)
                .font(.system(size: 12))
            Text(title)
                .font(theme.bodyFont(13, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private func addButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 14))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.accentDeep)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(theme.bodyFont(12))
            .foregroundStyle(theme.textTertiary)
            .padding(.vertical, 4)
    }

    // MARK: - Persistence

    private func loadFromProtocol() {
        guard let currentProtocol else { return }
        name = currentProtocol.name
        purpose = currentProtocol.purpose
        reagents = currentProtocol.reagents
        steps = currentProtocol.steps
        tags = currentProtocol.tags
        manualTotalMinutes = currentProtocol.manualTotalMinutes
    }

    private func persist() {
        guard var updated = currentProtocol else { return }
        updated.name = name
        updated.purpose = purpose
        updated.reagents = reagents
        updated.steps = steps
        updated.tags = tags
        updated.manualTotalMinutes = manualTotalMinutes
        store.updateProtocolDraft(updated)
    }

    // MARK: - Export

    private func exportProtocolFile() {
        guard let currentProtocol else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: ProtocolPackage.fileExtension) ?? .json]
        panel.nameFieldStringValue = (currentProtocol.name.isEmpty ? "Untitled Protocol" : currentProtocol.name)
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try store.exportProtocol(currentProtocol, to: url)
            } catch {
                exportErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct ReagentRow: View {
    @EnvironmentObject var theme: ThemeStore
    @Binding var reagent: Reagent
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            TextField("Name", text: $reagent.name)
                .textFieldStyle(.plain)
                .font(theme.bodyFont(12, weight: .medium))
                .frame(minWidth: 100)
            TextField("Amount", text: $reagent.amount)
                .textFieldStyle(.plain)
                .font(theme.bodyFont(12))
                .frame(width: 60)
            TextField("Unit", text: $reagent.unit)
                .textFieldStyle(.plain)
                .font(theme.bodyFont(12))
                .frame(width: 50)
            TextField("Notes", text: $reagent.notes)
                .textFieldStyle(.plain)
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)

            if isHovering {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(8)
        .softCard(cornerRadius: 8)
        .onHover { isHovering = $0 }
    }
}

private struct StepRow: View {
    @EnvironmentObject var theme: ThemeStore
    @Binding var step: ProtocolStep
    let number: Int
    @Binding var draggedStepID: UUID?
    let onDelete: () -> Void

    /// `step.durationMinutes` is the canonical storage; hours and minutes are just two views
    /// onto the same total, so "1 hr 30 min" and "90 min" are the same underlying value.
    private var hoursText: Binding<String> {
        Binding(
            get: {
                guard let total = step.durationMinutes, total >= 60 else { return "" }
                return String(total / 60)
            },
            set: { newValue in
                let hours = max(0, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0)
                let minutesPart = (step.durationMinutes ?? 0) % 60
                let total = hours * 60 + minutesPart
                step.durationMinutes = total == 0 ? nil : total
            }
        )
    }

    private var minutesText: Binding<String> {
        Binding(
            get: {
                guard let total = step.durationMinutes else { return "" }
                let minutes = total % 60
                return minutes == 0 && total < 60 ? "" : String(minutes)
            },
            set: { newValue in
                let minutes = max(0, min(59, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0))
                let hoursPart = (step.durationMinutes ?? 0) / 60
                let total = hoursPart * 60 + minutes
                step.durationMinutes = total == 0 ? nil : total
            }
        )
    }

    private var temperatureText: Binding<String> {
        Binding(
            get: { step.temperatureCelsius.map { String(format: "%g", $0) } ?? "" },
            set: { step.temperatureCelsius = Double($0.trimmingCharacters(in: .whitespaces)) }
        )
    }

    /// The color this row should stand out in — fixed semantic colors rather than the app
    /// theme, deliberately, so a warning still reads as a warning no matter which Cazzy theme
    /// is active (the same reasoning the print view uses for staying black-on-white).
    private var accentColor: Color? {
        switch step.kind {
        case .note: return .blue
        case .warning: return .orange
        case .step:
            switch step.importance {
            case .critical: return .red
            case .important: return .orange
            case .normal: return nil
            }
        }
    }

    private var calloutLabel: String? {
        switch step.kind {
        case .step: return nil
        case .note: return "NOTE"
        case .warning: return "WARNING"
        }
    }

    private var importanceIcon: String {
        switch step.importance {
        case .normal: return "flag"
        case .important: return "flag.fill"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }

    @ViewBuilder
    private var kindBadge: some View {
        switch step.kind {
        case .step:
            Text("\(number)")
                .font(theme.bodyFont(12, weight: .bold))
                .foregroundStyle(accentColor ?? theme.accentDeep)
                .frame(width: 18, height: 18)
                .background(Circle().fill((accentColor ?? theme.secondaryAccent).opacity(0.25)))
        case .note:
            Image(systemName: "note.text")
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.blue))
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.orange))
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textSecondary)
                    .help("Drag to reorder")
                    .onDrag {
                        draggedStepID = step.id
                        return NSItemProvider(object: step.id.uuidString as NSString)
                    }

                Menu {
                    ForEach(StepKind.allCases, id: \.self) { kind in
                        Button(kind.label) { step.kind = kind }
                    }
                } label: {
                    kindBadge
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Change type: Step, Note, or Warning")
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                if let calloutLabel {
                    Text(calloutLabel)
                        .font(theme.bodyFont(10, weight: .heavy))
                        .foregroundStyle(accentColor ?? theme.textSecondary)
                        .tracking(0.5)
                }

                TextField(
                    step.kind == .step ? "Describe this step" : "\(step.kind.label) text",
                    text: $step.text,
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .font(step.kind == .step ? theme.bodyFont(13) : theme.bodyFont(13, weight: .semibold))
                .lineLimit(1...4)

                if step.kind == .step {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            HStack(spacing: 0) {
                                TextField("0", text: hoursText)
                                    .textFieldStyle(.plain)
                                    .frame(width: 14)
                                Text("hr")
                                    .foregroundStyle(theme.textTertiary)
                            }
                            HStack(spacing: 0) {
                                TextField("0", text: minutesText)
                                    .textFieldStyle(.plain)
                                    .frame(width: 14)
                                Text("min")
                                    .foregroundStyle(theme.textTertiary)
                            }
                        }
                        HStack(spacing: 0) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 10))
                                .padding(.trailing, 4)
                            TextField("0", text: temperatureText)
                                .textFieldStyle(.plain)
                                .frame(width: 14)
                            Text("°C")
                                .foregroundStyle(theme.textTertiary)
                        }
                        TextField("Notes", text: $step.notes)
                            .textFieldStyle(.plain)
                            .foregroundStyle(theme.textSecondary)

                        Spacer(minLength: 0)

                        Menu {
                            ForEach(StepImportance.allCases, id: \.self) { level in
                                Button(level.label) { step.importance = level }
                            }
                        } label: {
                            Image(systemName: importanceIcon)
                                .foregroundStyle(accentColor ?? theme.textTertiary)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("Mark importance: Normal, Important, or Critical")
                    }
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.textSecondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accentColor?.opacity(0.12) ?? theme.cardBackground)
                .shadow(color: theme.accentDeep.opacity(0.08), radius: 8, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accentColor?.opacity(0.6) ?? Color.clear, lineWidth: accentColor != nil ? 1.5 : 0)
        )
    }
}

/// Live-reorders `steps` as a dragged row passes over another row's drop target, using the
/// drag handle icon in `StepRow` as the sole drag-initiator so the row's text fields stay
/// normally clickable/editable.
private struct StepDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var steps: [ProtocolStep]
    @Binding var draggedStepID: UUID?
    let onFinished: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedStepID,
              draggedStepID != targetID,
              let fromIndex = steps.firstIndex(where: { $0.id == draggedStepID }),
              let toIndex = steps.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            steps.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedStepID = nil
        onFinished()
        return true
    }
}

import SwiftUI

/// Create/edit form for a scheduled experiment, shown as a sheet over the calendar window.
struct ExperimentEditorSheet: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var appleCalendar: AppleCalendarService
    @Environment(\.dismiss) private var dismiss

    /// nil when creating a new experiment.
    let existing: ScheduledExperiment?

    @State private var title: String
    @State private var protocolID: UUID?
    @State private var start: Date
    @State private var durationMinutes: Int
    @State private var color: ExperimentColor
    @State private var notes: String

    // Recurrence (create mode only; occurrences are materialized on save).
    private enum RecurrenceChoice: String, CaseIterable, Identifiable {
        case none = "Doesn't repeat"
        case everyNDays = "Every N days"
        case weekly = "Weekly"
        var id: String { rawValue }
    }
    @State private var recurrenceChoice: RecurrenceChoice = .none
    @State private var recurrenceStepDays: Int = 2
    @State private var recurrenceEnd: Date

    init(existing: ScheduledExperiment? = nil, defaultStart: Date = Date(), prefilledProtocol: LabProtocol? = nil) {
        self.existing = existing
        _title = State(initialValue: existing?.title ?? prefilledProtocol?.name ?? "")
        _protocolID = State(initialValue: existing?.protocolID ?? prefilledProtocol?.id)
        _start = State(initialValue: existing?.start ?? defaultStart)
        _durationMinutes = State(initialValue: existing?.durationMinutes ?? prefilledProtocol?.effectiveTotalMinutes ?? 60)
        _color = State(initialValue: existing?.color ?? .teal)
        _notes = State(initialValue: existing?.notes ?? "")
        _recurrenceEnd = State(initialValue: Calendar.current.date(byAdding: .weekOfYear, value: 2, to: existing?.start ?? defaultStart) ?? defaultStart)
    }

    private var interval: DateInterval {
        DateInterval(start: start, duration: TimeInterval(max(durationMinutes, 15) * 60))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(existing == nil ? "New Experiment" : "Edit Experiment")
                .font(theme.displayFont(18))
                .foregroundStyle(theme.textPrimary)

            TextField("Experiment title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(theme.bodyFont(13))

            protocolPicker

            HStack(spacing: 12) {
                DatePicker("Starts", selection: $start)
                    .font(theme.bodyFont(12))
                durationFields
            }

            availabilityLine

            colorRow

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(theme.bodyFont(11, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
                TextEditor(text: $notes)
                    .font(theme.bodyFont(12))
                    .scrollContentBackground(.hidden)
                    .frame(height: 48)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.5)))
            }

            if existing == nil {
                recurrenceRow
            }

            if store.syncToAppleCalendar {
                Label(
                    appleCalendar.accessState == .granted
                        ? "Will be added to your Apple Calendar (change in Settings)"
                        : "Apple Calendar sync is on, but calendar access hasn't been granted",
                    systemImage: appleCalendar.accessState == .granted ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark"
                )
                .font(theme.bodyFont(10))
                .foregroundStyle(theme.textTertiary)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(existing == nil ? "Schedule" : "Save") { saveAndDismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accentDeep)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || durationMinutes <= 0)
            }
        }
        .padding(20)
        .frame(width: 420)
        .background(theme.background)
    }

    // MARK: - Subviews

    private var protocolPicker: some View {
        Picker(selection: $protocolID) {
            Text("None").tag(UUID?.none)
            ForEach(store.protocols) { protocolItem in
                Text(protocolItem.name.isEmpty ? "Untitled Protocol" : protocolItem.name)
                    .tag(UUID?.some(protocolItem.id))
            }
        } label: {
            Text("Protocol")
                .font(theme.bodyFont(12))
        }
        .onChange(of: protocolID) { newValue in
            // Picking a protocol pre-fills duration and (if still blank) the title.
            guard let newValue, let picked = store.protocols.first(where: { $0.id == newValue }) else { return }
            if let total = picked.effectiveTotalMinutes {
                durationMinutes = total
            }
            if title.trimmingCharacters(in: .whitespaces).isEmpty {
                title = picked.name
            }
        }
    }

    private var durationFields: some View {
        HStack(spacing: 4) {
            Text("for")
                .font(theme.bodyFont(12))
                .foregroundStyle(theme.textSecondary)
            TextField("h", text: hoursText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 36)
                .multilineTextAlignment(.trailing)
            Text("hr")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textTertiary)
            TextField("m", text: minutesText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 36)
                .multilineTextAlignment(.trailing)
            Text("min")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textTertiary)
        }
    }

    private var hoursText: Binding<String> {
        Binding(
            get: { durationMinutes >= 60 ? String(durationMinutes / 60) : "" },
            set: { newValue in
                let hours = max(0, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0)
                durationMinutes = hours * 60 + durationMinutes % 60
            }
        )
    }

    private var minutesText: Binding<String> {
        Binding(
            get: {
                let minutes = durationMinutes % 60
                return minutes == 0 && durationMinutes >= 60 ? "" : String(minutes)
            },
            set: { newValue in
                let minutes = max(0, min(59, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0))
                durationMinutes = (durationMinutes / 60) * 60 + minutes
            }
        )
    }

    @ViewBuilder
    private var availabilityLine: some View {
        switch appleCalendar.accessState {
        case .granted:
            if appleCalendar.isFree(interval) {
                Label("You're free at this time", systemImage: "checkmark.circle.fill")
                    .font(theme.bodyFont(11, weight: .medium))
                    .foregroundStyle(.green)
            } else {
                Label("Overlaps an event on your Apple Calendar", systemImage: "exclamationmark.triangle.fill")
                    .font(theme.bodyFont(11, weight: .medium))
                    .foregroundStyle(.orange)
            }
        default:
            EmptyView()
        }
    }

    private var colorRow: some View {
        HStack(spacing: 8) {
            Text("Color")
                .font(theme.bodyFont(12))
                .foregroundStyle(theme.textSecondary)
            ForEach(ExperimentColor.allCases) { option in
                Button {
                    color = option
                } label: {
                    Circle()
                        .fill(option.color)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle().strokeBorder(theme.textPrimary.opacity(color == option ? 0.8 : 0), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .help(option.label)
            }
        }
    }

    private var recurrenceRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(selection: $recurrenceChoice) {
                ForEach(RecurrenceChoice.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            } label: {
                Text("Repeats")
                    .font(theme.bodyFont(12))
            }
            if recurrenceChoice != .none {
                HStack(spacing: 8) {
                    if recurrenceChoice == .everyNDays {
                        Stepper(value: $recurrenceStepDays, in: 1...30) {
                            Text("Every \(recurrenceStepDays) day\(recurrenceStepDays == 1 ? "" : "s")")
                                .font(theme.bodyFont(12))
                        }
                    }
                    DatePicker("Until", selection: $recurrenceEnd, in: start..., displayedComponents: .date)
                        .font(theme.bodyFont(12))
                }
            }
        }
    }

    // MARK: - Saving

    private func saveAndDismiss() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        if var updated = existing {
            updated.title = trimmedTitle
            updated.protocolID = protocolID
            updated.start = start
            updated.durationMinutes = durationMinutes
            updated.color = color
            updated.notes = notes

            if updated.appleCalendarEventID != nil {
                appleCalendar.updatePushedEvent(for: updated)
            } else if store.syncToAppleCalendar {
                updated.appleCalendarEventID = appleCalendar.pushEvent(for: updated)
            }
            store.updateScheduledExperiment(updated)
        } else {
            let experiment = ScheduledExperiment(
                title: trimmedTitle,
                protocolID: protocolID,
                start: start,
                durationMinutes: durationMinutes,
                color: color,
                notes: notes
            )
            let recurrence: ExperimentRecurrence
            switch recurrenceChoice {
            case .none: recurrence = .none
            case .everyNDays: recurrence = .everyNDays(recurrenceStepDays)
            case .weekly: recurrence = .weekly
            }
            let created = store.scheduleExperiment(experiment, recurrence: recurrence, until: recurrenceChoice == .none ? nil : recurrenceEnd)
            if store.syncToAppleCalendar {
                for var occurrence in created {
                    occurrence.appleCalendarEventID = appleCalendar.pushEvent(for: occurrence)
                    if occurrence.appleCalendarEventID != nil {
                        store.updateScheduledExperiment(occurrence)
                    }
                }
            }
        }
        dismiss()
    }
}

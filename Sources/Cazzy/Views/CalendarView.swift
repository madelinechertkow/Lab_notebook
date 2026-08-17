import SwiftUI
import AppKit

/// Root of the experiment-planning calendar window: a compact month overview on the left,
/// the hourly week grid on the right.
struct CalendarView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var appleCalendar: AppleCalendarService
    @Environment(\.openWindow) private var openWindow

    @State private var weekStart: Date = CalendarView.startOfWeek(containing: Date())
    @State private var monthAnchor: Date = Date()
    @State private var sheetContext: SheetContext?
    @State private var selectedExperimentID: UUID?

    enum SheetContext: Identifiable {
        case create(start: Date, prefilledProtocol: LabProtocol?)
        case edit(ScheduledExperiment)

        var id: String {
            switch self {
            case .create(let start, _): return "create-\(start.timeIntervalSince1970)"
            case .edit(let experiment): return "edit-\(experiment.id)"
            }
        }
    }

    private var weekInterval: DateInterval {
        let end = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return DateInterval(start: weekStart, end: end)
    }

    var body: some View {
        HStack(spacing: 0) {
            leftRail
                .frame(width: 230)
                .background(theme.sidebar)
            Divider().overlay(theme.divider)
            VStack(spacing: 0) {
                weekToolbar
                Divider().overlay(theme.divider)
                dayHeaderRow
                Divider().overlay(theme.divider)
                CalendarWeekGrid(
                    weekStart: weekStart,
                    selectedExperimentID: $selectedExperimentID,
                    onCreateAt: { slot in sheetContext = .create(start: slot, prefilledProtocol: nil) },
                    onEdit: { experiment in
                        // Give the detail popover a beat to finish dismissing before
                        // presenting the sheet, or the presentation can get swallowed.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            sheetContext = .edit(experiment)
                        }
                    }
                )
            }
            .background(theme.editorBackground)
        }
        .background(CalendarKeyCatcher(onDeleteKey: deleteSelectedExperiment))
        .onAppear {
            appleCalendar.excludedEventIDs = Set(store.scheduledExperiments.compactMap(\.appleCalendarEventID))
            appleCalendar.requestAccessAndRefresh(for: weekInterval)
            consumePendingScheduleRequest()
        }
        .onChange(of: weekStart) { _ in
            appleCalendar.refreshBusyIntervals(for: weekInterval)
        }
        .onReceive(store.$scheduledExperiments) { experiments in
            // Keep the self-exclusion set current so experiments never "conflict" with
            // their own pushed Apple Calendar mirrors.
            let ids = Set(experiments.compactMap(\.appleCalendarEventID))
            if ids != appleCalendar.excludedEventIDs {
                appleCalendar.excludedEventIDs = ids
                appleCalendar.refreshBusyIntervals(for: weekInterval)
            }
        }
        .onReceive(store.$pendingScheduleProtocolID) { _ in
            consumePendingScheduleRequest()
        }
        .sheet(item: $sheetContext) { context in
            switch context {
            case .create(let start, let prefilledProtocol):
                ExperimentEditorSheet(defaultStart: start, prefilledProtocol: prefilledProtocol)
            case .edit(let experiment):
                ExperimentEditorSheet(existing: experiment)
            }
        }
    }

    /// Deletes the clicked/selected experiment when the user presses backspace.
    /// Returns whether the key was handled (so unhandled presses pass through).
    private func deleteSelectedExperiment() -> Bool {
        guard sheetContext == nil,
              let id = selectedExperimentID,
              let experiment = store.scheduledExperiments.first(where: { $0.id == id }) else { return false }
        let removed = store.deleteScheduledExperiment(experiment, wholeSeries: false)
        for item in removed {
            if let eventID = item.appleCalendarEventID {
                appleCalendar.removePushedEvent(id: eventID)
            }
        }
        selectedExperimentID = nil
        return true
    }

    /// Handles "Schedule…" arriving from a protocol editor in the main window.
    private func consumePendingScheduleRequest() {
        guard let protocolID = store.pendingScheduleProtocolID else { return }
        let prefilled = store.protocols.first(where: { $0.id == protocolID })
        store.pendingScheduleProtocolID = nil
        // Default to the top of the next hour — the user picks the real slot in the sheet.
        let calendar = Calendar.current
        let nextHour = calendar.date(bySetting: .minute, value: 0, of: calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()) ?? Date()
        sheetContext = .create(start: nextHour, prefilledProtocol: prefilled)
    }

    // MARK: - Left rail

    private var leftRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonthOverview(monthAnchor: $monthAnchor, weekStart: $weekStart)
            accessHint
            Spacer()
            legend
        }
        .padding(14)
    }

    @ViewBuilder
    private var accessHint: some View {
        if appleCalendar.accessState == .denied {
            VStack(alignment: .leading, spacing: 4) {
                Label("No calendar access", systemImage: "exclamationmark.triangle")
                    .font(theme.bodyFont(11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                Text("Busy times can't be shown. Grant access in System Settings → Privacy & Security → Calendars, then relaunch Cazzy.")
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
            }
            .padding(8)
            .softCard(cornerRadius: 8)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Legend")
                .font(theme.bodyFont(11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textTertiary.opacity(0.25))
                    .frame(width: 14, height: 10)
                Text("Busy (Apple Calendar)")
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
            }
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.yellow)
                Text("Experiment overlaps a busy time")
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
            }
        }
    }

    // MARK: - Week toolbar + day headers

    private var weekToolbar: some View {
        HStack(spacing: 10) {
            Text(weekTitle)
                .font(theme.displayFont(17))
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
            Button("Today") {
                weekStart = Self.startOfWeek(containing: Date())
                monthAnchor = Date()
            }
            .buttonStyle(.plain)
            .font(theme.bodyFont(12, weight: .medium))
            .foregroundStyle(theme.accentDeep)
            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)

            Button {
                openWindow(id: "todo")
            } label: {
                Label("To-Do List", systemImage: "checklist")
                    .font(theme.bodyFont(12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)

            Button {
                sheetContext = .create(start: defaultNewSlot, prefilledProtocol: nil)
            } label: {
                Label("New Experiment", systemImage: "plus")
                    .font(theme.bodyFont(12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.accentDeep)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var defaultNewSlot: Date {
        let calendar = Calendar.current
        if weekInterval.contains(Date()) {
            return calendar.date(bySetting: .minute, value: 0, of: calendar.date(byAdding: .hour, value: 1, to: Date()) ?? Date()) ?? Date()
        }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: weekStart) ?? weekStart
    }

    private var dayHeaderRow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 52) // aligns with the grid's time gutter
            ForEach(0..<7, id: \.self) { offset in
                let day = Calendar.current.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
                DayHeader(day: day)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Date helpers

    private func shiftWeek(by weeks: Int) {
        if let shifted = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: weekStart) {
            weekStart = shifted
            monthAnchor = shifted
        }
    }

    private var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMM yyyy", options: 0, locale: .current)
        return formatter.string(from: weekStart)
    }

    static func startOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}

// MARK: - Day header (with jump to that day's notebook entries)

private struct DayHeader: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.openWindow) private var openWindow

    let day: Date
    @State private var showingNotes = false
    @State private var showingTodos = false
    @State private var newTodoText = ""

    private var isToday: Bool { Calendar.current.isDateInToday(day) }
    private var dayNotes: [Note] { store.notes(createdOn: day) }
    private var dayTodos: [TodoItem] { store.todos(on: day) }

    var body: some View {
        VStack(spacing: 2) {
            Text(weekdayText)
                .font(theme.bodyFont(10, weight: .medium))
                .foregroundStyle(isToday ? theme.accentDeep : theme.textTertiary)
            HStack(spacing: 4) {
                Text(dayNumberText)
                    .font(theme.bodyFont(14, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? theme.accentDeep : theme.textPrimary)
                if !dayNotes.isEmpty {
                    Button {
                        showingNotes = true
                    } label: {
                        Image(systemName: "book")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.secondaryAccent)
                    }
                    .buttonStyle(.plain)
                    .help("Notebook entries from this day")
                    .popover(isPresented: $showingNotes) {
                        notesPopover
                    }
                }
                Button {
                    showingTodos = true
                } label: {
                    Image(systemName: dayTodos.isEmpty ? "checklist" : (dayTodos.allSatisfy(\.isDone) ? "checkmark.circle.fill" : "checklist"))
                        .font(.system(size: 9))
                        .foregroundStyle(dayTodos.isEmpty ? theme.textTertiary.opacity(0.5) : theme.accentDeep)
                }
                .buttonStyle(.plain)
                .help("To-dos for this day")
                .popover(isPresented: $showingTodos) {
                    todosPopover
                }
            }
        }
    }

    private var todosPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("To-Do — \(dayNumberText) \(weekdayText)")
                .font(theme.bodyFont(11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            if dayTodos.isEmpty {
                Text("Nothing for this day yet.")
                    .font(theme.bodyFont(12))
                    .foregroundStyle(theme.textTertiary)
            } else {
                ForEach(dayTodos) { item in
                    HStack(spacing: 6) {
                        Button {
                            store.toggleTodo(item)
                        } label: {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(item.isDone ? theme.accentDeep : theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        Text(item.text)
                            .font(theme.bodyFont(12))
                            .foregroundStyle(item.isDone ? theme.textTertiary : theme.textPrimary)
                            .strikethrough(item.isDone, color: theme.textTertiary)
                    }
                }
            }
            Divider().overlay(theme.divider)
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.accentDeep)
                TextField("Add a task", text: $newTodoText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12))
                    .onSubmit {
                        store.addTodo(newTodoText, date: day)
                        newTodoText = ""
                    }
            }
        }
        .padding(12)
        .frame(minWidth: 220, alignment: .leading)
    }

    private var notesPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notebook entries — \(dayNumberText) \(weekdayText)")
                .font(theme.bodyFont(11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            ForEach(dayNotes) { note in
                Button {
                    store.pendingOpenNoteID = note.id
                    openWindow(id: "main")
                    showingNotes = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 10))
                        Text(note.title.isEmpty ? "Untitled" : note.title)
                            .font(theme.bodyFont(12))
                            .lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textPrimary)
            }
        }
        .padding(12)
        .frame(minWidth: 200, alignment: .leading)
    }

    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: day)
    }

    private var dayNumberText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: day)
    }
}

// MARK: - Backspace-to-delete key monitor

/// SwiftUI (macOS 13) has no onKeyPress, so an invisible NSView installs a local event
/// monitor. Delete/backspace is only intercepted when the event belongs to the calendar
/// window (or its popover) and the user isn't typing in a text field.
private struct CalendarKeyCatcher: NSViewRepresentable {
    /// Return true to consume the key press.
    var onDeleteKey: () -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onDeleteKey = onDeleteKey
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onDeleteKey = onDeleteKey
    }

    final class MonitorView: NSView {
        var onDeleteKey: (() -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                    guard let self, self.shouldHandle(event) else { return event }
                    return (self.onDeleteKey?() ?? false) ? nil : event
                }
            } else if window == nil, let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private func shouldHandle(_ event: NSEvent) -> Bool {
            let deleteKeyCode: UInt16 = 51
            let forwardDeleteKeyCode: UInt16 = 117
            guard event.keyCode == deleteKeyCode || event.keyCode == forwardDeleteKeyCode,
                  event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
                  let window,
                  let eventWindow = event.window,
                  eventWindow === window || eventWindow.parent === window else { return false }
            // Not while the user is editing text (block title field, editor sheet, etc.).
            return !(eventWindow.firstResponder is NSText)
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

// MARK: - Month overview

private struct MonthOverview: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore

    @Binding var monthAnchor: Date
    @Binding var weekStart: Date

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(monthTitle)
                    .font(theme.bodyFont(13, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 10)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accentDeep)
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").font(.system(size: 10)) }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accentDeep)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(theme.bodyFont(9, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                }
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 22)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isToday = calendar.isDateInToday(day)
        let inSelectedWeek = day >= weekStart
            && day < (calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart)
        let hasExperiments = !store.experiments(on: day).isEmpty

        return Button {
            weekStart = CalendarView.startOfWeek(containing: day)
        } label: {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: day))")
                    .font(theme.bodyFont(10, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? theme.accentDeep : theme.textPrimary)
                Circle()
                    .fill(hasExperiments ? theme.secondaryAccent : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(inSelectedWeek ? theme.accent.opacity(0.18) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Days of the anchored month, padded with nils so weekday columns line up.
    private var monthDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthAnchor) else { return [] }
        let firstDay = monthInterval.start
        let dayCount = calendar.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        let leadingBlanks = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstDay))
        }
        return cells
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMM yyyy", options: 0, locale: .current)
        return formatter.string(from: monthAnchor)
    }

    private func shiftMonth(_ delta: Int) {
        if let shifted = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = shifted
        }
    }
}

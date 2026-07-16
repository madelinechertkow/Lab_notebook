import SwiftUI
import AppKit

/// The hourly week grid: 7 day columns over a 24-hour scale, with Apple Calendar busy
/// times as a gray underlay and scheduled experiments as draggable colored blocks.
struct CalendarWeekGrid: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var appleCalendar: AppleCalendarService

    /// First day (start-of-day) of the displayed week.
    let weekStart: Date
    @Binding var selectedExperimentID: UUID?
    let onCreateAt: (Date) -> Void
    let onEdit: (ScheduledExperiment) -> Void

    static let hourHeight: CGFloat = 48
    private static let gutterWidth: CGFloat = 52

    private var days: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                HStack(alignment: .top, spacing: 0) {
                    timeGutter
                    ForEach(days, id: \.self) { day in
                        DayColumn(day: day, selectedExperimentID: $selectedExperimentID, onCreateAt: onCreateAt, onEdit: onEdit)
                            .overlay(alignment: .leading) {
                                Rectangle().fill(theme.divider).frame(width: 1)
                            }
                    }
                }
                .frame(height: Self.hourHeight * 24)
            }
            .onAppear {
                // Land the viewport at the start of a plausible lab day, not midnight.
                proxy.scrollTo("hour-marker-7", anchor: .top)
            }
        }
    }

    private var timeGutter: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(0..<24, id: \.self) { hour in
                Text(Self.hourLabel(hour))
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                    .frame(width: Self.gutterWidth - 8, alignment: .trailing)
                    .offset(y: CGFloat(hour) * Self.hourHeight - 6)
                    .id("hour-marker-\(hour)")
            }
        }
        .frame(width: Self.gutterWidth, height: Self.hourHeight * 24, alignment: .topTrailing)
    }

    static func hourLabel(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current)
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Day column

private struct DayColumn: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var appleCalendar: AppleCalendarService

    let day: Date
    @Binding var selectedExperimentID: UUID?
    let onCreateAt: (Date) -> Void
    let onEdit: (ScheduledExperiment) -> Void

    private var hourHeight: CGFloat { CalendarWeekGrid.hourHeight }

    private var dayInterval: DateInterval {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Bottom layer catches empty-slot clicks → new experiment, snapped to the
                // half hour. AppKit tracking for the same reason as the blocks: SwiftUI
                // tap gestures are unreliable inside this ScrollView.
                MouseTracker(onClickAt: { point in
                    let minutes = Double(point.y / hourHeight) * 60
                    let snapped = (minutes / 30).rounded(.down) * 30
                    if let slot = Calendar.current.date(byAdding: .minute, value: Int(snapped), to: dayInterval.start) {
                        onCreateAt(slot)
                    }
                })

                hourLines(width: geo.size.width)

                ForEach(busySegments.indices, id: \.self) { idx in
                    busyBlock(busySegments[idx], width: geo.size.width)
                }

                ForEach(store.experiments(on: day)) { experiment in
                    ExperimentBlock(
                        experiment: experiment,
                        dayInterval: dayInterval,
                        columnWidth: geo.size.width,
                        selectedExperimentID: $selectedExperimentID,
                        onEdit: onEdit
                    )
                }

                if Calendar.current.isDateInToday(day) {
                    nowLine(width: geo.size.width)
                }
            }
        }
    }

    private func hourLines(width: CGFloat) -> some View {
        ForEach(0..<24, id: \.self) { hour in
            Rectangle()
                .fill(theme.divider.opacity(0.6))
                .frame(width: width, height: 1)
                .offset(y: CGFloat(hour) * hourHeight)
        }
    }

    /// Apple Calendar busy intervals clipped to this day.
    private var busySegments: [DateInterval] {
        appleCalendar.busyIntervals.compactMap { $0.intersection(with: dayInterval) }
            .filter { $0.duration > 0 }
    }

    private func busyBlock(_ segment: DateInterval, width: CGFloat) -> some View {
        let top = yOffset(for: segment.start)
        let height = max(hourHeight * segment.duration / 3600, 8)
        return RoundedRectangle(cornerRadius: 4)
            .fill(theme.textTertiary.opacity(0.18))
            .overlay(alignment: .topLeading) {
                if height >= 16 {
                    Text("Busy")
                        .font(theme.bodyFont(9, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .padding(.leading, 4)
                        .padding(.top, 2)
                }
            }
            .frame(width: max(width - 4, 0), height: height)
            .offset(x: 2, y: top)
            .allowsHitTesting(false)
    }

    private func nowLine(width: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Rectangle()
                .fill(.red)
                .frame(width: width, height: 1.5)
                .overlay(alignment: .leading) {
                    Circle().fill(.red).frame(width: 6, height: 6).offset(x: -3)
                }
                .offset(y: yOffset(for: context.date))
                .allowsHitTesting(false)
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        hourHeight * date.timeIntervalSince(dayInterval.start) / 3600
    }
}

// MARK: - Experiment block

private struct ExperimentBlock: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var appleCalendar: AppleCalendarService

    let experiment: ScheduledExperiment
    let dayInterval: DateInterval
    let columnWidth: CGFloat
    @Binding var selectedExperimentID: UUID?
    let onEdit: (ScheduledExperiment) -> Void

    @State private var showingDetail = false
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    private var isSelected: Bool { selectedExperimentID == experiment.id }

    private var hourHeight: CGFloat { CalendarWeekGrid.hourHeight }

    /// Rendered portion of the experiment within this day (overnight runs clip at midnight).
    private var visibleInterval: DateInterval {
        experiment.interval.intersection(with: dayInterval) ?? experiment.interval
    }

    private var continuesPastMidnight: Bool {
        experiment.end > dayInterval.end
    }

    private var conflictsWithBusy: Bool {
        appleCalendar.overlapsBusy(experiment.interval)
    }

    var body: some View {
        let top = hourHeight * visibleInterval.start.timeIntervalSince(dayInterval.start) / 3600
        let height = max(hourHeight * visibleInterval.duration / 3600, 18)

        blockContent(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.textPrimary.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
            )
            .frame(width: max(columnWidth - 8, 0), height: height)
            // AppKit-level mouse tracking instead of SwiftUI gestures: DragGesture (and even
            // tap+drag combinations) silently lose arbitration inside this ScrollView on
            // macOS, leaving blocks completely inert. A real NSView always gets the events.
            .overlay(
                MouseTracker(
                    onClick: {
                        selectedExperimentID = experiment.id
                        showingDetail = true
                    },
                    onDoubleClick: {
                        // The first click of the pair opened the popover; close it and
                        // open the full editor sheet instead.
                        showingDetail = false
                        onEdit(experiment)
                    },
                    onDragChanged: { translation in
                        selectedExperimentID = experiment.id
                        isDragging = true
                        dragOffset = translation
                    },
                    onDragEnded: { translation in
                        isDragging = false
                        dragOffset = .zero
                        applyDrag(translation)
                    }
                )
            )
            .offset(x: 4 + dragOffset.width, y: top + dragOffset.height)
            .opacity(isDragging ? 0.75 : 1)
            .popover(isPresented: $showingDetail, arrowEdge: .trailing) {
                ExperimentDetailPopover(experimentID: experiment.id, onEdit: onEdit)
            }
    }

    /// Vertical movement changes time (snapped to 15 min), horizontal changes day.
    private func applyDrag(_ translation: CGSize) {
        let minuteDelta = Double(translation.height / hourHeight) * 60
        let snappedMinutes = Int((minuteDelta / 15).rounded() * 15)
        let dayDelta = Int((translation.width / max(columnWidth, 1)).rounded())
        guard snappedMinutes != 0 || dayDelta != 0 else { return }

        var moved = experiment
        if let shifted = Calendar.current.date(byAdding: .minute, value: snappedMinutes + dayDelta * 24 * 60, to: experiment.start) {
            moved.start = shifted
            store.updateScheduledExperiment(moved)
            appleCalendar.updatePushedEvent(for: moved)
        }
    }

    private func blockContent(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(experiment.color.color.opacity(experiment.isCompleted ? 0.35 : 0.85))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 3) {
                        if experiment.isCompleted {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 8))
                        }
                        Text(experiment.title)
                            .font(theme.bodyFont(10, weight: .semibold))
                            .lineLimit(height > 30 ? 2 : 1)
                        if conflictsWithBusy {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                                .help("Overlaps a busy time on your Apple Calendar")
                        }
                    }
                    if height > 34 {
                        Text(timeRangeText)
                            .font(theme.bodyFont(9))
                            .opacity(0.85)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.top, 3)
            }
            .overlay(alignment: .bottomTrailing) {
                if continuesPastMidnight {
                    Text("continues →")
                        .font(theme.bodyFont(8))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(3)
                }
            }
    }

    private var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: experiment.start))–\(formatter.string(from: experiment.end))"
    }

}

/// Routes clicks and drags through AppKit mouse events — SwiftUI gestures silently lose
/// arbitration inside this ScrollView on macOS. Drag translations use window coordinates
/// so the math stays stable while the tracked view moves under the cursor mid-drag.
private struct MouseTracker: NSViewRepresentable {
    var onClick: (() -> Void)? = nil
    /// Fires on the second click of a double-click (the first click still fires onClick).
    var onDoubleClick: (() -> Void)? = nil
    /// Click location in the tracker's own top-left-origin coordinates.
    var onClickAt: ((CGPoint) -> Void)? = nil
    var onDragChanged: ((CGSize) -> Void)? = nil
    var onDragEnded: ((CGSize) -> Void)? = nil

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        updateCallbacks(on: view)
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        updateCallbacks(on: nsView)
    }

    private func updateCallbacks(on view: TrackerView) {
        view.onClick = onClick
        view.onDoubleClick = onDoubleClick
        view.onClickAt = onClickAt
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
    }

    final class TrackerView: NSView {
        var onClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?
        var onClickAt: ((CGPoint) -> Void)?
        var onDragChanged: ((CGSize) -> Void)?
        var onDragEnded: ((CGSize) -> Void)?

        private var downLocation: NSPoint?
        private var isDragging = false
        private static let dragThreshold: CGFloat = 4

        // Match SwiftUI's top-left-origin coordinates.
        override var isFlipped: Bool { true }

        /// AppKit window coordinates have y pointing up; SwiftUI's points down, so y is negated.
        private func translation(to event: NSEvent) -> CGSize {
            guard let downLocation else { return .zero }
            return CGSize(
                width: event.locationInWindow.x - downLocation.x,
                height: -(event.locationInWindow.y - downLocation.y)
            )
        }

        override func mouseDown(with event: NSEvent) {
            downLocation = event.locationInWindow
            isDragging = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard downLocation != nil, onDragChanged != nil || onDragEnded != nil else { return }
            let offset = translation(to: event)
            if !isDragging && (abs(offset.width) > Self.dragThreshold || abs(offset.height) > Self.dragThreshold) {
                isDragging = true
            }
            if isDragging {
                onDragChanged?(offset)
            }
        }

        override func mouseUp(with event: NSEvent) {
            defer {
                downLocation = nil
                isDragging = false
            }
            guard downLocation != nil else { return }
            if isDragging {
                onDragEnded?(translation(to: event))
            } else if event.clickCount >= 2, onDoubleClick != nil {
                onDoubleClick?()
            } else {
                onClick?()
                onClickAt?(convert(event.locationInWindow, from: nil))
            }
        }
    }
}

// MARK: - Detail popover

private struct ExperimentDetailPopover: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var appleCalendar: AppleCalendarService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    /// Looked up live so the popover stays current if the store changes underneath it.
    let experimentID: UUID
    let onEdit: (ScheduledExperiment) -> Void

    private var experiment: ScheduledExperiment? {
        store.scheduledExperiments.first(where: { $0.id == experimentID })
    }

    var body: some View {
        if let experiment {
            VStack(alignment: .leading, spacing: 10) {
                editableHeader(experiment)
                Divider()
                actions(experiment)
            }
            .padding(14)
            .frame(width: 270)
        }
    }

    /// Writes one change through to the store (and any pushed Apple Calendar mirror).
    private func mutate(_ transform: (inout ScheduledExperiment) -> Void) {
        guard var updated = experiment else { return }
        transform(&updated)
        store.updateScheduledExperiment(updated)
        appleCalendar.updatePushedEvent(for: updated)
    }

    private func editableHeader(_ experiment: ScheduledExperiment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: Binding(
                get: { self.experiment?.title ?? "" },
                set: { newValue in mutate { $0.title = newValue } }
            ))
            .textFieldStyle(.roundedBorder)
            .font(theme.bodyFont(13, weight: .semibold))

            DatePicker("Starts", selection: Binding(
                get: { self.experiment?.start ?? experiment.start },
                set: { newValue in mutate { $0.start = newValue } }
            ))
            .font(theme.bodyFont(11))

            HStack(spacing: 4) {
                Text("Duration")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
                TextField("h", text: durationHoursText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 34)
                    .multilineTextAlignment(.trailing)
                Text("hr")
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                TextField("m", text: durationMinutesText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 34)
                    .multilineTextAlignment(.trailing)
                Text("min")
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
            }

            HStack(spacing: 6) {
                ForEach(ExperimentColor.allCases) { option in
                    Button {
                        mutate { $0.color = option }
                    } label: {
                        Circle()
                            .fill(option.color)
                            .frame(width: 13, height: 13)
                            .overlay(
                                Circle().strokeBorder(theme.textPrimary.opacity(experiment.color == option ? 0.8 : 0), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(option.label)
                }
            }

            if let protocolID = experiment.protocolID,
               let linkedProtocol = store.protocols.first(where: { $0.id == protocolID }) {
                Label(linkedProtocol.name, systemImage: "list.clipboard")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
            }
            if !experiment.notes.isEmpty {
                Text(experiment.notes)
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(3)
            }
        }
    }

    private var durationHoursText: Binding<String> {
        Binding(
            get: {
                guard let total = experiment?.durationMinutes, total >= 60 else { return "" }
                return String(total / 60)
            },
            set: { newValue in
                let hours = max(0, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0)
                let minutesPart = (experiment?.durationMinutes ?? 0) % 60
                let total = hours * 60 + minutesPart
                if total > 0 { mutate { $0.durationMinutes = total } }
            }
        )
    }

    private var durationMinutesText: Binding<String> {
        Binding(
            get: {
                guard let total = experiment?.durationMinutes else { return "" }
                let minutes = total % 60
                return minutes == 0 && total >= 60 ? "" : String(minutes)
            },
            set: { newValue in
                let minutes = max(0, min(59, Int(newValue.trimmingCharacters(in: .whitespaces)) ?? 0))
                let hoursPart = (experiment?.durationMinutes ?? 0) / 60
                let total = hoursPart * 60 + minutes
                if total > 0 { mutate { $0.durationMinutes = total } }
            }
        )
    }

    @ViewBuilder
    private func actions(_ experiment: ScheduledExperiment) -> some View {
        actionRow("pencil", "Edit…") {
            dismiss()
            onEdit(experiment)
        }

        actionRow(experiment.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle", experiment.isCompleted ? "Mark as not done" : "Mark as done") {
            var updated = experiment
            updated.isCompleted.toggle()
            store.updateScheduledExperiment(updated)
        }

        // Running behind: nudge this + every later experiment today by the same delay.
        // Always-visible quick buttons — anything that has to pop up or expand inside an
        // NSPopover (inline steppers, Menu) fails to appear, so the options are static.
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 11))
                    .frame(width: 14)
                    .foregroundStyle(theme.textPrimary)
                Text("Running behind? Shift rest of day:")
                    .font(theme.bodyFont(12))
                    .foregroundStyle(theme.textPrimary)
            }
            HStack(spacing: 5) {
                ForEach([15, 30, 45, 60, 120], id: \.self) { minutes in
                    shiftButton("+\(DurationText.format(minutes))", minutes: minutes, experiment: experiment)
                }
            }
            .padding(.leading, 22)
            HStack(spacing: 5) {
                Text("Ahead?")
                    .font(theme.bodyFont(10))
                    .foregroundStyle(theme.textTertiary)
                ForEach([15, 30], id: \.self) { minutes in
                    shiftButton("−\(DurationText.format(minutes))", minutes: -minutes, experiment: experiment)
                }
            }
            .padding(.leading, 22)
        }

        if let noteID = experiment.linkedNoteID, store.notes.contains(where: { $0.id == noteID }) {
            actionRow("book", "Open notebook entry") {
                store.pendingOpenNoteID = noteID
                openWindow(id: "main")
                dismiss()
            }
        } else {
            actionRow("square.and.pencil", "Create notebook entry") {
                if let note = store.createNote(from: experiment) {
                    store.pendingOpenNoteID = note.id
                    openWindow(id: "main")
                }
                dismiss()
            }
        }

        if experiment.appleCalendarEventID == nil {
            actionRow("calendar.badge.plus", "Add to Apple Calendar") {
                var updated = experiment
                updated.appleCalendarEventID = appleCalendar.pushEvent(for: updated)
                if updated.appleCalendarEventID != nil {
                    store.updateScheduledExperiment(updated)
                }
            }
            .disabled(appleCalendar.accessState != .granted)
        } else {
            actionRow("calendar.badge.minus", "Remove from Apple Calendar") {
                if let id = experiment.appleCalendarEventID {
                    appleCalendar.removePushedEvent(id: id)
                }
                var updated = experiment
                updated.appleCalendarEventID = nil
                store.updateScheduledExperiment(updated)
            }
        }

        Divider()

        actionRow("trash", experiment.seriesID == nil ? "Delete" : "Delete this occurrence", role: .destructive) {
            deleteAndCleanUp(experiment, wholeSeries: false)
        }
        if experiment.seriesID != nil {
            actionRow("trash.fill", "Delete entire series", role: .destructive) {
                deleteAndCleanUp(experiment, wholeSeries: true)
            }
        }
    }

    private func shiftButton(_ label: String, minutes: Int, experiment: ScheduledExperiment) -> some View {
        Button {
            shiftRestOfDay(from: experiment, by: minutes)
        } label: {
            Text(label)
                .font(theme.bodyFont(10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(theme.accent.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textPrimary)
    }

    private func shiftRestOfDay(from experiment: ScheduledExperiment, by minutes: Int) {
        let shifted = store.shiftDay(startingAt: experiment, by: minutes)
        for item in shifted {
            appleCalendar.updatePushedEvent(for: item)
        }
        dismiss()
    }

    private func deleteAndCleanUp(_ experiment: ScheduledExperiment, wholeSeries: Bool) {
        let removed = store.deleteScheduledExperiment(experiment, wholeSeries: wholeSeries)
        for item in removed {
            if let id = item.appleCalendarEventID {
                appleCalendar.removePushedEvent(id: id)
            }
        }
        dismiss()
    }

    private func actionRow(_ symbol: String, _ label: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .frame(width: 14)
                Text(label)
                    .font(theme.bodyFont(12))
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? Color.red : theme.textPrimary)
    }

}

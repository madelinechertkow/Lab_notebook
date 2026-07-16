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
    @Environment(\.openWindow) private var openWindow

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
                    },
                    onDoubleClick: {
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
                    },
                    contextMenu: { contextMenuEntries() }
                )
            )
            .offset(x: 4 + dragOffset.width, y: top + dragOffset.height)
            .opacity(isDragging ? 0.75 : 1)
    }

    /// Right-click menu: the "running behind" delays up front, then the rest of the
    /// block's actions — a native NSMenu, immune to the popover problems.
    private func contextMenuEntries() -> [ContextMenuEntry] {
        var entries: [ContextMenuEntry] = []

        entries.append(.submenu("Running Behind — Delay Rest of Day", [15, 30, 45, 60, 90, 120].map { minutes in
            ("Delay by \(DurationText.format(minutes))", { shiftRestOfDay(by: minutes) })
        }))
        entries.append(.submenu("Ahead of Schedule — Move Up", [15, 30, 45, 60].map { minutes in
            ("Move up by \(DurationText.format(minutes))", { shiftRestOfDay(by: -minutes) })
        }))
        entries.append(.separator)

        entries.append(.action("Edit…", { onEdit(experiment) }))
        entries.append(.action(experiment.isCompleted ? "Mark as Not Done" : "Mark as Done", {
            var updated = experiment
            updated.isCompleted.toggle()
            store.updateScheduledExperiment(updated)
        }))
        entries.append(.separator)

        if let noteID = experiment.linkedNoteID, store.notes.contains(where: { $0.id == noteID }) {
            entries.append(.action("Open Notebook Entry", {
                store.pendingOpenNoteID = noteID
                openWindow(id: "main")
            }))
        } else {
            entries.append(.action("Create Notebook Entry", {
                if let note = store.createNote(from: experiment) {
                    store.pendingOpenNoteID = note.id
                    openWindow(id: "main")
                }
            }))
        }

        if experiment.appleCalendarEventID == nil {
            if appleCalendar.accessState == .granted {
                entries.append(.action("Add to Apple Calendar", {
                    var updated = experiment
                    updated.appleCalendarEventID = appleCalendar.pushEvent(for: updated)
                    if updated.appleCalendarEventID != nil {
                        store.updateScheduledExperiment(updated)
                    }
                }))
            }
        } else {
            entries.append(.action("Remove from Apple Calendar", {
                if let id = experiment.appleCalendarEventID {
                    appleCalendar.removePushedEvent(id: id)
                }
                var updated = experiment
                updated.appleCalendarEventID = nil
                store.updateScheduledExperiment(updated)
            }))
        }
        entries.append(.separator)

        entries.append(.action(experiment.seriesID == nil ? "Delete" : "Delete This Occurrence", {
            deleteExperiment(wholeSeries: false)
        }))
        if experiment.seriesID != nil {
            entries.append(.action("Delete Entire Series", {
                deleteExperiment(wholeSeries: true)
            }))
        }

        return entries
    }

    private func shiftRestOfDay(by minutes: Int) {
        let shifted = store.shiftDay(startingAt: experiment, by: minutes)
        for item in shifted {
            appleCalendar.updatePushedEvent(for: item)
        }
    }

    private func deleteExperiment(wholeSeries: Bool) {
        let removed = store.deleteScheduledExperiment(experiment, wholeSeries: wholeSeries)
        for item in removed {
            if let id = item.appleCalendarEventID {
                appleCalendar.removePushedEvent(id: id)
            }
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

/// One entry of an AppKit context menu shown on right-click.
enum ContextMenuEntry {
    case action(String, () -> Void)
    case submenu(String, [(String, () -> Void)])
    case separator
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
    /// Built fresh at right-click time so items reflect current state.
    var contextMenu: (() -> [ContextMenuEntry])? = nil

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
        view.contextMenuProvider = contextMenu
    }

    /// Wraps a closure so it can ride along as an NSMenuItem's representedObject.
    final class MenuAction {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
    }

    final class TrackerView: NSView {
        var onClick: (() -> Void)?
        var onDoubleClick: (() -> Void)?
        var onClickAt: ((CGPoint) -> Void)?
        var onDragChanged: ((CGSize) -> Void)?
        var onDragEnded: ((CGSize) -> Void)?
        var contextMenuProvider: (() -> [ContextMenuEntry])?

        override func rightMouseDown(with event: NSEvent) {
            guard let entries = contextMenuProvider?() else {
                super.rightMouseDown(with: event)
                return
            }
            let menu = NSMenu()
            for entry in entries {
                switch entry {
                case .separator:
                    menu.addItem(.separator())
                case .action(let title, let action):
                    menu.addItem(makeItem(title, action))
                case .submenu(let title, let children):
                    let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    let submenu = NSMenu(title: title)
                    for (childTitle, childAction) in children {
                        submenu.addItem(makeItem(childTitle, childAction))
                    }
                    parent.submenu = submenu
                    menu.addItem(parent)
                }
            }
            NSMenu.popUpContextMenu(menu, with: event, for: self)
        }

        private func makeItem(_ title: String, _ action: @escaping () -> Void) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(runMenuAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = MenuAction(action)
            return item
        }

        @objc private func runMenuAction(_ sender: NSMenuItem) {
            (sender.representedObject as? MenuAction)?.run()
        }

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


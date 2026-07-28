import Foundation
import EventKit
import Combine

/// Bridges Cazzy's calendar to the user's Apple Calendar via EventKit, for two things only:
/// 1. Busy/free — fetches the *time intervals* of existing events so the planner can show
///    when the user is unavailable. Event titles, locations, and attendees are discarded
///    immediately and never stored; only bare `DateInterval`s leave this class.
/// 2. Optional push — creating/updating/removing a mirror event for a scheduled experiment
///    when the user explicitly asks for one (so it shows up on their phone with alerts).
final class AppleCalendarService: ObservableObject {
    enum AccessState {
        case undetermined
        case granted
        case denied
        case unavailable
    }

    @Published private(set) var accessState: AccessState = .undetermined
    /// Busy intervals for the most recently requested date range, oldest first.
    @Published private(set) var busyIntervals: [DateInterval] = []

    /// Every Apple Calendar the user has, for the Settings picker. Populated once access
    /// is granted; empty until then.
    @Published private(set) var availableCalendars: [EKCalendar] = []
    /// Which of `availableCalendars` count toward busy/free math and the overlap warning.
    /// Defaults to "all of them" the first time calendars are seen, matching the old
    /// unfiltered behavior; persisted afterward so the user's choice sticks.
    @Published var selectedCalendarIdentifiers: Set<String> = [] {
        didSet {
            guard oldValue != selectedCalendarIdentifiers else { return }
            UserDefaults.standard.set(Array(selectedCalendarIdentifiers), forKey: Self.selectedCalendarsKey)
            if let range = lastFetchedRange {
                refreshBusyIntervals(for: range)
            }
        }
    }
    private static let selectedCalendarsKey = "cazzySelectedAppleCalendarIdentifiers"

    /// Which Apple Calendar new experiments get pushed into. `nil` means "use the system
    /// default calendar for new events" — the calendar Apple Calendar itself would use.
    @Published var pushCalendarIdentifier: String? {
        didSet {
            guard oldValue != pushCalendarIdentifier else { return }
            if let pushCalendarIdentifier {
                UserDefaults.standard.set(pushCalendarIdentifier, forKey: Self.pushCalendarKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.pushCalendarKey)
            }
        }
    }
    private static let pushCalendarKey = "cazzyPushCalendarIdentifier"

    /// Identifiers of events Cazzy itself pushed. These are excluded from busy/free math —
    /// otherwise an experiment would "conflict" with its own Apple Calendar mirror.
    /// The calendar window seeds this from the store; pushEvent keeps it current in-session.
    var excludedEventIDs: Set<String> = []

    private let eventStore = EKEventStore()
    private var lastFetchedRange: DateInterval?

    init() {
        pushCalendarIdentifier = UserDefaults.standard.string(forKey: Self.pushCalendarKey)
        refreshAccessState()
        refreshAvailableCalendars()
        // Keep the overlay current if the user edits their Apple Calendar while Cazzy is open.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func storeChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.refreshAvailableCalendars()
            guard let range = self.lastFetchedRange else { return }
            self.refreshBusyIntervals(for: range)
        }
    }

    /// Refreshes the list of calendars for the Settings picker. New calendars default to
    /// enabled; calendars the user removed from Apple Calendar drop out of the saved selection.
    private func refreshAvailableCalendars() {
        guard accessState == .granted else { return }
        let calendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        availableCalendars = calendars
        let known = Set(calendars.map(\.calendarIdentifier))
        if let saved = UserDefaults.standard.array(forKey: Self.selectedCalendarsKey) as? [String] {
            selectedCalendarIdentifiers = Set(saved).intersection(known)
        } else {
            selectedCalendarIdentifiers = known
        }
    }

    /// Calendars to actually query for busy/free math — `nil` (unfiltered) until the
    /// calendar list has loaded at least once, so nothing looks falsely "free" in that gap.
    private var filteredCalendars: [EKCalendar]? {
        guard !availableCalendars.isEmpty else { return nil }
        return availableCalendars.filter { selectedCalendarIdentifiers.contains($0.calendarIdentifier) }
    }

    private func refreshAccessState() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .notDetermined:
            accessState = .undetermined
        case .denied, .restricted:
            accessState = .denied
        case .authorized:
            accessState = .granted
        default:
            if #available(macOS 14.0, *), status == .fullAccess {
                accessState = .granted
            } else {
                accessState = .denied
            }
        }
    }

    /// Requests calendar access if not yet determined, then refreshes the given range.
    /// The TCC prompt only appears when Cazzy runs as a real .app bundle whose Info.plist
    /// carries the calendar usage-description keys.
    func requestAccessAndRefresh(for range: DateInterval) {
        let finish: (Bool) -> Void = { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.accessState = granted ? .granted : .denied
                if granted {
                    self.refreshAvailableCalendars()
                    self.refreshBusyIntervals(for: range)
                }
            }
        }

        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { granted, _ in finish(granted) }
            } else {
                eventStore.requestAccess(to: .event) { granted, _ in finish(granted) }
            }
        default:
            refreshAccessState()
            if accessState == .granted {
                refreshAvailableCalendars()
                refreshBusyIntervals(for: range)
            }
        }
    }

    /// Replaces `busyIntervals` with the busy times in `range`. All-day events are skipped —
    /// a holiday or birthday shouldn't block an experiment slot.
    func refreshBusyIntervals(for range: DateInterval) {
        guard accessState == .granted else { return }
        lastFetchedRange = range
        let predicate = eventStore.predicateForEvents(withStart: range.start, end: range.end, calendars: filteredCalendars)
        let events = eventStore.events(matching: predicate)
        let intervals = events
            .filter { !$0.isAllDay && !isPushedByCazzy($0) }
            .compactMap { event -> DateInterval? in
                guard let start = event.startDate, let end = event.endDate, end > start else { return nil }
                return DateInterval(start: start, end: end)
            }
            .sorted { $0.start < $1.start }
        busyIntervals = intervals
    }

    private func isPushedByCazzy(_ event: EKEvent) -> Bool {
        guard let id = event.eventIdentifier else { return false }
        return excludedEventIDs.contains(id)
    }

    /// Whether the user has no Apple Calendar event overlapping `interval`.
    /// Queries the store directly so it works for dates outside the fetched week too.
    func isFree(_ interval: DateInterval) -> Bool {
        guard accessState == .granted else { return true }
        let predicate = eventStore.predicateForEvents(withStart: interval.start, end: interval.end, calendars: filteredCalendars)
        return !eventStore.events(matching: predicate).contains { event in
            guard !event.isAllDay, !isPushedByCazzy(event),
                  let start = event.startDate, let end = event.endDate else { return false }
            return DateInterval(start: start, end: end).intersects(interval)
        }
    }

    /// Whether `interval` overlaps any of the currently fetched busy intervals — cheap
    /// check used per-block while rendering the week grid.
    func overlapsBusy(_ interval: DateInterval) -> Bool {
        busyIntervals.contains { $0.intersects(interval) }
    }

    // MARK: - Pushing experiments to Apple Calendar

    /// The calendar new experiments get pushed into: the user's Settings choice if it still
    /// exists, otherwise the system default. Auto-creating a dedicated calendar turned out to
    /// be unreliable (EventKit accepted the creation in-session but it never showed up in
    /// Calendar.app and didn't survive a restart) — picking from real, existing calendars
    /// sidesteps that entirely.
    private var pushCalendar: EKCalendar? {
        if let id = pushCalendarIdentifier, let chosen = availableCalendars.first(where: { $0.calendarIdentifier == id }) {
            return chosen
        }
        return eventStore.defaultCalendarForNewEvents
    }

    /// Creates an Apple Calendar event mirroring the experiment. Returns the event
    /// identifier to store on the experiment, or nil if saving failed.
    func pushEvent(for experiment: ScheduledExperiment) -> String? {
        guard accessState == .granted, let calendar = pushCalendar else { return nil }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = experiment.title
        event.startDate = experiment.start
        event.endDate = experiment.end
        event.notes = "Scheduled in Cazzy"
        do {
            try eventStore.save(event, span: .thisEvent)
            if let id = event.eventIdentifier {
                excludedEventIDs.insert(id)
            }
            return event.eventIdentifier
        } catch {
            return nil
        }
    }

    /// Moves the pushed mirror event to match the experiment's current time/title.
    /// Returns false if the event no longer exists (e.g. user deleted it in Apple Calendar).
    @discardableResult
    func updatePushedEvent(for experiment: ScheduledExperiment) -> Bool {
        guard accessState == .granted,
              let id = experiment.appleCalendarEventID,
              let event = eventStore.event(withIdentifier: id) else { return false }
        event.title = experiment.title
        event.startDate = experiment.start
        event.endDate = experiment.end
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            return false
        }
    }

    func removePushedEvent(id: String) {
        guard accessState == .granted,
              let event = eventStore.event(withIdentifier: id) else { return }
        try? eventStore.remove(event, span: .thisEvent)
    }
}

import SwiftUI
import UniformTypeIdentifiers

private enum DayFilter: Hashable {
    case week
    case day(Date)
}

struct TodoListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @State private var newItemText: String = ""
    @State private var newItemDate: Date = Date()
    @State private var filter: DayFilter = .week
    @State private var weekStart: Date = CalendarView.startOfWeek(containing: Date())

    private var weekDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var scopeDate: Date? {
        if case .day(let date) = filter { return date }
        return nil
    }

    private var itemsInScope: [TodoItem] {
        if let scopeDate {
            return store.todos(on: scopeDate)
        }
        return store.todos(forWeekStarting: weekStart)
    }

    private var hasCompletedInScope: Bool {
        itemsInScope.contains { $0.isDone }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("To-Do")
                    .font(theme.displayFont(20))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if hasCompletedInScope {
                    Button("Clear completed") {
                        if let scopeDate {
                            store.clearCompletedTodos(on: scopeDate)
                        } else {
                            store.clearCompletedTodos(forWeekStarting: weekStart)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                }
            }

            weekNav

            dayChips

            Divider().overlay(theme.divider)

            if itemsInScope.isEmpty {
                Text(scopeDate == nil ? "Nothing on your list this week." : "Nothing for this day yet.")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 2)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    switch filter {
                    case .week:
                        weekContent
                    case .day(let date):
                        dayContent(date)
                    }
                }
                .scrollContentBackground(.hidden)
            }

            Divider().overlay(theme.divider)

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(theme.accentDeep)
                TextField("Add a task", text: $newItemText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(13))
                    .onSubmit {
                        store.addTodo(newItemText, date: scopeDate ?? newItemDate)
                        newItemText = ""
                    }
                DatePicker("", selection: $newItemDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .font(theme.bodyFont(11, weight: .medium))
                    .fixedSize()
                    .disabled(scopeDate != nil)
                    .opacity(scopeDate != nil ? 0.5 : 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.cardBackground)
        .background(theme.secondaryAccent.opacity(0.16))
        .onChange(of: filter) { newValue in
            if case .day(let date) = newValue {
                newItemDate = date
            }
        }
    }

    // MARK: - Week navigation

    private var weekNav: some View {
        HStack(spacing: 10) {
            Text(weekTitle)
                .font(theme.bodyFont(12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
            Button("Today") {
                weekStart = CalendarView.startOfWeek(containing: Date())
                if case .day = filter {
                    filter = .day(Calendar.current.startOfDay(for: Date()))
                }
            }
            .buttonStyle(.plain)
            .font(theme.bodyFont(11, weight: .medium))
            .foregroundStyle(theme.accentDeep)
            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.accentDeep)
        }
    }

    private func shiftWeek(by weeks: Int) {
        guard let shifted = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: weekStart) else { return }
        weekStart = shifted
        // Keep the same weekday selected (e.g. "Wed") in the newly-shown week.
        if case .day(let date) = filter, let shiftedDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: date) {
            filter = .day(shiftedDate)
        }
    }

    private var weekTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMM d", options: 0, locale: .current)
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 6, to: weekStart) else {
            return formatter.string(from: weekStart)
        }
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
    }

    // MARK: - Day chips

    private var dayChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                DayChip(label: "Week", isSelected: filter == .week) {
                    filter = .week
                }
                ForEach(weekDates, id: \.self) { date in
                    DayChip(label: dayChipLabel(date), isSelected: isSelectedDay(date), isToday: Calendar.current.isDateInToday(date)) {
                        filter = .day(date)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func isSelectedDay(_ date: Date) -> Bool {
        if case .day(let selected) = filter { return Calendar.current.isDate(selected, inSameDayAs: date) }
        return false
    }

    private func dayChipLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }

    // MARK: - Content

    private var weekContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(weekDates, id: \.self) { date in
                let items = store.todos(on: date)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(dayHeaderLabel(date))
                            .font(theme.bodyFont(12, weight: .semibold))
                            .foregroundStyle(Calendar.current.isDateInToday(date) ? theme.accentDeep : theme.textSecondary)
                        Spacer()
                        if !items.isEmpty {
                            Text("\(items.count)")
                                .font(theme.bodyFont(11))
                                .foregroundStyle(theme.textTertiary)
                        }
                    }
                    if items.isEmpty {
                        Text("No tasks")
                            .font(theme.bodyFont(12))
                            .foregroundStyle(theme.textTertiary)
                    } else {
                        TodoItemsList(date: date)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func dayHeaderLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func dayContent(_ date: Date) -> some View {
        let items = store.todos(on: date)
        return VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Text("Nothing for \(dayChipLabel(date)) yet.")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
            } else {
                TodoItemsList(date: date)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DayChip: View {
    @EnvironmentObject var theme: ThemeStore
    let label: String
    let isSelected: Bool
    var isToday: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(theme.bodyFont(11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isSelected ? theme.accentDeep : theme.secondaryAccent.opacity(0.18))
                )
                .foregroundStyle(isSelected ? theme.accentDeep.readableForeground : theme.textSecondary)
                .overlay(
                    Capsule().strokeBorder(theme.accentDeep.opacity(isToday && !isSelected ? 0.6 : 0), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Renders one day's tasks and wires up drag-to-reorder. `items` is a computed binding
/// into `store.todos` filtered to `date`; reordering writes through it, but only during
/// an active drag — disk writes are deferred to `TodoDropDelegate.performDrop` so hovering
/// across rows doesn't hammer `save()`.
private struct TodoItemsList: View {
    @EnvironmentObject var store: NoteStore
    let date: Date
    @State private var draggedItemID: UUID?

    private var items: Binding<[TodoItem]> {
        Binding(
            get: { store.todos(on: date) },
            set: { newItems in
                var iterator = newItems.makeIterator()
                let calendar = Calendar.current
                store.todos = store.todos.map { calendar.isDate($0.date, inSameDayAs: date) ? (iterator.next() ?? $0) : $0 }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(items.wrappedValue) { item in
                TodoRow(item: item, draggedItemID: $draggedItemID)
                    .onDrop(
                        of: [.text],
                        delegate: TodoDropDelegate(
                            targetID: item.id,
                            items: items,
                            draggedItemID: $draggedItemID,
                            onFinished: { store.save() }
                        )
                    )
            }
        }
    }
}

private struct TodoDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var items: [TodoItem]
    @Binding var draggedItemID: UUID?
    let onFinished: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItemID,
              draggedItemID != targetID,
              let fromIndex = items.firstIndex(where: { $0.id == draggedItemID }),
              let toIndex = items.firstIndex(where: { $0.id == targetID }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItemID = nil
        onFinished()
        return true
    }
}

private struct TodoRow: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let item: TodoItem
    @Binding var draggedItemID: UUID?
    @State private var isHovering = false
    @State private var isExpanded = false
    @State private var newSubtaskText = ""
    @State private var isEditingText = false
    @State private var editedText = ""
    @FocusState private var isTextFieldFocused: Bool

    private var doneSubtaskCount: Int { item.subtasks.filter(\.isDone).count }

    private func startEditing() {
        editedText = item.text
        isEditingText = true
        isTextFieldFocused = true
    }

    private func commitEdit() {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            store.updateTodoText(item, text: trimmed)
        }
        isEditingText = false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary)
                    .opacity(isHovering ? 1 : 0.35)
                    .help("Drag to reorder")
                    .onDrag {
                        draggedItemID = item.id
                        return NSItemProvider(object: item.id.uuidString as NSString)
                    }

                Button {
                    store.toggleTodo(item)
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundStyle(item.isDone ? theme.accentDeep : theme.textSecondary)
                }
                .buttonStyle(.plain)

                if !item.subtasks.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .foregroundStyle(theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                if isEditingText {
                    TextField("", text: $editedText)
                        .textFieldStyle(.plain)
                        .font(theme.bodyFont(13))
                        .focused($isTextFieldFocused)
                        .onSubmit { commitEdit() }
                        .onChange(of: isTextFieldFocused) { focused in
                            if !focused { commitEdit() }
                        }
                } else {
                    Text(item.text)
                        .font(theme.bodyFont(13))
                        .foregroundStyle(item.isDone ? theme.textTertiary : theme.textPrimary)
                        .strikethrough(item.isDone, color: theme.textTertiary)
                        .contentShape(Rectangle())
                        .onTapGesture { startEditing() }
                }

                if !item.subtasks.isEmpty {
                    Text("\(doneSubtaskCount)/\(item.subtasks.count)")
                        .font(theme.bodyFont(10, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                }

                Spacer()

                if isHovering {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isExpanded = true }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                    .help("Add subtask")

                    Button {
                        store.deleteTodo(item)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in isHovering = hovering }

            if isExpanded {
                subtasksSection
            }
        }
    }

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(item.subtasks) { subtask in
                SubtaskRow(item: item, subtask: subtask)
            }
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.textTertiary)
                TextField("Add subtask", text: $newSubtaskText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(12))
                    .onSubmit {
                        store.addSubtask(newSubtaskText, to: item)
                        newSubtaskText = ""
                    }
            }
        }
        .padding(.leading, 33)
    }
}

private struct SubtaskRow: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let item: TodoItem
    let subtask: Subtask
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.toggleSubtask(subtask, in: item)
            } label: {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(subtask.isDone ? theme.accentDeep : theme.textSecondary)
            }
            .buttonStyle(.plain)

            Text(subtask.text)
                .font(theme.bodyFont(12))
                .foregroundStyle(subtask.isDone ? theme.textTertiary : theme.textPrimary)
                .strikethrough(subtask.isDone, color: theme.textTertiary)

            Spacer()

            if isHovering {
                Button {
                    store.deleteSubtask(subtask, from: item)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in isHovering = hovering }
    }
}

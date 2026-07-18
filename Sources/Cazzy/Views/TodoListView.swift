import SwiftUI

private enum DayFilter: Hashable {
    case week
    case day(Weekday)
}

struct TodoListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @State private var newItemText: String = ""
    @State private var newItemDay: Weekday = .today
    @State private var filter: DayFilter = .week

    private var scopeWeekday: Weekday? {
        if case .day(let weekday) = filter { return weekday }
        return nil
    }

    private var hasCompletedInScope: Bool {
        if let scopeWeekday {
            return store.todos(for: scopeWeekday).contains { $0.isDone }
        }
        return store.todos.contains { $0.isDone }
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
                        store.clearCompletedTodos(weekday: scopeWeekday)
                    }
                    .buttonStyle(.plain)
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                }
            }

            dayChips

            Divider().overlay(theme.divider)

            if store.todos.isEmpty {
                Text("Nothing on your list yet.")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 2)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    switch filter {
                    case .week:
                        weekContent
                    case .day(let weekday):
                        dayContent(weekday)
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
                        store.addTodo(newItemText, weekday: scopeWeekday ?? newItemDay)
                        newItemText = ""
                    }
                Menu {
                    ForEach(Weekday.allCases) { weekday in
                        Button(weekday.label) { newItemDay = weekday }
                    }
                } label: {
                    Text((scopeWeekday ?? newItemDay).shortLabel)
                        .font(theme.bodyFont(11, weight: .medium))
                        .foregroundStyle(theme.textSecondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(scopeWeekday != nil)
                .opacity(scopeWeekday != nil ? 0.5 : 1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.cardBackground)
        .background(theme.secondaryAccent.opacity(0.16))
        .onChange(of: filter) { newValue in
            if case .day(let weekday) = newValue {
                newItemDay = weekday
            }
        }
    }

    private var dayChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                DayChip(label: "Week", isSelected: filter == .week) {
                    filter = .week
                }
                ForEach(Weekday.allCases) { weekday in
                    DayChip(label: weekday.shortLabel, isSelected: filter == .day(weekday)) {
                        filter = .day(weekday)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var weekContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Weekday.allCases) { weekday in
                let items = store.todos(for: weekday)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(weekday.label)
                            .font(theme.bodyFont(12, weight: .semibold))
                            .foregroundStyle(theme.textSecondary)
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
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(items) { item in
                                TodoRow(item: item)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func dayContent(_ weekday: Weekday) -> some View {
        let items = store.todos(for: weekday)
        return VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Text("Nothing for \(weekday.label) yet.")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
            } else {
                ForEach(items) { item in
                    TodoRow(item: item)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DayChip: View {
    @EnvironmentObject var theme: ThemeStore
    let label: String
    let isSelected: Bool
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
        }
        .buttonStyle(.plain)
    }
}

private struct TodoRow: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    let item: TodoItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.toggleTodo(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(item.isDone ? theme.accentDeep : theme.textSecondary)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(theme.bodyFont(13))
                .foregroundStyle(item.isDone ? theme.textTertiary : theme.textPrimary)
                .strikethrough(item.isDone, color: theme.textTertiary)

            Spacer()

            Menu {
                ForEach(Weekday.allCases) { weekday in
                    Button(weekday.label) { store.setTodoWeekday(item, weekday: weekday) }
                }
            } label: {
                Text(item.weekday.shortLabel)
                    .font(theme.bodyFont(10, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if isHovering {
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
    }
}

import Foundation

extension NoteStore {
    // MARK: - CRUD

    func addTodo(_ text: String, date: Date = Date()) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.append(TodoItem(text: trimmed, date: date))
        save()
    }

    func toggleTodo(_ item: TodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].isDone.toggle()
        // Completing the main task implies its subtasks are done too; un-completing it
        // leaves their individual progress alone rather than resetting it.
        if todos[idx].isDone {
            for subIdx in todos[idx].subtasks.indices {
                todos[idx].subtasks[subIdx].isDone = true
            }
        }
        save()
    }

    func deleteTodo(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
        save()
    }

    func updateTodoText(_ item: TodoItem, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].text = trimmed
        save()
    }

    func addSubtask(_ text: String, to item: TodoItem) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].subtasks.append(Subtask(text: trimmed))
        save()
    }

    func toggleSubtask(_ subtask: Subtask, in item: TodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }),
              let subIdx = todos[idx].subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        todos[idx].subtasks[subIdx].isDone.toggle()
        save()
    }

    func deleteSubtask(_ subtask: Subtask, from item: TodoItem) {
        guard let idx = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[idx].subtasks.removeAll { $0.id == subtask.id }
        save()
    }

    // MARK: - Queries

    func todos(on day: Date) -> [TodoItem] {
        todos.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    /// Every todo whose date falls within the 7 days starting at `weekStart` (expected to
    /// already be a start-of-week date, e.g. from `CalendarView.startOfWeek(containing:)`).
    func todos(forWeekStarting weekStart: Date) -> [TodoItem] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: weekStart)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return [] }
        return todos.filter { $0.date >= start && $0.date < end }
    }

    func clearCompletedTodos(on day: Date) {
        todos.removeAll { $0.isDone && Calendar.current.isDate($0.date, inSameDayAs: day) }
        save()
    }

    func clearCompletedTodos(forWeekStarting weekStart: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: weekStart)
        guard let end = calendar.date(byAdding: .day, value: 7, to: start) else { return }
        todos.removeAll { $0.isDone && $0.date >= start && $0.date < end }
        save()
    }
}

import SwiftUI

struct TodoListView: View {
    @EnvironmentObject var store: NoteStore
    @EnvironmentObject var theme: ThemeStore
    @State private var newItemText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("To-Do")
                    .font(theme.displayFont(20))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if store.todos.contains(where: { $0.isDone }) {
                    Button("Clear completed") {
                        store.clearCompletedTodos()
                    }
                    .buttonStyle(.plain)
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                }
            }

            Divider().overlay(theme.divider)

            if store.todos.isEmpty {
                Text("Nothing on your list yet.")
                    .font(theme.bodyFont(13))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 2)
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.todos) { item in
                            TodoRow(item: item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider().overlay(theme.divider)

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(theme.accentDeep)
                TextField("Add a task", text: $newItemText)
                    .textFieldStyle(.plain)
                    .font(theme.bodyFont(13))
                    .onSubmit {
                        store.addTodo(newItemText)
                        newItemText = ""
                    }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.cardBackground)
        .background(theme.secondaryAccent.opacity(0.16))
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

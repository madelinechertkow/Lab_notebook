import SwiftUI
import AppKit

/// Captures a raw keyDown while `isRecording` is true, without inserting any text itself —
/// used by `ShortcutEditorSheet` to let the user press the exact combo they want to bind.
private struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (NSEvent) -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let view = RecorderNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.onCapture = onCapture
        if isRecording, nsView.window?.firstResponder !== nsView {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class RecorderNSView: NSView {
        var onCapture: ((NSEvent) -> Void)?
        override var acceptsFirstResponder: Bool { true }
        override func keyDown(with event: NSEvent) {
            onCapture?(event)
        }
    }
}

struct ShortcutManagerView: View {
    @EnvironmentObject var theme: ThemeStore
    @EnvironmentObject var shortcuts: ShortcutStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingShortcut: SpecialCharacterShortcut?
    @State private var showingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Special Character Shortcuts")
                    .font(theme.displayFont(16))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Button("Add Shortcut") {
                    editingShortcut = SpecialCharacterShortcut(key: "", insertText: "", label: "")
                    showingEditor = true
                }
            }
            .padding([.horizontal, .top], 20)

            Text("While writing a note, pressing one of these key combinations inserts its text instead of whatever that key would normally produce. The defaults mirror the standard macOS Option-key symbols, but every combo below can be changed or removed, and you can add your own.")
                .font(theme.bodyFont(11))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)

            List {
                ForEach(shortcuts.shortcuts) { shortcut in
                    HStack(spacing: 12) {
                        Text(shortcut.displayCombo)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(theme.editorBackground))
                            .frame(minWidth: 70, alignment: .center)

                        Text(shortcut.insertText)
                            .font(.system(size: 16))
                            .foregroundStyle(theme.accentDeep)
                            .frame(width: 28)

                        Text(shortcut.label)
                            .font(theme.bodyFont(12))
                            .foregroundStyle(theme.textSecondary)

                        Spacer()

                        Button {
                            editingShortcut = shortcut
                            showingEditor = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textSecondary)

                        Button(role: .destructive) {
                            shortcuts.remove(shortcut)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset)

            Divider().overlay(theme.divider)

            HStack {
                Button("Reset to Defaults") {
                    shortcuts.resetToDefaults()
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 520)
        .background(theme.background)
        .sheet(isPresented: $showingEditor) {
            if let editingShortcut {
                ShortcutEditorSheet(shortcut: editingShortcut) { updated in
                    if shortcuts.shortcuts.contains(where: { $0.id == updated.id }) {
                        shortcuts.update(updated)
                    } else {
                        shortcuts.add(updated)
                    }
                }
            }
        }
    }
}

private struct ShortcutEditorSheet: View {
    @EnvironmentObject var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    @State private var shortcut: SpecialCharacterShortcut
    @State private var insertText: String
    @State private var label: String
    @State private var isRecording = false
    var onSave: (SpecialCharacterShortcut) -> Void

    init(shortcut: SpecialCharacterShortcut, onSave: @escaping (SpecialCharacterShortcut) -> Void) {
        _shortcut = State(initialValue: shortcut)
        _insertText = State(initialValue: shortcut.insertText)
        _label = State(initialValue: shortcut.label)
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Special Character Shortcut")
                .font(theme.displayFont(15))
                .foregroundStyle(theme.textPrimary)

            VStack(alignment: .leading, spacing: 5) {
                Text("Keystroke")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)

                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? theme.accent : theme.divider, lineWidth: isRecording ? 2 : 1)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(theme.editorBackground))

                    Text(isRecording ? "Press a key combination…" : (shortcut.key.isEmpty ? "Click to record" : shortcut.displayCombo))
                        .font(theme.bodyFont(13))
                        .foregroundStyle(isRecording ? theme.textSecondary : theme.textPrimary)

                    ShortcutRecorderView(isRecording: $isRecording) { event in
                        if let updated = SpecialCharacterShortcut.fromEvent(event, insertText: insertText, label: label) {
                            shortcut.key = updated.key
                            shortcut.command = updated.command
                            shortcut.option = updated.option
                            shortcut.control = updated.control
                            shortcut.shift = updated.shift
                        }
                        isRecording = false
                    }
                }
                .frame(height: 32)
                .contentShape(Rectangle())
                .onTapGesture { isRecording = true }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Inserts")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                TextField("e.g. µ or °C", text: $insertText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Label")
                    .font(theme.bodyFont(11))
                    .foregroundStyle(theme.textSecondary)
                TextField("e.g. Micro", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    shortcut.insertText = insertText
                    shortcut.label = label.trimmingCharacters(in: .whitespaces).isEmpty ? insertText : label
                    onSave(shortcut)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(shortcut.key.isEmpty || insertText.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(theme.background)
    }
}

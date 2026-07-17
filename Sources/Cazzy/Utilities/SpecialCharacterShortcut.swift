import AppKit

/// A user-configurable keystroke that inserts a literal string of text into the editor,
/// overriding whatever AppKit would normally do with that key combination.
struct SpecialCharacterShortcut: Codable, Equatable, Identifiable {
    var id: UUID
    /// The base key as reported by `NSEvent.charactersIgnoringModifiers` (already reflects
    /// Shift, e.g. Shift+8 is "*") — lowercase for non-letter keys, case-sensitive for letters.
    var key: String
    var command: Bool
    var option: Bool
    var control: Bool
    var shift: Bool
    var insertText: String
    var label: String

    init(id: UUID = UUID(), key: String, command: Bool = false, option: Bool = false, control: Bool = false, shift: Bool = false, insertText: String, label: String) {
        self.id = id
        self.key = key
        self.command = command
        self.option = option
        self.control = control
        self.shift = shift
        self.insertText = insertText
        self.label = label
    }

    var displayCombo: String {
        var combo = ""
        if control { combo += "⌃" }
        if option { combo += "⌥" }
        if shift { combo += "⇧" }
        if command { combo += "⌘" }
        combo += key.count == 1 ? key.uppercased() : key
        return combo
    }

    private var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if command { flags.insert(.command) }
        if option { flags.insert(.option) }
        if control { flags.insert(.control) }
        if shift { flags.insert(.shift) }
        return flags
    }

    func matches(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers, chars == key else { return false }
        return event.modifierFlags.intersection([.command, .option, .control, .shift]) == modifierFlags
    }

    /// Builds a shortcut from a live keyDown event, e.g. while recording a new binding.
    static func fromEvent(_ event: NSEvent, insertText: String, label: String) -> SpecialCharacterShortcut? {
        guard let key = event.charactersIgnoringModifiers, !key.isEmpty else { return nil }
        let flags = event.modifierFlags
        return SpecialCharacterShortcut(
            key: key,
            command: flags.contains(.command),
            option: flags.contains(.option),
            control: flags.contains(.control),
            shift: flags.contains(.shift),
            insertText: insertText,
            label: label
        )
    }
}

extension SpecialCharacterShortcut {
    /// Mirrors the standard macOS Option-key special characters most relevant to lab notes.
    /// These already work natively in any text field without this feature — they're seeded
    /// here as editable defaults so the override mechanism has a familiar, non-surprising
    /// starting point that the user can then remap or add to.
    static let defaults: [SpecialCharacterShortcut] = [
        SpecialCharacterShortcut(key: "j", option: true, insertText: "∆", label: "Delta"),
        SpecialCharacterShortcut(key: "d", option: true, insertText: "∂", label: "Partial derivative"),
        SpecialCharacterShortcut(key: "z", option: true, insertText: "Ω", label: "Ohm / Omega"),
        SpecialCharacterShortcut(key: "p", option: true, insertText: "π", label: "Pi"),
        SpecialCharacterShortcut(key: "m", option: true, insertText: "µ", label: "Micro"),
        SpecialCharacterShortcut(key: "b", option: true, insertText: "∫", label: "Integral"),
        SpecialCharacterShortcut(key: "v", option: true, insertText: "√", label: "Square root"),
        SpecialCharacterShortcut(key: "5", option: true, insertText: "∞", label: "Infinity"),
        SpecialCharacterShortcut(key: "x", option: true, insertText: "≈", label: "Approximately"),
        SpecialCharacterShortcut(key: ",", option: true, insertText: "≤", label: "Less than or equal"),
        SpecialCharacterShortcut(key: ".", option: true, insertText: "≥", label: "Greater than or equal"),
        SpecialCharacterShortcut(key: "=", option: true, insertText: "≠", label: "Not equal"),
        SpecialCharacterShortcut(key: "+", option: true, shift: true, insertText: "±", label: "Plus-minus"),
        SpecialCharacterShortcut(key: "8", option: true, insertText: "•", label: "Bullet"),
        SpecialCharacterShortcut(key: "*", option: true, shift: true, insertText: "°", label: "Degree"),
        SpecialCharacterShortcut(key: "/", option: true, insertText: "÷", label: "Divide"),
    ]
}

/// Persists the user's special-character keystroke overrides, mirroring `ThemeStore`'s
/// pattern of a small standalone preference store with its own JSON file.
final class ShortcutStore: ObservableObject {
    @Published var shortcuts: [SpecialCharacterShortcut] {
        didSet { save() }
    }

    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Cazzy", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("shortcuts.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SpecialCharacterShortcut].self, from: data) {
            shortcuts = decoded
        } else {
            shortcuts = SpecialCharacterShortcut.defaults
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func add(_ shortcut: SpecialCharacterShortcut) {
        shortcuts.append(shortcut)
    }

    func update(_ shortcut: SpecialCharacterShortcut) {
        guard let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[index] = shortcut
    }

    func remove(_ shortcut: SpecialCharacterShortcut) {
        shortcuts.removeAll { $0.id == shortcut.id }
    }

    func resetToDefaults() {
        shortcuts = SpecialCharacterShortcut.defaults
    }

    func match(for event: NSEvent) -> SpecialCharacterShortcut? {
        shortcuts.first { $0.matches(event) }
    }
}

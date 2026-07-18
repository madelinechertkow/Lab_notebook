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
    /// The full standard macOS Option and Option+Shift character layer (US keyboard) — every
    /// combo that inserts a single printable character. These already work natively in any
    /// text field without this feature; they're seeded here as editable defaults so the
    /// override mechanism has a familiar, non-surprising starting point that the user can then
    /// remap or add to. Dead-key combos (Option+E, Option+U, etc., which start an accent and
    /// wait for a second keystroke rather than inserting anything themselves) are excluded,
    /// since they don't fit this insert-one-character-per-shortcut model.
    static let defaults: [SpecialCharacterShortcut] = optionKeyDefaults + greekAndScienceDefaults

    private static let optionKeyDefaults: [SpecialCharacterShortcut] = [
        // Option + letter
        SpecialCharacterShortcut(key: "a", option: true, insertText: "å", label: "A with ring above"),
        SpecialCharacterShortcut(key: "b", option: true, insertText: "∫", label: "Integral"),
        SpecialCharacterShortcut(key: "c", option: true, insertText: "ç", label: "C with cedilla"),
        SpecialCharacterShortcut(key: "d", option: true, insertText: "∂", label: "Partial derivative"),
        SpecialCharacterShortcut(key: "f", option: true, insertText: "ƒ", label: "Florin sign"),
        SpecialCharacterShortcut(key: "g", option: true, insertText: "©", label: "Copyright sign"),
        SpecialCharacterShortcut(key: "j", option: true, insertText: "∆", label: "Delta"),
        SpecialCharacterShortcut(key: "l", option: true, insertText: "¬", label: "Not sign"),
        SpecialCharacterShortcut(key: "m", option: true, insertText: "µ", label: "Micro"),
        SpecialCharacterShortcut(key: "o", option: true, insertText: "ø", label: "O with stroke"),
        SpecialCharacterShortcut(key: "p", option: true, insertText: "π", label: "Pi"),
        SpecialCharacterShortcut(key: "q", option: true, insertText: "œ", label: "OE ligature"),
        SpecialCharacterShortcut(key: "r", option: true, insertText: "®", label: "Registered sign"),
        SpecialCharacterShortcut(key: "s", option: true, insertText: "ß", label: "Sharp s (eszett)"),
        SpecialCharacterShortcut(key: "t", option: true, insertText: "†", label: "Dagger"),
        SpecialCharacterShortcut(key: "v", option: true, insertText: "√", label: "Square root"),
        SpecialCharacterShortcut(key: "w", option: true, insertText: "∑", label: "N-ary summation"),
        SpecialCharacterShortcut(key: "x", option: true, insertText: "≈", label: "Approximately"),
        SpecialCharacterShortcut(key: "y", option: true, insertText: "¥", label: "Yen sign"),
        SpecialCharacterShortcut(key: "z", option: true, insertText: "Ω", label: "Ohm / Omega"),

        // Option + Shift + letter
        SpecialCharacterShortcut(key: "A", option: true, shift: true, insertText: "Å", label: "A with ring above (capital)"),
        SpecialCharacterShortcut(key: "B", option: true, shift: true, insertText: "ı", label: "Dotless i"),
        SpecialCharacterShortcut(key: "C", option: true, shift: true, insertText: "Ç", label: "C with cedilla (capital)"),
        SpecialCharacterShortcut(key: "O", option: true, shift: true, insertText: "Ø", label: "O with stroke (capital)"),
        SpecialCharacterShortcut(key: "P", option: true, shift: true, insertText: "∏", label: "N-ary product"),
        SpecialCharacterShortcut(key: "Q", option: true, shift: true, insertText: "Œ", label: "OE ligature (capital)"),
        SpecialCharacterShortcut(key: "V", option: true, shift: true, insertText: "◊", label: "Lozenge"),
        SpecialCharacterShortcut(key: "W", option: true, shift: true, insertText: "„", label: "Low double quote"),

        // Option + number
        SpecialCharacterShortcut(key: "1", option: true, insertText: "¡", label: "Inverted exclamation mark"),
        SpecialCharacterShortcut(key: "2", option: true, insertText: "™", label: "Trademark sign"),
        SpecialCharacterShortcut(key: "3", option: true, insertText: "£", label: "Pound sterling"),
        SpecialCharacterShortcut(key: "4", option: true, insertText: "¢", label: "Cent sign"),
        SpecialCharacterShortcut(key: "5", option: true, insertText: "∞", label: "Infinity"),
        SpecialCharacterShortcut(key: "6", option: true, insertText: "§", label: "Section sign"),
        SpecialCharacterShortcut(key: "7", option: true, insertText: "¶", label: "Pilcrow / paragraph mark"),
        SpecialCharacterShortcut(key: "8", option: true, insertText: "•", label: "Bullet"),
        SpecialCharacterShortcut(key: "9", option: true, insertText: "ª", label: "Feminine ordinal indicator"),
        SpecialCharacterShortcut(key: "0", option: true, insertText: "º", label: "Masculine ordinal indicator"),

        // Option + Shift + number
        SpecialCharacterShortcut(key: "!", option: true, shift: true, insertText: "⁄", label: "Fraction slash"),
        SpecialCharacterShortcut(key: "@", option: true, shift: true, insertText: "€", label: "Euro sign"),
        SpecialCharacterShortcut(key: "#", option: true, shift: true, insertText: "‹", label: "Single left angle quote"),
        SpecialCharacterShortcut(key: "$", option: true, shift: true, insertText: "›", label: "Single right angle quote"),
        SpecialCharacterShortcut(key: "%", option: true, shift: true, insertText: "ﬁ", label: "Fi ligature"),
        SpecialCharacterShortcut(key: "^", option: true, shift: true, insertText: "ﬂ", label: "Fl ligature"),
        SpecialCharacterShortcut(key: "&", option: true, shift: true, insertText: "‡", label: "Double dagger"),
        SpecialCharacterShortcut(key: "*", option: true, shift: true, insertText: "°", label: "Degree"),
        SpecialCharacterShortcut(key: "(", option: true, shift: true, insertText: "‰", label: "Per mille sign"),

        // Option + punctuation
        SpecialCharacterShortcut(key: "-", option: true, insertText: "–", label: "En dash"),
        SpecialCharacterShortcut(key: "=", option: true, insertText: "≠", label: "Not equal"),
        SpecialCharacterShortcut(key: "[", option: true, insertText: "“", label: "Opening double quote"),
        SpecialCharacterShortcut(key: "]", option: true, insertText: "‘", label: "Opening single quote"),
        SpecialCharacterShortcut(key: "\\", option: true, insertText: "«", label: "Left guillemet"),
        SpecialCharacterShortcut(key: ";", option: true, insertText: "…", label: "Ellipsis"),
        SpecialCharacterShortcut(key: "'", option: true, insertText: "æ", label: "AE ligature"),
        SpecialCharacterShortcut(key: ",", option: true, insertText: "≤", label: "Less than or equal"),
        SpecialCharacterShortcut(key: ".", option: true, insertText: "≥", label: "Greater than or equal"),
        SpecialCharacterShortcut(key: "/", option: true, insertText: "÷", label: "Divide"),

        // Option + Shift + punctuation
        SpecialCharacterShortcut(key: "_", option: true, shift: true, insertText: "—", label: "Em dash"),
        SpecialCharacterShortcut(key: "+", option: true, shift: true, insertText: "±", label: "Plus-minus"),
        SpecialCharacterShortcut(key: "{", option: true, shift: true, insertText: "”", label: "Closing double quote"),
        SpecialCharacterShortcut(key: "}", option: true, shift: true, insertText: "’", label: "Closing single quote"),
        SpecialCharacterShortcut(key: "|", option: true, shift: true, insertText: "»", label: "Right guillemet"),
        SpecialCharacterShortcut(key: "\"", option: true, shift: true, insertText: "Æ", label: "AE ligature (capital)"),
        SpecialCharacterShortcut(key: "?", option: true, shift: true, insertText: "¿", label: "Inverted question mark"),
    ]

    /// Greek has no native Option-key layer on a US keyboard the way accented letters and
    /// math symbols above do, so this uses Control+Option instead — free of collisions with
    /// every combo above. The letter assigned to each Greek character is the same one macOS's
    /// own "Greek" keyboard input source puts on that physical QWERTY key (e.g. its G key
    /// types γ, its P key types π), so this is still a real system mapping, just gated behind
    /// an extra modifier rather than a full input-source switch. "Q" has no Greek letter under
    /// that layout, so it's repurposed for the logic quantifiers (∀/∃) instead. Uppercase
    /// (Control+Option+Shift) mirrors the same key-to-letter assignment, capitalized; W and S
    /// both produce Σ since sigma's final form (ς, on W) and medial form (σ, on S) share one
    /// capital letter in Greek.
    fileprivate static let greekAndScienceDefaults: [SpecialCharacterShortcut] = [
        // Control + Option + letter (lowercase Greek)
        SpecialCharacterShortcut(key: "a", option: true, control: true, insertText: "α", label: "Greek alpha"),
        SpecialCharacterShortcut(key: "b", option: true, control: true, insertText: "β", label: "Greek beta"),
        SpecialCharacterShortcut(key: "c", option: true, control: true, insertText: "ψ", label: "Greek psi"),
        SpecialCharacterShortcut(key: "d", option: true, control: true, insertText: "δ", label: "Greek delta"),
        SpecialCharacterShortcut(key: "e", option: true, control: true, insertText: "ε", label: "Greek epsilon"),
        SpecialCharacterShortcut(key: "f", option: true, control: true, insertText: "φ", label: "Greek phi"),
        SpecialCharacterShortcut(key: "g", option: true, control: true, insertText: "γ", label: "Greek gamma"),
        SpecialCharacterShortcut(key: "h", option: true, control: true, insertText: "η", label: "Greek eta"),
        SpecialCharacterShortcut(key: "i", option: true, control: true, insertText: "ι", label: "Greek iota"),
        SpecialCharacterShortcut(key: "j", option: true, control: true, insertText: "ξ", label: "Greek xi"),
        SpecialCharacterShortcut(key: "k", option: true, control: true, insertText: "κ", label: "Greek kappa"),
        SpecialCharacterShortcut(key: "l", option: true, control: true, insertText: "λ", label: "Greek lambda"),
        SpecialCharacterShortcut(key: "m", option: true, control: true, insertText: "μ", label: "Greek mu"),
        SpecialCharacterShortcut(key: "n", option: true, control: true, insertText: "ν", label: "Greek nu"),
        SpecialCharacterShortcut(key: "o", option: true, control: true, insertText: "ο", label: "Greek omicron"),
        SpecialCharacterShortcut(key: "p", option: true, control: true, insertText: "π", label: "Greek pi"),
        SpecialCharacterShortcut(key: "r", option: true, control: true, insertText: "ρ", label: "Greek rho"),
        SpecialCharacterShortcut(key: "s", option: true, control: true, insertText: "σ", label: "Greek sigma"),
        SpecialCharacterShortcut(key: "t", option: true, control: true, insertText: "τ", label: "Greek tau"),
        SpecialCharacterShortcut(key: "u", option: true, control: true, insertText: "θ", label: "Greek theta"),
        SpecialCharacterShortcut(key: "v", option: true, control: true, insertText: "ω", label: "Greek omega"),
        SpecialCharacterShortcut(key: "w", option: true, control: true, insertText: "ς", label: "Greek final sigma"),
        SpecialCharacterShortcut(key: "x", option: true, control: true, insertText: "χ", label: "Greek chi"),
        SpecialCharacterShortcut(key: "y", option: true, control: true, insertText: "υ", label: "Greek upsilon"),
        SpecialCharacterShortcut(key: "z", option: true, control: true, insertText: "ζ", label: "Greek zeta"),
        SpecialCharacterShortcut(key: "q", option: true, control: true, insertText: "∀", label: "For all"),

        // Control + Option + Shift + letter (uppercase Greek)
        SpecialCharacterShortcut(key: "A", option: true, control: true, shift: true, insertText: "Α", label: "Greek Alpha (capital)"),
        SpecialCharacterShortcut(key: "B", option: true, control: true, shift: true, insertText: "Β", label: "Greek Beta (capital)"),
        SpecialCharacterShortcut(key: "C", option: true, control: true, shift: true, insertText: "Ψ", label: "Greek Psi (capital)"),
        SpecialCharacterShortcut(key: "D", option: true, control: true, shift: true, insertText: "Δ", label: "Greek Delta (capital)"),
        SpecialCharacterShortcut(key: "E", option: true, control: true, shift: true, insertText: "Ε", label: "Greek Epsilon (capital)"),
        SpecialCharacterShortcut(key: "F", option: true, control: true, shift: true, insertText: "Φ", label: "Greek Phi (capital)"),
        SpecialCharacterShortcut(key: "G", option: true, control: true, shift: true, insertText: "Γ", label: "Greek Gamma (capital)"),
        SpecialCharacterShortcut(key: "H", option: true, control: true, shift: true, insertText: "Η", label: "Greek Eta (capital)"),
        SpecialCharacterShortcut(key: "I", option: true, control: true, shift: true, insertText: "Ι", label: "Greek Iota (capital)"),
        SpecialCharacterShortcut(key: "J", option: true, control: true, shift: true, insertText: "Ξ", label: "Greek Xi (capital)"),
        SpecialCharacterShortcut(key: "K", option: true, control: true, shift: true, insertText: "Κ", label: "Greek Kappa (capital)"),
        SpecialCharacterShortcut(key: "L", option: true, control: true, shift: true, insertText: "Λ", label: "Greek Lambda (capital)"),
        SpecialCharacterShortcut(key: "M", option: true, control: true, shift: true, insertText: "Μ", label: "Greek Mu (capital)"),
        SpecialCharacterShortcut(key: "N", option: true, control: true, shift: true, insertText: "Ν", label: "Greek Nu (capital)"),
        SpecialCharacterShortcut(key: "O", option: true, control: true, shift: true, insertText: "Ο", label: "Greek Omicron (capital)"),
        SpecialCharacterShortcut(key: "P", option: true, control: true, shift: true, insertText: "Π", label: "Greek Pi (capital)"),
        SpecialCharacterShortcut(key: "R", option: true, control: true, shift: true, insertText: "Ρ", label: "Greek Rho (capital)"),
        SpecialCharacterShortcut(key: "S", option: true, control: true, shift: true, insertText: "Σ", label: "Greek Sigma (capital)"),
        SpecialCharacterShortcut(key: "T", option: true, control: true, shift: true, insertText: "Τ", label: "Greek Tau (capital)"),
        SpecialCharacterShortcut(key: "U", option: true, control: true, shift: true, insertText: "Θ", label: "Greek Theta (capital)"),
        SpecialCharacterShortcut(key: "V", option: true, control: true, shift: true, insertText: "Ω", label: "Greek Omega (capital)"),
        SpecialCharacterShortcut(key: "W", option: true, control: true, shift: true, insertText: "Σ", label: "Greek Sigma (capital, from final sigma)"),
        SpecialCharacterShortcut(key: "X", option: true, control: true, shift: true, insertText: "Χ", label: "Greek Chi (capital)"),
        SpecialCharacterShortcut(key: "Y", option: true, control: true, shift: true, insertText: "Υ", label: "Greek Upsilon (capital)"),
        SpecialCharacterShortcut(key: "Z", option: true, control: true, shift: true, insertText: "Ζ", label: "Greek Zeta (capital)"),
        SpecialCharacterShortcut(key: "Q", option: true, control: true, shift: true, insertText: "∃", label: "There exists"),

        // Control + Option + number (arrows and other common science symbols)
        SpecialCharacterShortcut(key: "1", option: true, control: true, insertText: "→", label: "Right arrow"),
        SpecialCharacterShortcut(key: "2", option: true, control: true, insertText: "←", label: "Left arrow"),
        SpecialCharacterShortcut(key: "3", option: true, control: true, insertText: "↑", label: "Up arrow"),
        SpecialCharacterShortcut(key: "4", option: true, control: true, insertText: "↓", label: "Down arrow"),
        SpecialCharacterShortcut(key: "5", option: true, control: true, insertText: "↔", label: "Left-right arrow"),
        SpecialCharacterShortcut(key: "6", option: true, control: true, insertText: "⇌", label: "Chemical equilibrium arrows"),
        SpecialCharacterShortcut(key: "7", option: true, control: true, insertText: "×", label: "Multiplication sign"),
        SpecialCharacterShortcut(key: "8", option: true, control: true, insertText: "∈", label: "Element of"),
        SpecialCharacterShortcut(key: "9", option: true, control: true, insertText: "∇", label: "Nabla / gradient"),
        SpecialCharacterShortcut(key: "0", option: true, control: true, insertText: "∅", label: "Empty set"),
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
            // Someone who already had a shortcuts.json before the Greek/science batch was
            // added won't otherwise ever see it (the `.defaults` fallback below only applies
            // to a fresh install). Add just those new combos if the saved file predates them —
            // scoped to that one batch, not all of `.defaults`, so a combo the user deliberately
            // deleted from the *original* set doesn't get silently resurrected.
            shortcuts = Self.addingMissingCombos(SpecialCharacterShortcut.greekAndScienceDefaults, to: decoded)
        } else {
            shortcuts = SpecialCharacterShortcut.defaults
        }
    }

    private static func addingMissingCombos(_ additions: [SpecialCharacterShortcut], to existing: [SpecialCharacterShortcut]) -> [SpecialCharacterShortcut] {
        func comboKey(_ s: SpecialCharacterShortcut) -> String {
            "\(s.key)|\(s.command)|\(s.option)|\(s.control)|\(s.shift)"
        }
        let existingCombos = Set(existing.map(comboKey))
        let missing = additions.filter { !existingCombos.contains(comboKey($0)) }
        return existing + missing
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

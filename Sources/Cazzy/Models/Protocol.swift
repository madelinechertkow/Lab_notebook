import Foundation

/// What kind of thing a material is, so the Materials list can be grouped. `.uncategorized`
/// is what every material saved before categories existed decodes to.
enum MaterialCategory: String, Codable, CaseIterable, Identifiable {
    case chemicals, antibodies, biological, kits, consumables, equipment, software, other
    case uncategorized

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chemicals: return "Chemicals & Reagents"
        case .antibodies: return "Antibodies"
        case .biological: return "Cells & Biological"
        case .kits: return "Kits"
        case .consumables: return "Consumables"
        case .equipment: return "Equipment & Machines"
        case .software: return "Software"
        case .other: return "Other"
        case .uncategorized: return "Uncategorized"
        }
    }

    var systemImage: String {
        switch self {
        case .chemicals: return "flask"
        case .antibodies: return "y.circle"
        case .biological: return "allergens"
        case .kits: return "shippingbox"
        case .consumables: return "testtube.2"
        case .equipment: return "gearshape.2"
        case .software: return "desktopcomputer"
        case .other: return "square.grid.2x2"
        case .uncategorized: return "questionmark.circle"
        }
    }
}

struct Reagent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var unit: String
    var notes: String = ""
    var category: MaterialCategory = .uncategorized

    init(id: UUID = UUID(), name: String, amount: String = "", unit: String = "", notes: String = "", category: MaterialCategory = .uncategorized) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.notes = notes
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case id, name, amount, unit, notes, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""
        unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        // An unknown raw value (e.g. from a newer Cazzy) falls back rather than failing the load.
        category = (try? container.decodeIfPresent(MaterialCategory.self, forKey: .category)) ?? .uncategorized
    }
}

extension Array where Element == Reagent {
    /// Materials grouped by category in `MaterialCategory.allCases` order (uncategorized last),
    /// keeping the user's order within each group. Empty groups are left out.
    var groupedByCategory: [(category: MaterialCategory, reagents: [Reagent])] {
        MaterialCategory.allCases.compactMap { category in
            let members = filter { $0.category == category }
            return members.isEmpty ? nil : (category, members)
        }
    }

    /// True when grouping would add nothing — every material is still uncategorized — so
    /// views can skip the group headings and look exactly as they did before categories.
    var isUncategorized: Bool { allSatisfy { $0.category == .uncategorized } }
}

/// One ingredient of a `BufferRecipe`. Concentrations are free text ("1 M", "50 mM", "10X",
/// "0.5 mg/mL") so nothing is lost if `BufferMath` can't parse them; it only uses them to
/// suggest an amount when `amount` is left blank.
struct BufferComponent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var stockConcentration: String = ""
    var finalConcentration: String = ""
    /// What the user typed for "amount to add". Empty means "use the calculated amount".
    var amount: String = ""

    init(id: UUID = UUID(), name: String = "", stockConcentration: String = "", finalConcentration: String = "", amount: String = "") {
        self.id = id
        self.name = name
        self.stockConcentration = stockConcentration
        self.finalConcentration = finalConcentration
        self.amount = amount
    }

    enum CodingKeys: String, CodingKey {
        case id, name, stockConcentration, finalConcentration, amount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        stockConcentration = try container.decodeIfPresent(String.self, forKey: .stockConcentration) ?? ""
        finalConcentration = try container.decodeIfPresent(String.self, forKey: .finalConcentration) ?? ""
        amount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""
    }
}

/// How to make a buffer or solution the protocol needs — an optional section shown before
/// Materials & Reagents. A protocol with no buffers simply has an empty `buffers` array.
struct BufferRecipe: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    /// Total volume to make, e.g. "500 mL" — what component amounts are calculated against.
    var finalVolume: String = ""
    /// What to bring the buffer up to volume with, e.g. "Milli-Q water".
    var solvent: String = ""
    var components: [BufferComponent] = []
    /// Free-form preparation notes: pH adjustment, filtering, autoclaving, storage.
    var instructions: String = ""

    init(id: UUID = UUID(), name: String = "", finalVolume: String = "", solvent: String = "", components: [BufferComponent] = [], instructions: String = "") {
        self.id = id
        self.name = name
        self.finalVolume = finalVolume
        self.solvent = solvent
        self.components = components
        self.instructions = instructions
    }

    enum CodingKeys: String, CodingKey {
        case id, name, finalVolume, solvent, components, instructions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        finalVolume = try container.decodeIfPresent(String.self, forKey: .finalVolume) ?? ""
        solvent = try container.decodeIfPresent(String.self, forKey: .solvent) ?? ""
        components = try container.decodeIfPresent([BufferComponent].self, forKey: .components) ?? []
        instructions = try container.decodeIfPresent(String.self, forKey: .instructions) ?? ""
    }

    /// The amount to show for a component: what the user typed, else the calculated amount.
    func displayAmount(for component: BufferComponent) -> String {
        let typed = component.amount.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }
        return BufferMath.amountToAdd(stock: component.stockConcentration, final: component.finalConcentration, totalVolume: finalVolume) ?? ""
    }

    /// Roughly how much solvent is needed to reach `finalVolume`, when every component's amount
    /// is a liquid volume. nil when that can't be worked out (e.g. a powder measured in grams).
    var solventVolume: String? {
        BufferMath.remainingVolume(total: finalVolume, components: components.map(displayAmount(for:)))
    }
}

/// Whether a `ProtocolStep` is an actual numbered procedure step, a standalone callout
/// (not numbered) meant to interrupt the flow and catch the reader's eye, or a section
/// heading that groups the steps after it (numbering restarts under each section).
enum StepKind: String, Codable, CaseIterable, Equatable {
    case step
    case note
    case warning
    case section

    var label: String {
        switch self {
        case .step: return "Step"
        case .note: return "Note"
        case .warning: return "Warning"
        case .section: return "Section"
        }
    }
}

extension Array where Element == ProtocolStep {
    /// The number shown beside each element — 0 for anything that isn't a numbered step.
    /// Numbering restarts after every section heading, so each section reads 1, 2, 3…
    var stepNumbers: [Int] {
        var counter = 0
        return map { step in
            switch step.kind {
            case .section:
                counter = 0
                return 0
            case .step:
                counter += 1
                return counter
            case .note, .warning:
                return 0
            }
        }
    }
}

/// How much a numbered step (`StepKind.step`) should stand out to the reader.
enum StepImportance: String, Codable, CaseIterable, Equatable {
    case normal
    case important
    case critical

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .important: return "Important"
        case .critical: return "Critical"
        }
    }
}

/// A small grid attached to a step — a plate layout, a dilution series, a PCR mix. All cells
/// are free text; `DilutionMath` can fill one in, but after that it's just an editable table.
struct StepTable: Codable, Equatable {
    var title: String = ""
    var columns: [String]
    var rows: [[String]]

    init(title: String = "", columns: [String], rows: [[String]]) {
        self.title = title
        self.columns = columns
        self.rows = rows
    }

    static func blank(columns: Int = 3, rows: Int = 2) -> StepTable {
        StepTable(columns: Array(repeating: "", count: columns), rows: Array(repeating: Array(repeating: "", count: columns), count: rows))
    }

    enum CodingKeys: String, CodingKey {
        case title, columns, rows
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        columns = try container.decodeIfPresent([String].self, forKey: .columns) ?? []
        // Pad/trim every row to the column count so views can index cells without checking.
        let decodedRows = try container.decodeIfPresent([[String]].self, forKey: .rows) ?? []
        let width = columns.count
        rows = decodedRows.map { row in
            Array((row + Array(repeating: "", count: max(0, width - row.count))).prefix(width))
        }
    }
}

struct ProtocolStep: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var durationMinutes: Int?
    var temperatureCelsius: Double?
    var notes: String = ""
    var kind: StepKind = .step
    var importance: StepImportance = .normal
    /// Optional table shown under the step (e.g. a dilution series).
    var table: StepTable?

    init(
        id: UUID = UUID(),
        text: String,
        durationMinutes: Int? = nil,
        temperatureCelsius: Double? = nil,
        notes: String = "",
        kind: StepKind = .step,
        importance: StepImportance = .normal,
        table: StepTable? = nil
    ) {
        self.id = id
        self.text = text
        self.durationMinutes = durationMinutes
        self.temperatureCelsius = temperatureCelsius
        self.notes = notes
        self.kind = kind
        self.importance = importance
        self.table = table
    }

    enum CodingKeys: String, CodingKey {
        case id, text, durationMinutes, temperatureCelsius, notes, kind, importance, table
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try container.decode(String.self, forKey: .text)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        temperatureCelsius = try container.decodeIfPresent(Double.self, forKey: .temperatureCelsius)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        kind = try container.decodeIfPresent(StepKind.self, forKey: .kind) ?? .step
        importance = try container.decodeIfPresent(StepImportance.self, forKey: .importance) ?? .normal
        table = try? container.decodeIfPresent(StepTable.self, forKey: .table)
    }
}

/// A frozen copy of a protocol's editable fields, captured either as saved version history
/// or as the payload of an exported `.cazzyprotocol` file.
struct ProtocolVersionSnapshot: Codable, Equatable {
    var name: String
    var purpose: String
    var buffers: [BufferRecipe]
    var reagents: [Reagent]
    var steps: [ProtocolStep]
    var tags: [String]
    var manualTotalMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case name, purpose, buffers, reagents, steps, tags, manualTotalMinutes
    }

    init(name: String, purpose: String = "", buffers: [BufferRecipe] = [], reagents: [Reagent] = [], steps: [ProtocolStep] = [], tags: [String] = [], manualTotalMinutes: Int? = nil) {
        self.name = name
        self.purpose = purpose
        self.buffers = buffers
        self.reagents = reagents
        self.steps = steps
        self.tags = tags
        self.manualTotalMinutes = manualTotalMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        buffers = try container.decodeIfPresent([BufferRecipe].self, forKey: .buffers) ?? []
        reagents = try container.decodeIfPresent([Reagent].self, forKey: .reagents) ?? []
        steps = try container.decodeIfPresent([ProtocolStep].self, forKey: .steps) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        manualTotalMinutes = try container.decodeIfPresent(Int.self, forKey: .manualTotalMinutes)
    }
}

struct ProtocolVersion: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var versionNumber: Int
    var savedAt: Date = Date()
    var changeNote: String = ""
    var snapshot: ProtocolVersionSnapshot

    init(id: UUID = UUID(), versionNumber: Int, savedAt: Date = Date(), changeNote: String = "", snapshot: ProtocolVersionSnapshot) {
        self.id = id
        self.versionNumber = versionNumber
        self.savedAt = savedAt
        self.changeNote = changeNote
        self.snapshot = snapshot
    }

    enum CodingKeys: String, CodingKey {
        case id, versionNumber, savedAt, changeNote, snapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        versionNumber = try container.decode(Int.self, forKey: .versionNumber)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        changeNote = try container.decodeIfPresent(String.self, forKey: .changeNote) ?? ""
        snapshot = try container.decode(ProtocolVersionSnapshot.self, forKey: .snapshot)
    }
}

/// A structured, versioned lab protocol. Named `LabProtocol` (not `Protocol`) to avoid
/// colliding with Swift's built-in `Protocol` type.
struct LabProtocol: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var purpose: String = ""
    /// Optional buffer/solution recipes, shown before Materials & Reagents.
    var buffers: [BufferRecipe] = []
    var reagents: [Reagent] = []
    var steps: [ProtocolStep] = []
    var tags: [String] = []
    /// User-entered total time override for scheduling; nil means "use the step-duration sum".
    var manualTotalMinutes: Int?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Saved version history. The fields above are the live, editable draft;
    /// "Save New Version" snapshots them into this array.
    var versions: [ProtocolVersion] = []
    /// 0 means the protocol has never been explicitly versioned yet.
    var currentVersionNumber: Int = 0

    init(
        id: UUID = UUID(),
        name: String,
        purpose: String = "",
        buffers: [BufferRecipe] = [],
        reagents: [Reagent] = [],
        steps: [ProtocolStep] = [],
        tags: [String] = [],
        manualTotalMinutes: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        versions: [ProtocolVersion] = [],
        currentVersionNumber: Int = 0
    ) {
        self.id = id
        self.name = name
        self.purpose = purpose
        self.buffers = buffers
        self.reagents = reagents
        self.steps = steps
        self.tags = tags
        self.manualTotalMinutes = manualTotalMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.versions = versions
        self.currentVersionNumber = currentVersionNumber
    }

    enum CodingKeys: String, CodingKey {
        case id, name, purpose, buffers, reagents, steps, tags, manualTotalMinutes, createdAt, updatedAt, versions, currentVersionNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        buffers = try container.decodeIfPresent([BufferRecipe].self, forKey: .buffers) ?? []
        reagents = try container.decodeIfPresent([Reagent].self, forKey: .reagents) ?? []
        steps = try container.decodeIfPresent([ProtocolStep].self, forKey: .steps) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        manualTotalMinutes = try container.decodeIfPresent(Int.self, forKey: .manualTotalMinutes)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        versions = try container.decodeIfPresent([ProtocolVersion].self, forKey: .versions) ?? []
        currentVersionNumber = try container.decodeIfPresent(Int.self, forKey: .currentVersionNumber) ?? 0
    }

    var draftSnapshot: ProtocolVersionSnapshot {
        ProtocolVersionSnapshot(name: name, purpose: purpose, buffers: buffers, reagents: reagents, steps: steps, tags: tags, manualTotalMinutes: manualTotalMinutes)
    }

    /// Sum of the durations entered on numbered steps (notes/warnings excluded).
    var stepDurationSum: Int {
        steps.filter { $0.kind == .step }.compactMap(\.durationMinutes).reduce(0, +)
    }

    /// The duration used when scheduling this protocol: the manual override if set,
    /// otherwise the step-duration sum, or nil if neither gives a usable value.
    var effectiveTotalMinutes: Int? {
        if let manualTotalMinutes, manualTotalMinutes > 0 { return manualTotalMinutes }
        return stepDurationSum > 0 ? stepDurationSum : nil
    }
}

/// The on-disk export/import file format for sharing a protocol between Cazzy installs.
struct ProtocolPackage: Codable {
    static let currentFormatVersion = 1
    static let fileExtension = "cazzyprotocol"

    var formatVersion: Int = ProtocolPackage.currentFormatVersion
    var exportedAt: Date = Date()
    var protocolPayload: LabProtocol

    init(protocolPayload: LabProtocol) {
        self.formatVersion = ProtocolPackage.currentFormatVersion
        self.exportedAt = Date()
        self.protocolPayload = protocolPayload
    }

    enum CodingKeys: String, CodingKey {
        case formatVersion, exportedAt, protocolPayload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()
        protocolPayload = try container.decode(LabProtocol.self, forKey: .protocolPayload)
    }
}

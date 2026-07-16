import Foundation

struct Reagent: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var unit: String
    var notes: String = ""

    init(id: UUID = UUID(), name: String, amount: String = "", unit: String = "", notes: String = "") {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id, name, amount, unit, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        amount = try container.decodeIfPresent(String.self, forKey: .amount) ?? ""
        unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

/// Whether a `ProtocolStep` is an actual numbered procedure step, or a standalone callout
/// (not numbered) meant to interrupt the flow and catch the reader's eye.
enum StepKind: String, Codable, CaseIterable, Equatable {
    case step
    case note
    case warning

    var label: String {
        switch self {
        case .step: return "Step"
        case .note: return "Note"
        case .warning: return "Warning"
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

struct ProtocolStep: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var durationMinutes: Int?
    var temperatureCelsius: Double?
    var notes: String = ""
    var kind: StepKind = .step
    var importance: StepImportance = .normal

    init(
        id: UUID = UUID(),
        text: String,
        durationMinutes: Int? = nil,
        temperatureCelsius: Double? = nil,
        notes: String = "",
        kind: StepKind = .step,
        importance: StepImportance = .normal
    ) {
        self.id = id
        self.text = text
        self.durationMinutes = durationMinutes
        self.temperatureCelsius = temperatureCelsius
        self.notes = notes
        self.kind = kind
        self.importance = importance
    }

    enum CodingKeys: String, CodingKey {
        case id, text, durationMinutes, temperatureCelsius, notes, kind, importance
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
    }
}

/// A frozen copy of a protocol's editable fields, captured either as saved version history
/// or as the payload of an exported `.cazzyprotocol` file.
struct ProtocolVersionSnapshot: Codable, Equatable {
    var name: String
    var purpose: String
    var reagents: [Reagent]
    var steps: [ProtocolStep]
    var tags: [String]

    enum CodingKeys: String, CodingKey {
        case name, purpose, reagents, steps, tags
    }

    init(name: String, purpose: String = "", reagents: [Reagent] = [], steps: [ProtocolStep] = [], tags: [String] = []) {
        self.name = name
        self.purpose = purpose
        self.reagents = reagents
        self.steps = steps
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        reagents = try container.decodeIfPresent([Reagent].self, forKey: .reagents) ?? []
        steps = try container.decodeIfPresent([ProtocolStep].self, forKey: .steps) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
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
    var reagents: [Reagent] = []
    var steps: [ProtocolStep] = []
    var tags: [String] = []
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
        reagents: [Reagent] = [],
        steps: [ProtocolStep] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        versions: [ProtocolVersion] = [],
        currentVersionNumber: Int = 0
    ) {
        self.id = id
        self.name = name
        self.purpose = purpose
        self.reagents = reagents
        self.steps = steps
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.versions = versions
        self.currentVersionNumber = currentVersionNumber
    }

    enum CodingKeys: String, CodingKey {
        case id, name, purpose, reagents, steps, tags, createdAt, updatedAt, versions, currentVersionNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        reagents = try container.decodeIfPresent([Reagent].self, forKey: .reagents) ?? []
        steps = try container.decodeIfPresent([ProtocolStep].self, forKey: .steps) ?? []
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        versions = try container.decodeIfPresent([ProtocolVersion].self, forKey: .versions) ?? []
        currentVersionNumber = try container.decodeIfPresent(Int.self, forKey: .currentVersionNumber) ?? 0
    }

    var draftSnapshot: ProtocolVersionSnapshot {
        ProtocolVersionSnapshot(name: name, purpose: purpose, reagents: reagents, steps: steps, tags: tags)
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

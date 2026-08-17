import Foundation

/// The interpreter a note's ```exec code blocks run under. Set once per note, not per block.
enum ExecutionLanguage: String, Codable, CaseIterable, Identifiable {
    case python, r, bash

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .python: return "Python"
        case .r: return "R"
        case .bash: return "Bash"
        }
    }

    var symbol: String {
        switch self {
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .r: return "function"
        case .bash: return "terminal"
        }
    }

    /// The interpreter binary invoked (resolved against the user's login-shell PATH).
    var interpreterCommand: String {
        switch self {
        case .python: return "python3"
        case .r: return "Rscript"
        case .bash: return "bash"
        }
    }

    /// Extension used for the temp script file a block's code is written to before running.
    var fileExtension: String {
        switch self {
        case .python: return "py"
        case .r: return "R"
        case .bash: return "sh"
        }
    }
}

/// Interpreter version + installed-package listing captured at the time a block was run,
/// so the output can be traced back to the environment that produced it later.
struct EnvironmentSnapshot: Codable, Equatable {
    var interpreterVersion: String
    var packageList: String

    init(interpreterVersion: String = "", packageList: String = "") {
        self.interpreterVersion = interpreterVersion
        self.packageList = packageList
    }
}

/// The result of running one ```exec code block. Keyed by the block's stable short ID
/// (embedded in the fence's info string), not by position, so edits/reordering don't
/// disturb which result belongs to which block.
struct CodeBlockResult: Identifiable, Codable, Equatable {
    var id: String
    /// The code as it was at the moment of this run — compared against the block's current
    /// text to detect and flag a stale result rather than silently discarding it.
    var codeSnapshot: String
    var stdout: String
    var stderr: String
    var exitCode: Int32
    var startedAt: Date
    var durationSeconds: Double
    var environment: EnvironmentSnapshot

    enum CodingKeys: String, CodingKey {
        case id, codeSnapshot, stdout, stderr, exitCode, startedAt, durationSeconds, environment
    }

    init(
        id: String,
        codeSnapshot: String,
        stdout: String,
        stderr: String,
        exitCode: Int32,
        startedAt: Date,
        durationSeconds: Double,
        environment: EnvironmentSnapshot
    ) {
        self.id = id
        self.codeSnapshot = codeSnapshot
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.environment = environment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        codeSnapshot = try container.decodeIfPresent(String.self, forKey: .codeSnapshot) ?? ""
        stdout = try container.decodeIfPresent(String.self, forKey: .stdout) ?? ""
        stderr = try container.decodeIfPresent(String.self, forKey: .stderr) ?? ""
        exitCode = try container.decodeIfPresent(Int32.self, forKey: .exitCode) ?? 0
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        durationSeconds = try container.decodeIfPresent(Double.self, forKey: .durationSeconds) ?? 0
        environment = try container.decodeIfPresent(EnvironmentSnapshot.self, forKey: .environment) ?? EnvironmentSnapshot()
    }
}

struct Note: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var notebookID: UUID
    var title: String
    var content: String
    var tags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    /// Determines display order (descending — highest first). Defaults to createdAt so
    /// notes are chronological (newest first) until manually dragged; editing a note never
    /// touches this, only a drag does, so entries don't reshuffle every time you save.
    var sortIndex: Double = Date().timeIntervalSinceReferenceDate
    /// nil means this note has no executable code blocks.
    var executionLanguage: ExecutionLanguage? = nil
    /// References a `CodeEnvironment` in the library (not a copy) — renaming/fixing an
    /// environment's activation command should apply to every note using it. nil means run
    /// under the default login shell with no activation step.
    var codeEnvironmentID: UUID? = nil
    /// Keyed by block ID (see `ExecBlockParser`).
    var codeBlockResults: [String: CodeBlockResult] = [:]
    /// Keyed by block ID — each is a self-contained copy, not a live reference to a
    /// `PlateMapTemplate`, so editing it here never changes the library template.
    var plateMapResults: [String: PlateMapInstance] = [:]
    /// Keyed by block ID.
    var gelMapResults: [String: GelMapInstance] = [:]
    /// Archived notes are hidden from "All Notes" and their notebook's list, but not
    /// deleted — the reversible first step before a permanent deleteNote(_:).
    var isArchived: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, notebookID, title, content, tags, createdAt, updatedAt, sortIndex, executionLanguage, codeEnvironmentID, codeBlockResults, plateMapResults, gelMapResults, isArchived
    }

    init(
        id: UUID = UUID(),
        notebookID: UUID,
        title: String,
        content: String,
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        sortIndex: Double? = nil,
        executionLanguage: ExecutionLanguage? = nil,
        codeEnvironmentID: UUID? = nil,
        codeBlockResults: [String: CodeBlockResult] = [:],
        plateMapResults: [String: PlateMapInstance] = [:],
        gelMapResults: [String: GelMapInstance] = [:],
        isArchived: Bool = false
    ) {
        self.id = id
        self.notebookID = notebookID
        self.title = title
        self.content = content
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex ?? createdAt.timeIntervalSinceReferenceDate
        self.executionLanguage = executionLanguage
        self.codeEnvironmentID = codeEnvironmentID
        self.codeBlockResults = codeBlockResults
        self.plateMapResults = plateMapResults
        self.gelMapResults = gelMapResults
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        notebookID = try container.decode(UUID.self, forKey: .notebookID)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        sortIndex = try container.decodeIfPresent(Double.self, forKey: .sortIndex) ?? createdAt.timeIntervalSinceReferenceDate
        executionLanguage = try container.decodeIfPresent(ExecutionLanguage.self, forKey: .executionLanguage)
        codeEnvironmentID = try container.decodeIfPresent(UUID.self, forKey: .codeEnvironmentID)
        codeBlockResults = try container.decodeIfPresent([String: CodeBlockResult].self, forKey: .codeBlockResults) ?? [:]
        plateMapResults = try container.decodeIfPresent([String: PlateMapInstance].self, forKey: .plateMapResults) ?? [:]
        gelMapResults = try container.decodeIfPresent([String: GelMapInstance].self, forKey: .gelMapResults) ?? [:]
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    var wordCount: Int {
        content.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

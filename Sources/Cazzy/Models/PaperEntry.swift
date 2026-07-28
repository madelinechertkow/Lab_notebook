import Foundation

/// Mirrors the "Read Status" data-validation list from the original Paper_Tracker.xlsx.
enum PaperReadStatus: String, Codable, CaseIterable, Identifiable {
    case notRead = "Not Read"
    case skimmed = "Skimmed"
    case read = "Read"
    case deepRead = "Deep Read"

    var id: String { rawValue }
}

/// Mirrors the "Relevance to Project" data-validation list.
enum PaperRelevance: String, Codable, CaseIterable, Identifiable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { rawValue }
}

/// One row of the Paper Tracker spreadsheet. Field names and grouping follow the
/// IDENTIFICATION / METHODS & DATA / SCIENCE / PROJECT RELEVANCE / CITATION sections
/// of the original Paper_Tracker.xlsx so existing tracking habits carry over directly.
struct PaperEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    // IDENTIFICATION
    var dateAdded: Date = Date()
    var datePublished: String = ""
    var firstAuthor: String = ""
    var lastAuthor: String = ""
    var journal: String = ""
    var year: String = ""
    var title: String = ""
    var link: String = ""

    // METHODS & DATA
    var methods: String = ""
    var modelsUsed: String = ""
    var clinicalSamples: String = ""
    var modelOrganism: String = ""
    var sampleSize: String = ""
    var dataAvailability: String = ""
    var softwareTools: String = ""

    // SCIENCE
    var novelFinding: String = ""
    var summary: String = ""
    var figuresOfInterest: String = ""

    // PROJECT RELEVANCE
    var relevance: PaperRelevance?
    var projectNotes: String = ""
    var readStatus: PaperReadStatus = .notRead
    var tags: [String] = []
    var followUpNeeded: Bool = false

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case id, dateAdded, datePublished, firstAuthor, lastAuthor, journal, year, title, link,
             methods, modelsUsed, clinicalSamples, modelOrganism, sampleSize, dataAvailability, softwareTools,
             novelFinding, summary, figuresOfInterest,
             relevance, projectNotes, readStatus, tags, followUpNeeded, createdAt, updatedAt
    }

    init(
        id: UUID = UUID(),
        dateAdded: Date = Date(),
        datePublished: String = "",
        firstAuthor: String = "",
        lastAuthor: String = "",
        journal: String = "",
        year: String = "",
        title: String = "",
        link: String = "",
        methods: String = "",
        modelsUsed: String = "",
        clinicalSamples: String = "",
        modelOrganism: String = "",
        sampleSize: String = "",
        dataAvailability: String = "",
        softwareTools: String = "",
        novelFinding: String = "",
        summary: String = "",
        figuresOfInterest: String = "",
        relevance: PaperRelevance? = nil,
        projectNotes: String = "",
        readStatus: PaperReadStatus = .notRead,
        tags: [String] = [],
        followUpNeeded: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dateAdded = dateAdded
        self.datePublished = datePublished
        self.firstAuthor = firstAuthor
        self.lastAuthor = lastAuthor
        self.journal = journal
        self.year = year
        self.title = title
        self.link = link
        self.methods = methods
        self.modelsUsed = modelsUsed
        self.clinicalSamples = clinicalSamples
        self.modelOrganism = modelOrganism
        self.sampleSize = sampleSize
        self.dataAvailability = dataAvailability
        self.softwareTools = softwareTools
        self.novelFinding = novelFinding
        self.summary = summary
        self.figuresOfInterest = figuresOfInterest
        self.relevance = relevance
        self.projectNotes = projectNotes
        self.readStatus = readStatus
        self.tags = tags
        self.followUpNeeded = followUpNeeded
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        datePublished = try container.decodeIfPresent(String.self, forKey: .datePublished) ?? ""
        firstAuthor = try container.decodeIfPresent(String.self, forKey: .firstAuthor) ?? ""
        lastAuthor = try container.decodeIfPresent(String.self, forKey: .lastAuthor) ?? ""
        journal = try container.decodeIfPresent(String.self, forKey: .journal) ?? ""
        year = try container.decodeIfPresent(String.self, forKey: .year) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        link = try container.decodeIfPresent(String.self, forKey: .link) ?? ""
        methods = try container.decodeIfPresent(String.self, forKey: .methods) ?? ""
        modelsUsed = try container.decodeIfPresent(String.self, forKey: .modelsUsed) ?? ""
        clinicalSamples = try container.decodeIfPresent(String.self, forKey: .clinicalSamples) ?? ""
        modelOrganism = try container.decodeIfPresent(String.self, forKey: .modelOrganism) ?? ""
        sampleSize = try container.decodeIfPresent(String.self, forKey: .sampleSize) ?? ""
        dataAvailability = try container.decodeIfPresent(String.self, forKey: .dataAvailability) ?? ""
        softwareTools = try container.decodeIfPresent(String.self, forKey: .softwareTools) ?? ""
        novelFinding = try container.decodeIfPresent(String.self, forKey: .novelFinding) ?? ""
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        figuresOfInterest = try container.decodeIfPresent(String.self, forKey: .figuresOfInterest) ?? ""
        relevance = try container.decodeIfPresent(PaperRelevance.self, forKey: .relevance)
        projectNotes = try container.decodeIfPresent(String.self, forKey: .projectNotes) ?? ""
        readStatus = try container.decodeIfPresent(PaperReadStatus.self, forKey: .readStatus) ?? .notRead
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        followUpNeeded = try container.decodeIfPresent(Bool.self, forKey: .followUpNeeded) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Approximates Nature's reference style — "Author, A. & Author, B. Title. Journal (Year)."
    /// Author fields are used as entered (or already "Surname, Initials" formatted when filled
    /// in via PaperMetadataFetcher); volume/page numbers aren't tracked so they're simply
    /// omitted rather than guessed.
    var natureCitation: String {
        guard !firstAuthor.isEmpty else { return "" }
        var authors = firstAuthor
        if !lastAuthor.isEmpty { authors += " & \(lastAuthor)" }

        var parts: [String] = [authors]
        if !title.isEmpty {
            parts.append(title.hasSuffix(".") ? title : "\(title).")
        }
        if !journal.isEmpty || !year.isEmpty {
            var journalYear = journal
            if !year.isEmpty {
                journalYear += journalYear.isEmpty ? "(\(year))" : " (\(year))"
            }
            parts.append(journalYear)
        }

        var citation = parts.joined(separator: " ")
        if !citation.hasSuffix(".") { citation += "." }
        return citation
    }
}

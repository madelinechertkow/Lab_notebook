import Foundation

/// Bibliographic fields pulled from a paper's link — whichever ones the source actually had.
/// Missing fields stay nil so the caller can leave the corresponding form field untouched.
struct PaperMetadata {
    var title: String?
    var journal: String?
    var year: String?
    var datePublished: String?
    var firstAuthor: String?
    var lastAuthor: String?
}

enum PaperMetadataError: LocalizedError {
    case invalidLink
    case network(Error)
    case noMetadataFound

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "That doesn't look like a link."
        case .network:
            return "Couldn't reach the network to look up that link."
        case .noMetadataFound:
            return "Couldn't find paper details at that link."
        }
    }
}

/// Looks up a paper's title/authors/journal/year from just its link. Tries a DOI lookup via
/// CrossRef first (fast, structured, works for any link containing a DOI — which covers most
/// publisher and doi.org links); falls back to scraping the page's own `citation_*` meta tags
/// (the Highwire/Google-Scholar convention that Nature, Science, PubMed, bioRxiv, etc. all
/// embed) for links CrossRef can't resolve.
enum PaperMetadataFetcher {
    static func fetchMetadata(fromLink rawLink: String) async throws -> PaperMetadata {
        let trimmed = rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PaperMetadataError.invalidLink }

        if let doi = extractDOI(from: trimmed) {
            do {
                let metadata = try await fetchFromCrossRef(doi: doi)
                if metadata.title != nil {
                    return metadata
                }
            } catch {
                // Fall through to the HTML scrape below rather than failing outright —
                // CrossRef doesn't index every DOI (e.g. some preprint servers).
            }
        }

        guard let url = normalizedURL(from: trimmed) else { throw PaperMetadataError.invalidLink }
        let html: String
        do {
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("Cazzy/1.0 (macOS lab notebook app)", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)
            html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
        } catch {
            throw PaperMetadataError.network(error)
        }

        let metadata = parseCitationMetaTags(from: html)
        guard metadata.title != nil || metadata.journal != nil else {
            throw PaperMetadataError.noMetadataFound
        }
        return metadata
    }

    private static func normalizedURL(from raw: String) -> URL? {
        var candidate = raw
        if !candidate.lowercased().hasPrefix("http://") && !candidate.lowercased().hasPrefix("https://") {
            candidate = "https://" + candidate
        }
        return URL(string: candidate)
    }

    /// DOIs always look like "10.xxxx/suffix" — this pulls one out of a full URL
    /// (e.g. https://doi.org/10.1038/s41586-020-2649-2) or a bare DOI string alike.
    private static func extractDOI(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"10\.\d{4,9}/[^\s"'<>]+"#) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), let matchRange = Range(match.range, in: text) else {
            return nil
        }
        var doi = String(text[matchRange])
        while let last = doi.last, ".,;)]".contains(last) {
            doi.removeLast()
        }
        return doi.isEmpty ? nil : doi
    }

    private static func fetchFromCrossRef(doi: String) async throws -> PaperMetadata {
        guard let encodedDOI = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.crossref.org/works/\(encodedDOI)") else {
            throw PaperMetadataError.invalidLink
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Cazzy/1.0 (macOS lab notebook app)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw PaperMetadataError.network(error)
        }
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PaperMetadataError.noMetadataFound
        }

        let decoded: CrossRefResponse
        do {
            decoded = try JSONDecoder().decode(CrossRefResponse.self, from: data)
        } catch {
            throw PaperMetadataError.noMetadataFound
        }
        let work = decoded.message

        var metadata = PaperMetadata()
        metadata.title = work.title?.first
        metadata.journal = work.containerTitle?.first
        if let year = work.bestYear {
            metadata.year = String(year)
        }
        if let authors = work.author, !authors.isEmpty {
            metadata.firstAuthor = formatAuthorName(authors.first)
            if authors.count > 1 {
                metadata.lastAuthor = formatAuthorName(authors.last)
            }
        }
        return metadata
    }

    /// Nature-style author formatting: "Family, G." — falls back to whatever name fields
    /// CrossRef did provide (some entries, e.g. consortia, only have a plain "name").
    private static func formatAuthorName(_ author: CrossRefAuthor?) -> String? {
        guard let author else { return nil }
        guard let family = author.family, !family.isEmpty else { return author.name }
        guard let given = author.given, !given.isEmpty else { return family }
        let initials = given
            .split(separator: " ")
            .compactMap { $0.first }
            .map { "\($0)." }
            .joined(separator: " ")
        return "\(family), \(initials)"
    }

    private static func parseCitationMetaTags(from html: String) -> PaperMetadata {
        var metadata = PaperMetadata()
        metadata.title = firstMetaContent(named: "citation_title", in: html)
        metadata.journal = firstMetaContent(named: "citation_journal_title", in: html)

        if let dateString = firstMetaContent(named: "citation_publication_date", in: html)
            ?? firstMetaContent(named: "citation_date", in: html), dateString.count >= 4 {
            metadata.datePublished = dateString
            metadata.year = String(dateString.prefix(4))
        } else if let year = firstMetaContent(named: "citation_year", in: html) {
            metadata.year = year
        }

        // Most publishers (Nature, Science, bioRxiv…) repeat a singular "citation_author" tag
        // per author; PubMed instead emits one "citation_authors" tag, semicolon-joined.
        var authors = allMetaContents(named: "citation_author", in: html)
        if authors.isEmpty, let joined = firstMetaContent(named: "citation_authors", in: html) {
            authors = joined
                .split(separator: ";")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if !authors.isEmpty {
            metadata.firstAuthor = authors.first
            if authors.count > 1 {
                metadata.lastAuthor = authors.last
            }
        }
        return metadata
    }

    private static func firstMetaContent(named name: String, in html: String) -> String? {
        allMetaContents(named: name, in: html).first
    }

    /// Matches `<meta name="citation_title" content="...">` in either attribute order —
    /// publishers aren't consistent about which comes first.
    private static func allMetaContents(named name: String, in html: String) -> [String] {
        let escapedName = NSRegularExpression.escapedPattern(for: name)
        let patterns = [
            #"<meta[^>]+name=["']"# + escapedName + #"["'][^>]+content=["']([^"']*)["']"#,
            #"<meta[^>]+content=["']([^"']*)["'][^>]+name=["']"# + escapedName + #"["']"#
        ]
        var results: [String] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(html.startIndex..., in: html)
            regex.enumerateMatches(in: html, range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: html) else { return }
                results.append(decodeHTMLEntities(String(html[valueRange])))
            }
        }
        return results
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct CrossRefResponse: Decodable {
    let message: CrossRefWork
}

private struct CrossRefWork: Decodable {
    let title: [String]?
    let containerTitle: [String]?
    let author: [CrossRefAuthor]?
    let published: CrossRefDateParts?
    let publishedPrint: CrossRefDateParts?
    let publishedOnline: CrossRefDateParts?
    let issued: CrossRefDateParts?

    enum CodingKeys: String, CodingKey {
        case title, author, published, issued
        case containerTitle = "container-title"
        case publishedPrint = "published-print"
        case publishedOnline = "published-online"
    }

    var bestYear: Int? {
        published?.dateParts?.first?.first
            ?? publishedPrint?.dateParts?.first?.first
            ?? publishedOnline?.dateParts?.first?.first
            ?? issued?.dateParts?.first?.first
    }
}

private struct CrossRefAuthor: Decodable {
    let given: String?
    let family: String?
    let name: String?
}

private struct CrossRefDateParts: Decodable {
    let dateParts: [[Int]]?

    enum CodingKeys: String, CodingKey {
        case dateParts = "date-parts"
    }
}

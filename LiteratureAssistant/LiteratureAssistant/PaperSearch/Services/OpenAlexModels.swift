//
//  OpenAlexModels.swift
//  LiteratureAssistant · PaperSearch
//
//  Decodable mirrors of the parts of the OpenAlex JSON we use, plus mapping to `Paper`.
//  Every field is optional: OpenAlex omits or nulls many of them.
//  Explicit CodingKeys (not .convertFromSnakeCase) so the words inside
//  abstract_inverted_index are never rewritten.
//

import Foundation

nonisolated struct OpenAlexListResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        var count: Int?
        var page: Int?
        var perPage: Int?

        enum CodingKeys: String, CodingKey {
            case count, page
            case perPage = "per_page"
        }
    }

    var meta: Meta?
    var results: [Item]
}

nonisolated struct OpenAlexWork: Decodable, Sendable {
    var id: String?
    var doi: String?
    var title: String?
    var displayName: String?
    var publicationDate: String?
    var publicationYear: Int?
    var authorships: [Authorship]?
    var primaryLocation: Location?
    var citedByCount: Int?
    var abstractInvertedIndex: [String: [Int]]?

    struct Authorship: Decodable, Sendable {
        var author: Author?
        var rawAuthorName: String?

        enum CodingKeys: String, CodingKey {
            case author
            case rawAuthorName = "raw_author_name"
        }
    }

    struct Author: Decodable, Sendable {
        var displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    struct Location: Decodable, Sendable {
        var landingPageUrl: String?
        var source: Source?

        enum CodingKeys: String, CodingKey {
            case landingPageUrl = "landing_page_url"
            case source
        }
    }

    struct Source: Decodable, Sendable {
        var displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, doi, title, authorships
        case displayName = "display_name"
        case publicationDate = "publication_date"
        case publicationYear = "publication_year"
        case primaryLocation = "primary_location"
        case citedByCount = "cited_by_count"
        case abstractInvertedIndex = "abstract_inverted_index"
    }
}

/// An author or topic returned by /authors or /topics, used to resolve a name to an ID.
nonisolated struct OpenAlexEntity: Decodable, Sendable {
    var id: String
    var displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

/// Error body OpenAlex returns, e.g. {"error": "...", "message": "...", "reason": "query_timeout"}.
nonisolated struct OpenAlexErrorBody: Decodable, Sendable {
    var error: String?
    var message: String?
    var reason: String?
    var code: String?
}

// MARK: - Mapping

nonisolated enum OpenAlexMapper {
    /// "https://openalex.org/W123" → "W123". Leaves short IDs untouched.
    static func shortID(_ id: String) -> String {
        id.split(separator: "/").last.map(String.init) ?? id
    }

    /// "https://doi.org/10.1/ABC" → "10.1/ABC".
    static func bareDOI(_ doi: String?) -> String? {
        guard let doi, !doi.isEmpty else { return nil }
        return SearchMode.normalizeDOI(doi) ?? doi
    }

    /// Rebuilds plain text from OpenAlex's inverted index (word → positions).
    /// Returns nil for a missing or empty index.
    static func rebuildAbstract(from index: [String: [Int]]?) -> String? {
        guard let index, !index.isEmpty else { return nil }
        var positioned: [(Int, String)] = []
        positioned.reserveCapacity(index.values.reduce(0) { $0 + $1.count })
        for (word, positions) in index {
            for position in positions where position >= 0 {
                positioned.append((position, word))
            }
        }
        guard !positioned.isEmpty else { return nil }
        positioned.sort { $0.0 < $1.0 }
        let text = positioned.map(\.1).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return dateFormatter.date(from: value)
    }

    static func paper(from work: OpenAlexWork, retrievedAt: Date = .now) -> Paper? {
        guard let rawID = work.id, !rawID.isEmpty else { return nil }
        let shortID = shortID(rawID)
        let doi = bareDOI(work.doi)

        let title = [work.title, work.displayName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Untitled"

        let authors: [String] = (work.authorships ?? []).compactMap { authorship in
            let name = authorship.author?.displayName ?? authorship.rawAuthorName
            guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
            return name
        }

        let venue = work.primaryLocation?.source?.displayName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let publicationDate = parseDate(work.publicationDate)
        var year = work.publicationYear
        if year == nil, let publicationDate {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!
            year = calendar.component(.year, from: publicationDate)
        }

        let sourceUrl = [
            work.primaryLocation?.landingPageUrl,
            doi.map { "https://doi.org/\($0)" },
            rawID.hasPrefix("http") ? rawID : "https://openalex.org/\(shortID)",
        ].compactMap { $0 }.first { !$0.isEmpty }!

        return Paper(
            externalApiId: shortID,
            externalApiSource: Paper.openAlexSource,
            title: title,
            authors: authors,
            doi: doi,
            publicationDate: publicationDate,
            publicationYear: year,
            venue: (venue?.isEmpty ?? true) ? nil : venue,
            abstract: rebuildAbstract(from: work.abstractInvertedIndex),
            citationCount: work.citedByCount,
            sourceUrl: sourceUrl,
            retrievedAt: retrievedAt
        )
    }
}

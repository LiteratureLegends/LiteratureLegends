//
//  Paper.swift
//  LiteratureAssistant · PaperSearch
//
//  Mirrors the `Paper` table in readme.md. `fullText` is intentionally omitted
//  until the document-chat feature needs it.
//

import Foundation

nonisolated struct Paper: Codable, Identifiable, Hashable, Sendable {
    /// Identifier supplied by the external API (OpenAlex short ID, e.g. "W2741809807").
    var externalApiId: String
    /// Name of the API that supplied the record.
    var externalApiSource: String
    var title: String
    var authors: [String]
    /// Bare DOI such as "10.7717/peerj.4375" (no https://doi.org/ prefix).
    var doi: String?
    var publicationDate: Date?
    var publicationYear: Int?
    var venue: String?
    var abstract: String?
    var citationCount: Int?
    /// Link to the original paper record or source.
    var sourceUrl: String
    var retrievedAt: Date

    /// Until Parse assigns an internal objectId, the external ID is unique enough.
    var id: String { externalApiId }

    static let openAlexSource = "OpenAlex"

    init(
        externalApiId: String,
        externalApiSource: String = Paper.openAlexSource,
        title: String,
        authors: [String] = [],
        doi: String? = nil,
        publicationDate: Date? = nil,
        publicationYear: Int? = nil,
        venue: String? = nil,
        abstract: String? = nil,
        citationCount: Int? = nil,
        sourceUrl: String,
        retrievedAt: Date = .now
    ) {
        self.externalApiId = externalApiId
        self.externalApiSource = externalApiSource
        self.title = title
        self.authors = authors
        self.doi = doi
        self.publicationDate = publicationDate
        self.publicationYear = publicationYear
        self.venue = venue
        self.abstract = abstract
        self.citationCount = citationCount
        self.sourceUrl = sourceUrl
        self.retrievedAt = retrievedAt
    }
}

// MARK: - Display helpers

nonisolated extension Paper {
    /// "A, B, C et al." for lists; "et al." only when more than three authors exist.
    var shortAuthorList: String {
        guard !authors.isEmpty else { return "Unknown authors" }
        let shown = authors.prefix(3).joined(separator: ", ")
        return authors.count > 3 ? "\(shown) et al." : shown
    }

    /// `https://doi.org/<doi>` when a DOI is present.
    var doiURL: URL? {
        guard let doi, !doi.isEmpty else { return nil }
        return URL(string: "https://doi.org/\(doi)")
    }

    /// The best link to open in Safari: the source record, falling back to the DOI link.
    var openURL: URL? {
        if let url = URL(string: sourceUrl), url.scheme?.hasPrefix("http") == true { return url }
        return doiURL
    }

    /// Full date when known (formatted in UTC so it never shifts a day), else the year.
    var displayDate: String? {
        if let publicationDate {
            var style = Date.FormatStyle(date: .long, time: .omitted)
            style.timeZone = TimeZone(identifier: "UTC")!
            return publicationDate.formatted(style)
        }
        return publicationYear.map(String.init)
    }

    var displayYear: String? {
        if let publicationYear { return String(publicationYear) }
        guard let publicationDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return String(calendar.component(.year, from: publicationDate))
    }

    var citationText: String? {
        guard let citationCount else { return nil }
        return citationCount == 1 ? "1 citation" : "\(citationCount.formatted()) citations"
    }
}

//
//  MockPaperSearchService.swift
//  LiteratureAssistant · PaperSearch
//
//  In-memory PaperSearchService for SwiftUI previews. No networking.
//

import Foundation

nonisolated struct MockPaperSearchService: PaperSearchService {
    enum Behavior: Sendable {
        case results
        case empty
        case failure(PaperSearchError)
    }

    var behavior: Behavior = .results
    var delay: Duration = .milliseconds(300)
    var totalPages = 3

    func searchPapers(query: String, mode: SearchMode, page: Int) async throws -> PaperSearchPage {
        try await Task.sleep(for: delay)
        switch behavior {
        case .empty:
            return .empty(page: page)
        case .failure(let error):
            throw error
        case .results:
            let papers = (0..<OpenAlexService.pageSize).map { index in
                Self.samplePaper(number: (page - 1) * OpenAlexService.pageSize + index + 1, query: query)
            }
            return PaperSearchPage(
                papers: papers,
                totalCount: totalPages * OpenAlexService.pageSize,
                page: page,
                hasMore: page < totalPages,
                matchedEntityName: mode == .author ? "Ada Lovelace" : (mode == .topic ? "Machine Learning" : nil)
            )
        }
    }

    func getPaperDetails(id: String) async throws -> Paper {
        try await Task.sleep(for: delay)
        if case .failure(let error) = behavior { throw error }
        var paper = Self.sample
        paper.externalApiId = id
        return paper
    }

    static let sample = Paper(
        externalApiId: "W2741809807",
        title: "The state of OA: a large-scale analysis of the prevalence and impact of Open Access articles",
        authors: ["Heather Piwowar", "Jason Priem", "Vincent Larivière", "Juan Pablo Alperin", "Lisa Matthias"],
        doi: "10.7717/peerj.4375",
        publicationDate: OpenAlexMapper.parseDate("2018-02-13"),
        publicationYear: 2018,
        venue: "PeerJ",
        abstract: "Despite growing interest in Open Access (OA) to scholarly literature, there is an unmet need for large-scale, up-to-date, and reliable studies quantifying the prevalence of OA.",
        citationCount: 1487,
        sourceUrl: "https://doi.org/10.7717/peerj.4375"
    )

    static func samplePaper(number: Int, query: String) -> Paper {
        Paper(
            externalApiId: "W\(1000 + number)",
            title: "\(query.isEmpty ? "Sample" : query.capitalized) study #\(number)",
            authors: number.isMultiple(of: 3) ? ["Grace Hopper"] : ["Ada Lovelace", "Alan Turing", "Grace Hopper", "Katherine Johnson"],
            doi: number.isMultiple(of: 2) ? "10.1234/sample.\(number)" : nil,
            publicationYear: 2026 - number % 10,
            venue: number.isMultiple(of: 4) ? nil : "Journal of Examples",
            abstract: number.isMultiple(of: 5) ? nil : "A short sample abstract for preview purposes.",
            citationCount: 500 - number,
            sourceUrl: "https://openalex.org/W\(1000 + number)"
        )
    }
}

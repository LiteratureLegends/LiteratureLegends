//
//  PaperSearchService.swift
//  LiteratureAssistant · PaperSearch
//
//  The UI only talks to this protocol. OpenAlexService implements it today; a
//  Parse Cloud Function `searchPapers` / `getPaperDetails` implementation (see
//  readme.md › Networking) can replace it later without touching any view.
//

import Foundation

nonisolated protocol PaperSearchService: Sendable {
    /// Returns one page (1-based) of results for `query` in the given mode.
    func searchPapers(query: String, mode: SearchMode, page: Int) async throws -> PaperSearchPage

    /// Returns the full record for a paper, e.g. to fill in the abstract or the complete author list.
    func getPaperDetails(id: String) async throws -> Paper
}

nonisolated struct PaperSearchPage: Equatable, Sendable {
    var papers: [Paper]
    /// Total number of matches reported by the API.
    var totalCount: Int
    var page: Int
    var hasMore: Bool
    /// For author/topic searches: the author or topic the query was resolved to.
    var matchedEntityName: String?

    static func empty(page: Int = 1) -> PaperSearchPage {
        PaperSearchPage(papers: [], totalCount: 0, page: page, hasMore: false, matchedEntityName: nil)
    }
}

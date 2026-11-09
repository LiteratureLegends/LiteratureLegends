//
//  PaperDetailViewModel.swift
//  LiteratureAssistant · PaperSearch
//

import Foundation
import Observation

@MainActor
@Observable
final class PaperDetailViewModel {
    private(set) var paper: Paper
    private(set) var isLoadingDetails = false
    /// Set when fetching the full record failed; the summary from the search result stays visible.
    private(set) var detailError: PaperSearchError?

    private let service: any PaperSearchService
    private var hasLoadedDetails = false

    /// List results can include at most 100 authors; the single-work endpoint returns them all.
    static let listAuthorLimit = 100

    init(paper: Paper, service: any PaperSearchService) {
        self.paper = paper
        self.service = service
    }

    /// True when the search result is missing fields the detail record can fill in.
    /// Search results never include the abstract (it's left out of `select` to keep pages small).
    var needsDetails: Bool {
        paper.abstract == nil
            || paper.authors.isEmpty
            || paper.authors.count >= Self.listAuthorLimit
            || paper.venue == nil
            || (paper.publicationDate == nil && paper.publicationYear == nil)
    }

    /// Fetches the full record once, if needed. Safe to call from `.task` on every appearance.
    func loadDetailsIfNeeded() async {
        guard !hasLoadedDetails, !isLoadingDetails, needsDetails else { return }
        await loadDetails()
    }

    func retry() async {
        await loadDetails()
    }

    private func loadDetails() async {
        isLoadingDetails = true
        detailError = nil
        defer { isLoadingDetails = false }
        do {
            let detailed = try await service.getPaperDetails(id: paper.externalApiId)
            paper = Self.merge(summary: paper, detailed: detailed)
            hasLoadedDetails = true
        } catch is CancellationError {
            // The view disappeared; try again next time it appears.
        } catch {
            detailError = PaperSearchError(error)
        }
    }

    /// Prefers the detailed record but keeps any field only the summary had.
    static func merge(summary: Paper, detailed: Paper) -> Paper {
        var merged = detailed
        merged.externalApiId = summary.externalApiId
        if merged.title == "Untitled" { merged.title = summary.title }
        if merged.authors.count < summary.authors.count { merged.authors = summary.authors }
        merged.doi = detailed.doi ?? summary.doi
        merged.publicationDate = detailed.publicationDate ?? summary.publicationDate
        merged.publicationYear = detailed.publicationYear ?? summary.publicationYear
        merged.venue = detailed.venue ?? summary.venue
        merged.abstract = detailed.abstract ?? summary.abstract
        merged.citationCount = detailed.citationCount ?? summary.citationCount
        return merged
    }
}

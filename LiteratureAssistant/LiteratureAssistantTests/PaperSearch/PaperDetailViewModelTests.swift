//
//  PaperDetailViewModelTests.swift
//  LiteratureAssistantTests
//

import XCTest
@testable import LiteratureAssistant

@MainActor
final class PaperDetailViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    /// The second result in works_search.json: no abstract, DOI, venue or date.
    private func listResult() async throws -> Paper {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("works_search"))
        let page = try await Fixtures.makeService().searchPapers(query: "oa", mode: .keyword, page: 1)
        MockURLProtocol.reset()
        return page.papers[0]
    }

    func testFetchesDetailsWhenAbstractIsMissing() async throws {
        let summary = try await listResult()
        XCTAssertNil(summary.abstract, "list results never include the abstract")
        XCTAssertEqual(summary.authors.count, 4)

        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("work_detail"))
        let viewModel = PaperDetailViewModel(paper: summary, service: Fixtures.makeService())
        XCTAssertTrue(viewModel.needsDetails)

        await viewModel.loadDetailsIfNeeded()

        XCTAssertEqual(MockURLProtocol.requests.compactMap(\.url?.path), ["/works/W2741809807"])
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.queryDictionary["api_key"], Fixtures.apiKey)
        XCTAssertNotNil(viewModel.paper.abstract)
        XCTAssertEqual(viewModel.paper.authors.count, 9, "detail record has the full author list")
        XCTAssertFalse(viewModel.isLoadingDetails)
        XCTAssertNil(viewModel.detailError)

        // Loading again does nothing: the full record is already here.
        await viewModel.loadDetailsIfNeeded()
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testSkipsFetchWhenPaperIsComplete() async {
        let viewModel = PaperDetailViewModel(paper: MockPaperSearchService.sample, service: Fixtures.makeService())
        XCTAssertFalse(viewModel.needsDetails)
        await viewModel.loadDetailsIfNeeded()
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testFailureKeepsSummaryAndCanRetry() async throws {
        let summary = try await listResult()
        MockURLProtocol.handler = MockURLProtocol.fail(with: .notConnectedToInternet)
        let viewModel = PaperDetailViewModel(paper: summary, service: Fixtures.makeService())

        await viewModel.loadDetailsIfNeeded()

        XCTAssertEqual(viewModel.detailError, .offline)
        XCTAssertEqual(viewModel.paper, summary)
        XCTAssertNil(viewModel.paper.abstract, "view shows 'Abstract not available'")

        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("work_detail"))
        await viewModel.retry()
        XCTAssertNil(viewModel.detailError)
        XCTAssertNotNil(viewModel.paper.abstract)
    }

    func testMergeKeepsSummaryFieldsMissingFromDetail() {
        let summary = MockPaperSearchService.sample
        let sparse = Paper(externalApiId: summary.externalApiId, title: "Untitled", sourceUrl: "https://openalex.org/W2741809807")

        let merged = PaperDetailViewModel.merge(summary: summary, detailed: sparse)

        XCTAssertEqual(merged.title, summary.title)
        XCTAssertEqual(merged.authors, summary.authors)
        XCTAssertEqual(merged.doi, summary.doi)
        XCTAssertEqual(merged.venue, summary.venue)
        XCTAssertEqual(merged.abstract, summary.abstract)
        XCTAssertEqual(merged.citationCount, summary.citationCount)
        XCTAssertEqual(merged.publicationDate, summary.publicationDate)
    }

    func testOpenURLPrefersSourceThenDOI() {
        var paper = MockPaperSearchService.sample
        paper.sourceUrl = "https://example.org/landing"
        XCTAssertEqual(paper.openURL?.absoluteString, "https://example.org/landing")

        paper.sourceUrl = ""
        XCTAssertEqual(paper.openURL?.absoluteString, "https://doi.org/10.7717/peerj.4375")

        paper.doi = nil
        XCTAssertNil(paper.openURL)
    }

    func testDisplayDateFallsBackToYear() {
        var paper = MockPaperSearchService.sample
        XCTAssertNotNil(paper.displayDate)
        XCTAssertTrue(paper.displayDate?.contains("2018") == true)
        XCTAssertTrue(paper.displayDate?.contains("13") == true, "UTC formatting keeps the 13th, not the 12th")

        paper.publicationDate = nil
        XCTAssertEqual(paper.displayDate, "2018")

        paper.publicationYear = nil
        XCTAssertNil(paper.displayDate)
    }
}

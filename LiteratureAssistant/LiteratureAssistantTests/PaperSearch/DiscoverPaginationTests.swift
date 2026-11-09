//
//  DiscoverPaginationTests.swift
//  LiteratureAssistantTests
//

import XCTest
@testable import LiteratureAssistant

@MainActor
final class DiscoverPaginationTests: XCTestCase {
    private var page1 = Data()
    private var page2 = Data()

    override func setUp() async throws {
        try await super.setUp()
        MockURLProtocol.reset()
        page1 = try Fixtures.data("works_search")
        page2 = try Fixtures.data("works_page2")
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func installPagedHandler(page2Status: Int = 200) {
        let page1 = page1, page2 = page2
        MockURLProtocol.handler = { request in
            let page = request.url!.queryDictionary["page"]
            let isSecond = page == "2"
            let status = isSecond ? page2Status : 200
            let data = isSecond ? (status == 200 ? page2 : Data()) : page1
            return (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!, data)
        }
    }

    private func searchFirstPage() async -> DiscoverViewModel {
        let viewModel = DiscoverViewModel(service: Fixtures.makeService(), debounceInterval: .zero)
        viewModel.query = "open access"
        viewModel.submit()
        await viewModel.waitForCurrentSearch()
        return viewModel
    }

    func testFirstPageReportsMoreAvailable() async {
        installPagedHandler()
        let viewModel = await searchFirstPage()
        XCTAssertEqual(viewModel.state, .results)
        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(MockURLProtocol.requests.last?.url?.queryDictionary["per_page"], "25")
    }

    func testScrollingToEndAppendsNextPageWithoutDuplicates() async throws {
        installPagedHandler()
        let viewModel = await searchFirstPage()

        viewModel.loadNextPageIfNeeded(currentPaper: try XCTUnwrap(viewModel.papers.last))
        XCTAssertTrue(viewModel.isLoadingNextPage)
        await viewModel.waitForNextPage()

        XCTAssertFalse(viewModel.isLoadingNextPage)
        XCTAssertEqual(viewModel.papers.map(\.id), ["W2741809807", "W2000000002", "W2000000003", "W3000000001"])
        XCTAssertFalse(viewModel.hasMore, "count 30 means page 2 is the last page")
        XCTAssertEqual(MockURLProtocol.requests.last?.url?.queryDictionary["page"], "2")
        XCTAssertEqual(viewModel.state, .results)
    }

    func testDoesNotLoadMoreWhenNoMorePages() async throws {
        installPagedHandler()
        let viewModel = await searchFirstPage()
        viewModel.loadNextPage()
        await viewModel.waitForNextPage()
        let requestCount = MockURLProtocol.requests.count

        viewModel.loadNextPageIfNeeded(currentPaper: try XCTUnwrap(viewModel.papers.last))
        await viewModel.waitForNextPage()

        XCTAssertEqual(MockURLProtocol.requests.count, requestCount)
    }

    func testNextPageFailureKeepsResultsAndAllowsRetry() async throws {
        installPagedHandler(page2Status: 503)
        let viewModel = await searchFirstPage()

        viewModel.loadNextPage()
        await viewModel.waitForNextPage()

        XCTAssertEqual(viewModel.state, .results, "existing results stay on screen")
        XCTAssertEqual(viewModel.papers.count, 3)
        XCTAssertEqual(viewModel.nextPageError, .serverError(statusCode: 503))

        // Automatic loading pauses after a failure; the footer Retry button calls loadNextPage().
        let before = MockURLProtocol.requests.count
        viewModel.loadNextPageIfNeeded(currentPaper: try XCTUnwrap(viewModel.papers.last))
        XCTAssertEqual(MockURLProtocol.requests.count, before)

        installPagedHandler()
        viewModel.loadNextPage()
        await viewModel.waitForNextPage()
        XCTAssertNil(viewModel.nextPageError)
        XCTAssertEqual(viewModel.papers.count, 4)
    }

    func testRetryAfterErrorRunsSameSearch() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 429, data: Data(), headers: ["Retry-After": "1"])
        let viewModel = await searchFirstPage()
        XCTAssertEqual(viewModel.state, .error(.rateLimited(retryAfterSeconds: 1)))

        installPagedHandler()
        viewModel.query = "something else typed meanwhile"
        viewModel.retry()
        await viewModel.waitForCurrentSearch()

        XCTAssertEqual(viewModel.state, .results)
        XCTAssertEqual(MockURLProtocol.requests.last?.url?.queryDictionary["search"], "open access")
    }

    func testNewSearchDropsPendingNextPage() async throws {
        installPagedHandler()
        let viewModel = await searchFirstPage()
        viewModel.loadNextPage()

        viewModel.query = "brand new query"
        viewModel.submit()
        await viewModel.waitForNextPage()
        await viewModel.waitForCurrentSearch()

        XCTAssertEqual(viewModel.activeQuery, "brand new query")
        XCTAssertEqual(viewModel.papers.count, 3, "page-2 results of the old query are never appended")
        XCTAssertFalse(viewModel.isLoadingNextPage)
    }

    func testServiceStopsAtTenThousandResultWindow() async throws {
        // page 401 × 25 > 10,000: no request is sent and the page is empty.
        let page = try await Fixtures.makeService().searchPapers(query: "anything", mode: .keyword, page: 401)
        XCTAssertTrue(page.papers.isEmpty)
        XCTAssertFalse(page.hasMore)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }
}

//
//  DiscoverViewModelTests.swift
//  LiteratureAssistantTests
//

import XCTest
@testable import LiteratureAssistant

@MainActor
final class DiscoverViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func makeViewModel(debounce: Duration = .zero) -> DiscoverViewModel {
        DiscoverViewModel(service: Fixtures.makeService(), debounceInterval: debounce)
    }

    func testStartsIdle() {
        let viewModel = makeViewModel()
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(viewModel.papers.isEmpty)
    }

    func testSubmitGoesThroughLoadingToResults() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("works_search"))
        let viewModel = makeViewModel()
        viewModel.query = "open access"

        viewModel.submit()
        await Task.yield()
        XCTAssertEqual(viewModel.state, .loading)

        await viewModel.waitForCurrentSearch()
        XCTAssertEqual(viewModel.state, .results)
        XCTAssertEqual(viewModel.papers.count, 3)
        XCTAssertEqual(viewModel.totalCount, 60)
        XCTAssertEqual(viewModel.activeQuery, "open access")
    }

    func testEmptyResponseGivesEmptyState() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("works_empty"))
        let viewModel = makeViewModel()
        viewModel.query = "  zzqxv  "

        viewModel.submit()
        await viewModel.waitForCurrentSearch()

        XCTAssertEqual(viewModel.state, .empty(query: "zzqxv"))
    }

    func testFailureGivesErrorState() async {
        MockURLProtocol.handler = MockURLProtocol.fail(with: .notConnectedToInternet)
        let viewModel = makeViewModel()
        viewModel.query = "open access"

        viewModel.submit()
        await viewModel.waitForCurrentSearch()

        XCTAssertEqual(viewModel.state, .error(.offline))
    }

    func testWhitespaceOnlyInputIsIgnored() {
        let viewModel = makeViewModel()
        viewModel.query = "    "
        viewModel.submit()
        viewModel.queryDidChange()
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testTypingFewerThanThreeCharactersDoesNotSearch() async {
        let viewModel = makeViewModel()
        viewModel.query = "ab"
        viewModel.queryDidChange()
        await viewModel.waitForCurrentSearch()
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testTypingDebouncesToOneRequest() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("works_search"))
        let viewModel = makeViewModel(debounce: .milliseconds(50))

        for text in ["ope", "open", "open a", "open access"] {
            viewModel.query = text
            viewModel.queryDidChange()
        }
        await viewModel.waitForCurrentSearch()

        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertEqual(MockURLProtocol.requests.first?.url?.queryDictionary["search"], "open access")
        XCTAssertEqual(viewModel.state, .results)
    }

    func testClearingQueryReturnsToIdle() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("works_search"))
        let viewModel = makeViewModel()
        viewModel.query = "open access"
        viewModel.submit()
        await viewModel.waitForCurrentSearch()

        viewModel.query = ""
        viewModel.queryDidChange()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(viewModel.papers.isEmpty)
    }

    func testNewQueryCancelsInFlightSearch() async {
        let service = ControllableSearchService()
        let viewModel = DiscoverViewModel(service: service, debounceInterval: .zero)

        viewModel.query = "first"
        viewModel.submit()
        await service.waitForCalls(1)

        viewModel.query = "second"
        viewModel.submit()
        await service.waitForCalls(2)

        // The first request finishes last; its result must be ignored.
        await service.complete(query: "second")
        await service.complete(query: "first")
        await viewModel.waitForCurrentSearch()

        XCTAssertEqual(viewModel.activeQuery, "second")
        XCTAssertEqual(viewModel.papers.first?.title, "Second study #1")
        let firstWasCancelled = await service.wasCancelled(query: "first")
        XCTAssertTrue(firstWasCancelled)
    }

    func testModeChangeSearchesAgainImmediately() async throws {
        let authors = try Fixtures.data("authors_search")
        let works = try Fixtures.data("works_search")
        MockURLProtocol.handler = { request in
            let data = request.url!.path == "/authors" ? authors : works
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let viewModel = makeViewModel()
        viewModel.query = "Jason Priem"
        viewModel.mode = .author
        viewModel.modeDidChange()
        await viewModel.waitForCurrentSearch()

        XCTAssertEqual(viewModel.activeMode, .author)
        XCTAssertEqual(viewModel.matchedEntityName, "Jason Priem")
    }

    func testDOIIsAutoDetected() {
        let viewModel = makeViewModel()
        viewModel.query = "10.7717/peerj.4375"
        XCTAssertEqual(viewModel.effectiveMode, .doi)
        XCTAssertTrue(viewModel.isDOIAutoDetected)
    }
}

/// A service whose calls stay pending until the test completes them, to test cancellation.
actor ControllableSearchService: PaperSearchService {
    private var pending: [String: CheckedContinuation<PaperSearchPage, Error>] = [:]
    private var cancelled: Set<String> = []
    private var callCount = 0
    private var callWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    nonisolated func searchPapers(query: String, mode: SearchMode, page: Int) async throws -> PaperSearchPage {
        let result = try await withTaskCancellationHandler {
            try await self.register(query: query)
        } onCancel: {
            Task { await self.markCancelled(query) }
        }
        return result
    }

    nonisolated func getPaperDetails(id: String) async throws -> Paper {
        MockPaperSearchService.sample
    }

    private func register(query: String) async throws -> PaperSearchPage {
        try await withCheckedThrowingContinuation { continuation in
            pending[query] = continuation
            callCount += 1
            callWaiters.removeAll { count, waiter in
                guard callCount >= count else { return false }
                waiter.resume()
                return true
            }
        }
    }

    private func markCancelled(_ query: String) { cancelled.insert(query) }

    func wasCancelled(query: String) async -> Bool {
        // Cancellation is delivered asynchronously; give it a moment.
        for _ in 0..<50 where !cancelled.contains(query) { await Task.yield() }
        return cancelled.contains(query)
    }

    func waitForCalls(_ count: Int) async {
        if callCount >= count { return }
        await withCheckedContinuation { callWaiters.append((count, $0)) }
    }

    func complete(query: String) {
        let paper = MockPaperSearchService.samplePaper(number: 1, query: query)
        pending.removeValue(forKey: query)?.resume(returning: PaperSearchPage(
            papers: [paper], totalCount: 1, page: 1, hasMore: false, matchedEntityName: nil))
    }
}

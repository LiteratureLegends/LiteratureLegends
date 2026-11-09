//
//  OpenAlexErrorTests.swift
//  LiteratureAssistantTests
//
//  HTTP and network failures map to friendly PaperSearchError values.
//

import XCTest
@testable import LiteratureAssistant

final class OpenAlexErrorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    private func searchError(file: StaticString = #filePath, line: UInt = #line) async -> PaperSearchError? {
        do {
            _ = try await Fixtures.makeService().searchPapers(query: "open access", mode: .keyword, page: 1)
            XCTFail("expected an error", file: file, line: line)
            return nil
        } catch {
            return error as? PaperSearchError
        }
    }

    func testRateLimitReadsRetryAfter() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 429, data: Data(), headers: ["Retry-After": "12"])
        let error = await searchError()
        XCTAssertEqual(error, .rateLimited(retryAfterSeconds: 12))
        XCTAssertEqual(error?.message, "You've hit OpenAlex's rate limit. Try again in 12 seconds.")
        XCTAssertTrue(error?.isRetryable == true)
    }

    func testRateLimitWithoutRetryAfter() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 429, data: Data())
        let error = await searchError()
        XCTAssertEqual(error, .rateLimited(retryAfterSeconds: nil))
        XCTAssertEqual(error?.message, "You've hit OpenAlex's rate limit. Wait a moment and try again.")
    }

    func testKeyNotActivated() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 403, data: try Fixtures.data("error_key_not_activated"))
        let error = await searchError()
        XCTAssertEqual(error, .keyNotActivated)
    }

    func testUnauthorizedIsInvalidKeyAndNotRetryable() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 401, data: Data())
        let error = await searchError()
        XCTAssertEqual(error, .invalidAPIKey)
        XCTAssertEqual(error?.isRetryable, false)
    }

    func testOther4xxIsClientError() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 400, data: Data("{\"error\":\"Invalid query\"}".utf8))
        let error = await searchError()
        XCTAssertEqual(error, .clientError(statusCode: 400))
    }

    func testGatewayTimeoutIsServerError() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 504, data: try Fixtures.data("error_query_timeout"))
        let error = await searchError()
        XCTAssertEqual(error, .serverError(statusCode: 504))
        XCTAssertTrue(error?.message.contains("Try again") == true)
    }

    func testServerError() async {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 500, data: Data("oops".utf8))
        let error = await searchError()
        XCTAssertEqual(error, .serverError(statusCode: 500))
    }

    func testOffline() async {
        MockURLProtocol.handler = MockURLProtocol.fail(with: .notConnectedToInternet)
        let error = await searchError()
        XCTAssertEqual(error, .offline)
        XCTAssertEqual(error?.title, "You're offline")
    }

    func testTimeout() async {
        MockURLProtocol.handler = MockURLProtocol.fail(with: .timedOut)
        let error = await searchError()
        XCTAssertEqual(error, .timedOut)
    }

    func testMalformedJSONIsDecodingError() async {
        MockURLProtocol.handler = MockURLProtocol.respond(data: Data("<html>not json</html>".utf8))
        let error = await searchError()
        XCTAssertEqual(error, .decoding)
    }

    func testInvalidDOIInDOIModeIsInvalidQuery() async {
        do {
            _ = try await Fixtures.makeService().searchPapers(query: "hello world", mode: .doi, page: 1)
            XCTFail("expected an error")
        } catch {
            guard case .invalidQuery = error as? PaperSearchError else {
                return XCTFail("expected invalidQuery, got \(error)")
            }
        }
        XCTAssertTrue(MockURLProtocol.requests.isEmpty, "no request for an invalid DOI")
    }

    func testEveryErrorHasFriendlyText() {
        let all: [PaperSearchError] = [
            .missingAPIKey, .invalidAPIKey, .keyNotActivated, .offline, .timedOut,
            .rateLimited(retryAfterSeconds: 1), .invalidQuery("x"), .notFound,
            .clientError(statusCode: 418), .serverError(statusCode: 503), .decoding, .network,
        ]
        for error in all {
            XCTAssertFalse(error.title.isEmpty)
            XCTAssertFalse(error.message.isEmpty)
            XCTAssertFalse(error.message.contains("URLError"), "no raw system errors in UI text")
        }
    }
}

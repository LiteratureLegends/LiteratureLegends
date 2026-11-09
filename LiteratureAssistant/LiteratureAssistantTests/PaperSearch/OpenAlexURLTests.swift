//
//  OpenAlexURLTests.swift
//  LiteratureAssistantTests
//
//  Checks the requests each search mode sends. All traffic goes through MockURLProtocol.
//

import XCTest
@testable import LiteratureAssistant

final class OpenAlexURLTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: Pure URL builders

    func testKeywordURL() {
        let url = Fixtures.makeService().worksSearchURL(query: "deep learning & C++", page: 2)
        let query = url.queryDictionary

        XCTAssertEqual(url.host, "api.openalex.org")
        XCTAssertEqual(url.path, "/works")
        XCTAssertEqual(query["search"], "deep learning & C++")
        XCTAssertEqual(query["per_page"], "25")
        XCTAssertEqual(query["page"], "2")
        XCTAssertEqual(query["api_key"], Fixtures.apiKey)
        XCTAssertEqual(query["select"], OpenAlexService.listFields.joined(separator: ","))
        XCTAssertTrue(url.absoluteString.contains("C%2B%2B"), "'+' must be percent-encoded")
        XCTAssertTrue(url.absoluteString.contains("%26"), "'&' inside a value must be percent-encoded")
    }

    func testDOIURLUsesSingletonPath() {
        let url = Fixtures.makeService().workURL(doi: "10.7717/peerj.4375")
        XCTAssertEqual(url.path, "/works/doi:10.7717/peerj.4375")
        XCTAssertEqual(url.queryDictionary["api_key"], Fixtures.apiKey)
    }

    func testDetailURLAcceptsFullOrShortIDs() {
        let service = Fixtures.makeService()
        XCTAssertEqual(service.workURL(id: "https://openalex.org/W123").path, "/works/W123")
        XCTAssertEqual(service.workURL(id: "W123").path, "/works/W123")
    }

    func testEntityLookupURLs() {
        let service = Fixtures.makeService()
        let author = service.entityLookupURL(kind: .author, query: "Jason Priem")
        XCTAssertEqual(author.path, "/authors")
        XCTAssertEqual(author.queryDictionary["search"], "Jason Priem")
        XCTAssertEqual(author.queryDictionary["per_page"], "1")

        let topic = service.entityLookupURL(kind: .topic, query: "bibliometrics")
        XCTAssertEqual(topic.path, "/topics")
        XCTAssertEqual(topic.queryDictionary["search"], "bibliometrics")
    }

    // MARK: Requests sent per mode

    func testKeywordSearchSendsOneWorksRequest() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("works_search"))

        let page = try await Fixtures.makeService().searchPapers(query: "  open access  ", mode: .keyword, page: 1)

        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        let url = try XCTUnwrap(MockURLProtocol.requests.first?.url)
        XCTAssertEqual(url.path, "/works")
        XCTAssertEqual(url.queryDictionary["search"], "open access", "query is trimmed")
        XCTAssertEqual(page.papers.count, 3)
        XCTAssertEqual(page.totalCount, 60)
        XCTAssertTrue(page.hasMore)
    }

    func testDOISearchUsesSingletonLookup() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("work_detail"))

        let page = try await Fixtures.makeService().searchPapers(query: "https://doi.org/10.7717/peerj.4375", mode: .keyword, page: 1)

        let url = try XCTUnwrap(MockURLProtocol.requests.first?.url)
        XCTAssertEqual(url.path, "/works/doi:10.7717/peerj.4375", "DOI is auto-detected even in keyword mode")
        XCTAssertEqual(page.papers.map(\.id), ["W2741809807"])
        XCTAssertFalse(page.hasMore)
    }

    func testDOINotFoundIsEmptyNotError() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(status: 404, data: Data("{}".utf8))
        let page = try await Fixtures.makeService().searchPapers(query: "10.1/missing", mode: .doi, page: 1)
        XCTAssertTrue(page.papers.isEmpty)
    }

    func testAuthorSearchResolvesAuthorThenFiltersWorks() async throws {
        let authors = try Fixtures.data("authors_search")
        let works = try Fixtures.data("works_search")
        MockURLProtocol.handler = { request in
            let data = request.url!.path == "/authors" ? authors : works
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        let service = Fixtures.makeService()

        let page = try await service.searchPapers(query: "Jason Priem", mode: .author, page: 1)

        let urls = MockURLProtocol.requests.compactMap(\.url)
        XCTAssertEqual(urls.map(\.path), ["/authors", "/works"])
        XCTAssertEqual(urls[1].queryDictionary["filter"], "authorships.author.id:A5023888391")
        XCTAssertEqual(urls[1].queryDictionary["sort"], "cited_by_count:desc")
        XCTAssertEqual(page.matchedEntityName, "Jason Priem")

        // Page 2 reuses the resolved author ID instead of looking it up again.
        _ = try await service.searchPapers(query: "Jason Priem", mode: .author, page: 2)
        XCTAssertEqual(MockURLProtocol.requests.compactMap(\.url?.path), ["/authors", "/works", "/works"])
        XCTAssertEqual(MockURLProtocol.requests.last?.url?.queryDictionary["page"], "2")
    }

    func testTopicSearchResolvesTopicThenFiltersWorks() async throws {
        let topics = try Fixtures.data("topics_search")
        let works = try Fixtures.data("works_search")
        MockURLProtocol.handler = { request in
            let data = request.url!.path == "/topics" ? topics : works
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let page = try await Fixtures.makeService().searchPapers(query: "bibliometrics", mode: .topic, page: 1)

        let urls = MockURLProtocol.requests.compactMap(\.url)
        XCTAssertEqual(urls.map(\.path), ["/topics", "/works"])
        XCTAssertEqual(urls[1].queryDictionary["filter"], "topics.id:T10102")
        XCTAssertEqual(page.matchedEntityName, "scientometrics and bibliometrics research")
    }

    func testUnknownAuthorReturnsEmptyWithoutWorksRequest() async throws {
        MockURLProtocol.handler = MockURLProtocol.respond(data: try Fixtures.data("works_empty"))
        let page = try await Fixtures.makeService().searchPapers(query: "Nobody Atall", mode: .author, page: 1)
        XCTAssertTrue(page.papers.isEmpty)
        XCTAssertEqual(MockURLProtocol.requests.compactMap(\.url?.path), ["/authors"])
    }

    func testMissingKeyThrowsWithoutNetwork() async {
        let service = OpenAlexService(apiKey: "  ", session: MockURLProtocol.makeSession())
        do {
            _ = try await service.searchPapers(query: "anything", mode: .keyword, page: 1)
            XCTFail("expected missingAPIKey")
        } catch {
            XCTAssertEqual(error as? PaperSearchError, .missingAPIKey)
        }
        XCTAssertTrue(MockURLProtocol.requests.isEmpty)
    }

    func testAppConfigTreatsPlaceholderAsMissing() {
        XCTAssertNil(AppConfig.sanitizedAPIKey(nil))
        XCTAssertNil(AppConfig.sanitizedAPIKey(""))
        XCTAssertNil(AppConfig.sanitizedAPIKey(AppConfig.placeholderAPIKey))
        XCTAssertNil(AppConfig.sanitizedAPIKey("$(OPENALEX_API_KEY)"))
        XCTAssertEqual(AppConfig.sanitizedAPIKey(" abc123 "), "abc123")
    }
}

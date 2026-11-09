//
//  OpenAlexMappingTests.swift
//  LiteratureAssistantTests
//

import XCTest
@testable import LiteratureAssistant

final class OpenAlexMappingTests: XCTestCase {
    func testMapsFullWorkIntoPaper() throws {
        let paper = try XCTUnwrap(OpenAlexMapper.paper(from: Fixtures.work("work_detail"), retrievedAt: Fixtures.fixedDate))

        XCTAssertEqual(paper.id, "W2741809807")
        XCTAssertEqual(paper.externalApiId, "W2741809807")
        XCTAssertEqual(paper.externalApiSource, "OpenAlex")
        XCTAssertEqual(paper.title, "The state of OA: a large-scale analysis of the prevalence and impact of Open Access articles")
        XCTAssertEqual(paper.authors.count, 9)
        XCTAssertEqual(paper.authors.first, "Heather Piwowar")
        XCTAssertEqual(paper.authors.last, "Stefanie Haustein")
        XCTAssertEqual(paper.doi, "10.7717/peerj.4375")
        XCTAssertEqual(paper.publicationYear, 2018)
        XCTAssertEqual(paper.publicationDate, OpenAlexMapper.parseDate("2018-02-13"))
        XCTAssertEqual(paper.venue, "PeerJ")
        XCTAssertEqual(paper.citationCount, 1487)
        XCTAssertEqual(paper.sourceUrl, "https://doi.org/10.7717/peerj.4375")
        XCTAssertEqual(paper.retrievedAt, Fixtures.fixedDate)
    }

    func testRebuildsAbstractFromInvertedIndex() throws {
        let paper = try XCTUnwrap(OpenAlexMapper.paper(from: Fixtures.work("work_detail")))
        // "in" appears at two positions; the underscore word must not be rewritten by key decoding.
        XCTAssertEqual(
            paper.abstract,
            "Despite growing interest in Open Access (OA) in scholarly_literature, we measure it."
        )
    }

    func testRebuildAbstractHandlesEmptyAndGaps() {
        XCTAssertNil(OpenAlexMapper.rebuildAbstract(from: nil))
        XCTAssertNil(OpenAlexMapper.rebuildAbstract(from: [:]))
        XCTAssertNil(OpenAlexMapper.rebuildAbstract(from: ["word": []]))
        XCTAssertEqual(OpenAlexMapper.rebuildAbstract(from: ["b": [5], "a": [2]]), "a b")
    }

    func testMinimalWorkUsesFallbacksForMissingFields() throws {
        let paper = try XCTUnwrap(OpenAlexMapper.paper(from: Fixtures.work("work_minimal")))

        XCTAssertEqual(paper.id, "W9999999999")
        XCTAssertEqual(paper.title, "Untitled")
        XCTAssertEqual(paper.authors, [])
        XCTAssertNil(paper.doi)
        XCTAssertNil(paper.publicationDate)
        XCTAssertNil(paper.publicationYear)
        XCTAssertNil(paper.venue)
        XCTAssertNil(paper.abstract)
        XCTAssertNil(paper.citationCount)
        XCTAssertEqual(paper.sourceUrl, "https://openalex.org/W9999999999")
        XCTAssertEqual(paper.shortAuthorList, "Unknown authors")
    }

    func testListResultsMapNullsAndRawAuthorNames() throws {
        let response = try JSONDecoder().decode(
            OpenAlexListResponse<OpenAlexWork>.self, from: Fixtures.data("works_search"))
        let papers = response.results.compactMap { OpenAlexMapper.paper(from: $0) }

        XCTAssertEqual(response.meta?.count, 60)
        XCTAssertEqual(papers.count, 3)

        let second = papers[1]
        XCTAssertNil(second.doi)
        XCTAssertNil(second.venue)
        XCTAssertNil(second.publicationDate)
        XCTAssertEqual(second.publicationYear, 2021)
        XCTAssertEqual(second.authors, ["Ada Lovelace", "A. Turing"], "falls back to raw_author_name")
        XCTAssertEqual(second.sourceUrl, "https://openalex.org/W2000000002")

        XCTAssertEqual(papers[2].title, "Untitled")
        XCTAssertNil(papers[2].citationCount)
    }

    func testShortAuthorListAddsEtAlOnlyAfterThree() {
        var paper = MockPaperSearchService.sample
        paper.authors = ["A", "B", "C", "D"]
        XCTAssertEqual(paper.shortAuthorList, "A, B, C et al.")
        paper.authors = ["A", "B", "C"]
        XCTAssertEqual(paper.shortAuthorList, "A, B, C")
    }

    func testPaperRoundTripsThroughCodable() throws {
        let paper = MockPaperSearchService.sample
        let decoded = try JSONDecoder().decode(Paper.self, from: JSONEncoder().encode(paper))
        XCTAssertEqual(decoded, paper)
    }
}

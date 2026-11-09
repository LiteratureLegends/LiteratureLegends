//
//  SearchModeTests.swift
//  LiteratureAssistantTests
//

import XCTest
@testable import LiteratureAssistant

final class SearchModeTests: XCTestCase {
    func testDetectsDOIs() {
        XCTAssertTrue(SearchMode.looksLikeDOI("10.7717/peerj.4375"))
        XCTAssertTrue(SearchMode.looksLikeDOI("  10.1000/xyz123 "))
        XCTAssertTrue(SearchMode.looksLikeDOI("https://doi.org/10.7717/peerj.4375"))
        XCTAssertTrue(SearchMode.looksLikeDOI("http://dx.doi.org/10.7717/peerj.4375"))
        XCTAssertTrue(SearchMode.looksLikeDOI("DOI:10.7717/peerj.4375"))
    }

    func testDoesNotDetectOrdinaryQueries() {
        XCTAssertFalse(SearchMode.looksLikeDOI("deep learning"))
        XCTAssertFalse(SearchMode.looksLikeDOI("Jason Priem"))
        XCTAssertFalse(SearchMode.looksLikeDOI("covid 10.5 mg"))
        XCTAssertFalse(SearchMode.looksLikeDOI(""))
    }

    func testEffectiveModeOverridesPickerForDOIs() {
        XCTAssertEqual(SearchMode.effectiveMode(for: "10.7717/peerj.4375", selected: .keyword), .doi)
        XCTAssertEqual(SearchMode.effectiveMode(for: "https://doi.org/10.1/a", selected: .author), .doi)
        XCTAssertEqual(SearchMode.effectiveMode(for: "open access", selected: .topic), .topic)
    }

    func testNormalizesDOIs() {
        XCTAssertEqual(SearchMode.normalizeDOI("https://doi.org/10.7717/peerj.4375"), "10.7717/peerj.4375")
        XCTAssertEqual(SearchMode.normalizeDOI("doi: 10.7717/peerj.4375"), "10.7717/peerj.4375")
        XCTAssertEqual(SearchMode.normalizeDOI(" 10.1002/(SICI)1097-4571 "), "10.1002/(SICI)1097-4571")
        XCTAssertEqual(SearchMode.normalizeDOI("https://doi.org/10.1000%2Fabc"), "10.1000/abc")
        XCTAssertNil(SearchMode.normalizeDOI("10.7717"))
        XCTAssertNil(SearchMode.normalizeDOI("10.7717/"))
        XCTAssertNil(SearchMode.normalizeDOI("not a doi"))
    }
}

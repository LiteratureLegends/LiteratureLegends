//
//  AppConfigTests.swift
//  LiteratureLegendsTests
//

import XCTest
@testable import LiteratureLegends

final class AppConfigTests: XCTestCase {
    func testEveryExamplePlaceholderIsTreatedAsMissing() {
        for placeholder in ["YOUR_OPENALEX_API_KEY", "YOUR_GEMINI_API_KEY",
                            "YOUR_PARSE_APPLICATION_ID", "YOUR_PARSE_REST_API_KEY"] {
            XCTAssertNil(AppConfig.sanitizedAPIKey(placeholder), placeholder)
        }
    }

    func testUnsubstitutedBuildSettingIsTreatedAsMissing() {
        XCTAssertNil(AppConfig.sanitizedAPIKey("$(GEMINI_API_KEY)"))
        XCTAssertNil(AppConfig.sanitizedAPIKey("   "))
    }

    func testRealLookingValueIsTrimmedAndKept() {
        XCTAssertEqual(AppConfig.sanitizedAPIKey("  abc123\n"), "abc123")
    }

    func testMissingInfoKeyReturnsNil() {
        XCTAssertNil(AppConfig.value(for: "DefinitelyNotAKey", in: Bundle(for: Self.self)))
    }
}

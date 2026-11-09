//
//  Fixtures.swift
//  LiteratureAssistantTests
//

import Foundation
import XCTest
@testable import LiteratureAssistant

enum Fixtures {
    private final class BundleToken {}

    /// Loads `<name>.json` from the test bundle.
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let bundle = Bundle(for: BundleToken.self)
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        let resolved = try XCTUnwrap(url, "Missing fixture \(name).json in test bundle", file: file, line: line)
        return try Data(contentsOf: resolved)
    }

    static func work(_ name: String) throws -> OpenAlexWork {
        try JSONDecoder().decode(OpenAlexWork.self, from: data(name))
    }

    static let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
    static let apiKey = "TEST_KEY_123"

    static func makeService() -> OpenAlexService {
        OpenAlexService(apiKey: apiKey, session: MockURLProtocol.makeSession(), now: { fixedDate })
    }
}

extension URL {
    /// Query items as a dictionary for easy assertions.
    var queryDictionary: [String: String] {
        let items = URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { $1 })
    }
}

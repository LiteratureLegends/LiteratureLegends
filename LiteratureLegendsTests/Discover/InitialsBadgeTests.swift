//
//  InitialsBadgeTests.swift
//  LiteratureLegendsTests
//

import XCTest
@testable import LiteratureLegends

@MainActor
final class InitialsBadgeTests: XCTestCase {
    func testUsesFirstTwoNameParts() {
        XCTAssertEqual(InitialsBadge(name: "Ada Byron Lovelace").initials, "AB")
        XCTAssertEqual(InitialsBadge(name: "jordan").initials, "J")
        XCTAssertEqual(InitialsBadge(name: "").initials, "?")
    }
}

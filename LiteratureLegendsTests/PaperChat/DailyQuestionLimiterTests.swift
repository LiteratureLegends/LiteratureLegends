//
//  DailyQuestionLimiterTests.swift
//  LiteratureLegendsTests
//

import XCTest
@testable import LiteratureLegends

@MainActor
final class DailyQuestionLimiterTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var now = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    override func setUp() {
        super.setUp()
        suiteName = "DailyQuestionLimiterTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeLimiter(limit: Int = 3) -> DailyQuestionLimiter {
        DailyQuestionLimiter(defaults: defaults, limit: limit, calendar: calendar, now: { [unowned self] in now })
    }

    func testCountsUpToLimit() {
        let limiter = makeLimiter()
        XCTAssertEqual(limiter.remainingToday, 3)
        limiter.recordQuestion()
        limiter.recordQuestion()
        XCTAssertEqual(limiter.remainingToday, 1)
        XCTAssertTrue(limiter.canAsk)
        limiter.recordQuestion()
        XCTAssertEqual(limiter.remainingToday, 0)
        XCTAssertFalse(limiter.canAsk)
    }

    func testCountPersistsAcrossInstances() {
        makeLimiter().recordQuestion()
        XCTAssertEqual(makeLimiter().usedToday, 1)
    }

    func testResetsOnNextDay() {
        let limiter = makeLimiter(limit: 1)
        limiter.recordQuestion()
        XCTAssertFalse(limiter.canAsk)

        now = now.addingTimeInterval(86_400)
        XCTAssertEqual(limiter.usedToday, 0)
        XCTAssertTrue(limiter.canAsk)
        limiter.recordQuestion()
        XCTAssertEqual(limiter.usedToday, 1)
    }

    func testDefaultLimitIsTwenty() {
        XCTAssertEqual(DailyQuestionLimiter.defaultLimit, 20)
    }
}

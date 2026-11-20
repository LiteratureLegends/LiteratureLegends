//
//  DailyQuestionLimiter.swift
//  LiteratureLegends · PaperChat
//
//  Soft limit on AI questions per day, stored locally in UserDefaults. It protects the shared
//  free-tier quota from accidental overuse; it is not a security boundary.
//

import Foundation

@MainActor
final class DailyQuestionLimiter {
    nonisolated static let defaultLimit = 20
    private static let dayKey = "PaperChat.questionDay"
    private static let countKey = "PaperChat.questionCount"

    let limit: Int
    private let defaults: UserDefaults
    private let now: () -> Date
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, limit: Int = DailyQuestionLimiter.defaultLimit,
         calendar: Calendar = .current, now: @escaping () -> Date = { .now }) {
        self.defaults = defaults
        self.limit = limit
        self.calendar = calendar
        self.now = now
    }

    /// Questions answered today (resets at local midnight).
    var usedToday: Int {
        defaults.string(forKey: Self.dayKey) == todayKey ? defaults.integer(forKey: Self.countKey) : 0
    }

    var remainingToday: Int { max(0, limit - usedToday) }

    var canAsk: Bool { remainingToday > 0 }

    /// Call after a question was answered.
    func recordQuestion() {
        let count = usedToday + 1
        defaults.set(todayKey, forKey: Self.dayKey)
        defaults.set(count, forKey: Self.countKey)
    }

    private var todayKey: String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}

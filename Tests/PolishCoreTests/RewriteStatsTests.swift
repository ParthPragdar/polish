import XCTest
@testable import PolishCore

final class RewriteStatsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private func date(_ day: Int, hour: Int = 9) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))! // Oct 5, 2026 is a Monday.
    }
    private func item(_ mode: RewriteMode, _ app: String, _ text: String, day: Int, hour: Int = 9) -> HistoryItem {
        HistoryItem(createdAt: date(day, hour: hour), mode: mode, sourceApp: app, original: text, result: text)
    }

    func testEmptyHistory() {
        let stats = RewriteStats(items: [], calendar: calendar)
        XCTAssertEqual(stats.overall.total, 0)
        XCTAssertEqual(stats.words, 0)
        XCTAssertNil(stats.since)
        XCTAssertEqual(stats.weekdays.count, 7)
        XCTAssertTrue(stats.apps.isEmpty)
    }

    func testTotalsWeekdaysAndApps() {
        let items = [
            item(.grammar, "Mail", "one two three", day: 5),
            item(.prompt, "Slack", "four  five\nsix", day: 5, hour: 18),
            item(.grammar, "Slack", "seven", day: 11),
            item(.grammar, "Notes", "eight nine", day: 8)
        ]
        let stats = RewriteStats(items: items, calendar: calendar)
        XCTAssertEqual(stats.overall, .init(grammar: 3, prompt: 1))
        XCTAssertEqual(stats.words, 9)
        XCTAssertEqual(stats.since, date(5))
        XCTAssertEqual(stats.weekdays[0], .init(grammar: 1, prompt: 1)) // Monday
        XCTAssertEqual(stats.weekdays[3], .init(grammar: 1))            // Thursday
        XCTAssertEqual(stats.weekdays[6], .init(grammar: 1))            // Sunday
        XCTAssertEqual(stats.apps.map(\.name), ["Slack", "Mail", "Notes"])
        XCTAssertEqual(stats.apps.first?.tally, .init(grammar: 1, prompt: 1))
    }

    func testWeekdayIndexIgnoresFirstWeekday() {
        var sundayFirst = calendar; sundayFirst.firstWeekday = 1
        var mondayFirst = calendar; mondayFirst.firstWeekday = 2
        XCTAssertEqual(RewriteStats.weekdayIndex(of: date(5), calendar: sundayFirst), 0)
        XCTAssertEqual(RewriteStats.weekdayIndex(of: date(11), calendar: mondayFirst), 6)
    }

    func testGroupingByDay() {
        let items = [item(.grammar, "Mail", "a", day: 5), item(.prompt, "Mail", "b", day: 5, hour: 23), item(.grammar, "Mail", "c", day: 6)]
        let days = RewriteStats.byDay(items, calendar: calendar)
        XCTAssertEqual(days[calendar.startOfDay(for: date(5))], .init(grammar: 1, prompt: 1))
        XCTAssertEqual(days[calendar.startOfDay(for: date(6))], .init(grammar: 1))
        XCTAssertEqual(days.count, 2)
    }
}

final class WordDiffTests: XCTestCase {
    func testPairsEachReplacedWord() {
        XCTAssertEqual(WordDiff.changes(from: "i has a idea", to: "I have an idea"), [
            .removed("i"), .added("I"), .same(" "), .removed("has"), .added("have"), .same(" "),
            .removed("a"), .added("an"), .same(" idea")
        ])
    }

    func testIdenticalTextIsOneRun() {
        XCTAssertEqual(WordDiff.changes(from: "Hello there.", to: "Hello there."), [.same("Hello there.")])
    }

    func testInsertionAndDeletion() {
        XCTAssertEqual(WordDiff.changes(from: "a b c", to: "a c d"), [
            .same("a "), .removed("b "), .same("c"), .added(" d")
        ])
    }

    func testReassemblesBothTexts() throws {
        let old = "Line one,\n  line two!  "
        let new = "Line 1,\nline two."
        let changes = try XCTUnwrap(WordDiff.changes(from: old, to: new))
        let rebuiltOld = changes.map { if case let .same(t) = $0 { return t }; if case let .removed(t) = $0 { return t }; return "" }.joined()
        let rebuiltNew = changes.map { if case let .same(t) = $0 { return t }; if case let .added(t) = $0 { return t }; return "" }.joined()
        XCTAssertEqual(rebuiltOld, old)
        XCTAssertEqual(rebuiltNew, new)
    }

    func testLongTextIsSkipped() {
        let long = Array(repeating: "word", count: 2000).joined(separator: " ")
        XCTAssertNil(WordDiff.changes(from: long, to: long))
    }
}

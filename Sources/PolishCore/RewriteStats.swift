import Foundation

/// Activity figures derived from saved history, which keeps only the latest rewrites.
public struct RewriteStats: Equatable, Sendable {
    public struct Tally: Equatable, Sendable {
        public var grammar = 0
        public var prompt = 0
        public var total: Int { grammar + prompt }
        public init(grammar: Int = 0, prompt: Int = 0) { self.grammar = grammar; self.prompt = prompt }
        mutating func add(_ mode: RewriteMode) { if mode == .grammar { grammar += 1 } else { prompt += 1 } }
    }
    public struct AppUsage: Equatable, Sendable {
        public let name: String
        public let tally: Tally
    }

    public let overall: Tally
    /// Words in the original text Polish was asked to rewrite.
    public let words: Int
    /// The oldest saved rewrite, or nil when history is empty.
    public let since: Date?
    /// Rewrites per weekday, Monday first.
    public let weekdays: [Tally]
    /// Source apps, most used first.
    public let apps: [AppUsage]

    public init(items: [HistoryItem], calendar: Calendar = .current) {
        var overall = Tally()
        var weekdays = Array(repeating: Tally(), count: 7)
        var apps: [String: Tally] = [:]
        var words = 0
        for item in items {
            overall.add(item.mode)
            weekdays[Self.weekdayIndex(of: item.createdAt, calendar: calendar)].add(item.mode)
            apps[item.sourceApp, default: Tally()].add(item.mode)
            words += item.original.split(whereSeparator: \.isWhitespace).count
        }
        self.overall = overall
        self.words = words
        self.since = items.map(\.createdAt).min()
        self.weekdays = weekdays
        self.apps = apps.map { AppUsage(name: $0.key, tally: $0.value) }
            .sorted { $0.tally.total == $1.tally.total ? $0.name < $1.name : $0.tally.total > $1.tally.total }
    }

    /// Monday = 0 … Sunday = 6, independent of the calendar's first weekday.
    public static func weekdayIndex(of date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// Rewrites grouped by the start of their day.
    public static func byDay(_ items: [HistoryItem], calendar: Calendar = .current) -> [Date: Tally] {
        var days: [Date: Tally] = [:]
        for item in items { days[calendar.startOfDay(for: item.createdAt), default: Tally()].add(item.mode) }
        return days
    }
}

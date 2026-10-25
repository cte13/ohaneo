import Foundation

/// Decides whether a day is a phrase or grammar day. Single words are only a
/// fallback for when the phrase list runs out.
public struct MixScheduler: Sendable {
    /// 0–7.
    public var grammarDaysPerWeek: Int
    public var calendar: StudyCalendar

    public init(grammarDaysPerWeek: Int = 2, calendar: StudyCalendar = StudyCalendar()) {
        self.grammarDaysPerWeek = min(max(grammarDaysPerWeek, 0), 7)
        self.calendar = calendar
    }

    /// Grammar weekdays (Monday = 0), spread evenly and starting on Tuesday.
    /// Two days a week gives Tuesday and Friday.
    public var grammarWeekdays: Set<Int> {
        let n = grammarDaysPerWeek
        guard n > 0 else { return [] }
        return Set((0..<n).map { i in (1 + (i * 7) / n) % 7 })
    }

    /// The preferred kind for a day.
    public func kind(for date: Date) -> ItemKind {
        grammarWeekdays.contains(calendar.weekdayIndex(date)) ? .grammar : .phrase
    }

    /// The preferred kind first, then fallbacks for when a list runs out.
    public func kinds(for date: Date) -> [ItemKind] {
        switch kind(for: date) {
        case .grammar: [.grammar, .phrase, .word]
        case .phrase, .word: [.phrase, .word, .grammar]
        }
    }
}

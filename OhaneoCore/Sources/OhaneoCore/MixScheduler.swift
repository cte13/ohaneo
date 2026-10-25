import Foundation

/// Decides whether a day is a word, phrase or grammar day.
public struct MixScheduler: Sendable {
    /// 0–7.
    public var grammarDaysPerWeek: Int
    /// Share of vocab days that show a phrase, 0–100.
    public var phrasePercent: Int
    public var calendar: StudyCalendar

    public init(grammarDaysPerWeek: Int = 2, phrasePercent: Int = 30, calendar: StudyCalendar = StudyCalendar()) {
        self.grammarDaysPerWeek = min(max(grammarDaysPerWeek, 0), 7)
        self.phrasePercent = min(max(phrasePercent, 0), 100)
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
        if grammarWeekdays.contains(calendar.weekdayIndex(date)) { return .grammar }
        return isPhraseDay(date) ? .phrase : .word
    }

    /// The preferred kind first, then fallbacks for when a list runs out.
    public func kinds(for date: Date) -> [ItemKind] {
        switch kind(for: date) {
        case .grammar: [.grammar, .word, .phrase]
        case .phrase: [.phrase, .word, .grammar]
        case .word: [.word, .phrase, .grammar]
        }
    }

    /// Spreads phrase days evenly: stepping the day number by 7 (mod 10) visits every
    /// remainder once per 10 days, so a 30% share lands on about every third day.
    private func isPhraseDay(_ date: Date) -> Bool {
        let slots = Int((Double(phrasePercent) / 10).rounded())
        let value = ((calendar.dayNumber(date) * 7) % 10 + 10) % 10
        return value < slots
    }
}

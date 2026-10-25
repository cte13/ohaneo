import Foundation
import Testing
@testable import OhaneoCore

@Suite struct MixSchedulerTests {
    let cal = Fixtures.calendar

    @Test func twoGrammarDaysAreTuesdayAndFriday() {
        let mix = MixScheduler(grammarDaysPerWeek: 2, calendar: cal)
        #expect(mix.grammarWeekdays == [1, 4])
        // 2026-10-27 is a Tuesday, 2026-10-30 a Friday.
        #expect(mix.kind(for: Fixtures.date(2026, 10, 27)) == .grammar)
        #expect(mix.kind(for: Fixtures.date(2026, 10, 30)) == .grammar)
        #expect(mix.kind(for: Fixtures.date(2026, 10, 28)) != .grammar)
    }

    @Test(arguments: 0...7) func grammarDayCountMatchesSetting(n: Int) {
        let mix = MixScheduler(grammarDaysPerWeek: n, calendar: cal)
        #expect(mix.grammarWeekdays.count == n)
    }

    @Test func grammarDaysNeverAdjacentAtTwoOrThree() {
        for n in [2, 3] {
            let days = MixScheduler(grammarDaysPerWeek: n, calendar: cal).grammarWeekdays
            for d in days { #expect(!days.contains((d + 1) % 7), "n=\(n) has adjacent days") }
        }
    }

    @Test func phraseShareIsAboutThirtyPercentOfVocabDays() {
        let mix = MixScheduler(grammarDaysPerWeek: 2, phrasePercent: 30, calendar: cal)
        let start = Fixtures.date(2026, 1, 1)
        let kinds = (0..<700).map { mix.kind(for: cal.adding(days: $0, to: start)) }
        let vocab = kinds.filter { $0 != .grammar }
        let share = Double(vocab.filter { $0 == .phrase }.count) / Double(vocab.count)
        #expect(abs(share - 0.3) < 0.05)
        #expect(kinds.filter { $0 == .grammar }.count == 200)
    }

    @Test func noPhrasesAtZeroPercent() {
        let mix = MixScheduler(grammarDaysPerWeek: 0, phrasePercent: 0, calendar: cal)
        let start = Fixtures.date(2026, 1, 1)
        #expect((0..<30).allSatisfy { mix.kind(for: cal.adding(days: $0, to: start)) == .word })
    }

    @Test func fallbacksStartWithPreferredKind() {
        let mix = MixScheduler(grammarDaysPerWeek: 7, calendar: cal)
        #expect(mix.kinds(for: Fixtures.date(2026, 10, 27)) == [.grammar, .word, .phrase])
    }
}

@Suite struct ReviewSchedulerTests {
    let cal = Fixtures.calendar
    var scheduler: ReviewScheduler { ReviewScheduler(calendar: cal) }
    let today = Fixtures.date(2026, 10, 25, hour: 22)

    @Test func learningStartsInBoxOneDueTomorrow() {
        let state = scheduler.startLearning(today: today)
        #expect(state == ReviewState(status: .learning, box: 1, nextReviewAt: cal.adding(days: 1, to: today)))
    }

    @Test func gotItWalksUpTheBoxesThenKnown() {
        var state = scheduler.startLearning(today: today)
        var day = today
        var gaps: [Int] = []
        while state.status == .learning {
            let due = state.nextReviewAt!
            gaps.append(cal.daysBetween(day, due))
            day = due
            state = scheduler.answer(.gotIt, box: state.box, today: day)
        }
        #expect(gaps == [1, 3, 7, 21])
        #expect(state == ReviewState(status: .known, box: 0, nextReviewAt: nil))
    }

    @Test func notYetDropsOneBoxAndComesBackTomorrow() {
        let state = scheduler.answer(.notYet, box: 3, today: today)
        #expect(state.box == 2)
        #expect(state.nextReviewAt == cal.adding(days: 1, to: today))
        #expect(scheduler.answer(.notYet, box: 1, today: today).box == 1)
    }

    @Test func dueTodayIsMostOverdueFirstAndCapped() {
        let d = { (n: Int) in cal.adding(days: n, to: today) }
        let candidates = [
            ReviewCandidate(id: "a", box: 2, nextReviewAt: d(-1)),
            ReviewCandidate(id: "b", box: 1, nextReviewAt: d(-5)),
            ReviewCandidate(id: "c", box: 1, nextReviewAt: d(0)),
            ReviewCandidate(id: "d", box: 3, nextReviewAt: d(-3)),
            ReviewCandidate(id: "e", box: 1, nextReviewAt: d(1)),
        ]
        #expect(scheduler.dueToday(candidates, today: today).map(\.id) == ["b", "d", "a"])
    }

    @Test func capCountsReviewsAlreadyAnsweredToday() {
        let candidates = [
            ReviewCandidate(id: "done1", box: 2, nextReviewAt: cal.adding(days: 3, to: today), lastReviewedAt: today),
            ReviewCandidate(id: "done2", box: 2, nextReviewAt: cal.adding(days: 3, to: today), lastReviewedAt: today),
            ReviewCandidate(id: "x", box: 1, nextReviewAt: cal.adding(days: -2, to: today)),
            ReviewCandidate(id: "y", box: 1, nextReviewAt: cal.adding(days: -1, to: today)),
        ]
        #expect(scheduler.dueToday(candidates, today: today).map(\.id) == ["x"])
    }
}

@Suite struct StudyCalendarTests {
    @Test func daysBetweenSurvivesDaylightSaving() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let sc = StudyCalendar(calendar: cal)
        let before = cal.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23))!
        let after = cal.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 30))!
        #expect(sc.daysBetween(before, after) == 2)
        #expect(sc.adding(days: 1, to: before) == cal.date(from: DateComponents(year: 2026, month: 3, day: 8)))
    }

    @Test func weekdayIndexStartsMonday() {
        #expect(Fixtures.calendar.weekdayIndex(Fixtures.date(2026, 10, 26)) == 0)
        #expect(Fixtures.calendar.weekdayIndex(Fixtures.date(2026, 10, 25)) == 6)
    }
}

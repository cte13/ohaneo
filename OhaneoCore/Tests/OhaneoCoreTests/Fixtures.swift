import Foundation
@testable import OhaneoCore

enum Fixtures {
    /// Fixed Gregorian calendar in Seoul, so tests don't depend on the machine.
    static var calendar: StudyCalendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return StudyCalendar(calendar: cal)
    }

    /// A local date in the fixture calendar.
    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        calendar.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func words(_ count: Int) -> [SeedWord] {
        (1...count).map { SeedWord(id: "w:\($0)", korean: "단어\($0)", meaning: "word \($0)", rank: $0) }
    }

    static func phrases(_ count: Int) -> [SeedWord] {
        (1...count).map { SeedWord(id: "p:\($0)", korean: "표현\($0)", kind: .phrase, meaning: "phrase \($0)", rank: $0) }
    }

    static let grammar: [GrammarPattern] = [
        pattern("g:ayo", order: 10, assumed: true),
        pattern("g:jiman", order: 20, assumed: true),
        pattern("g:aseo", order: 30, prerequisites: ["g:ayo"]),
        pattern("g:nikka", order: 40, prerequisites: ["g:aseo"]),
        pattern("g:neunde", order: 50, prerequisites: ["g:jiman"]),
        pattern("g:myeonseo", order: 60, prerequisites: ["g:neunde"]),
    ]

    static func pattern(_ id: String, order: Int, prerequisites: [String] = [], assumed: Bool = false) -> GrammarPattern {
        GrammarPattern(
            id: id, pattern: id, meaning: "meaning of \(id)", order: order,
            prerequisites: prerequisites,
            formation: [FormationRule(appliesTo: .verb, form: "-x", example: "가x")],
            assumedKnown: assumed
        )
    }

    static func library(words: Int = 100, phrases: Int = 10) -> SeedLibrary {
        SeedLibrary(words: self.words(words), phrases: self.phrases(phrases), grammar: grammar)
    }
}

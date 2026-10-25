import Foundation
import Testing
@testable import OhaneoCore

@Suite struct CourseTests {
    @Test func stagesFollowTheNextClass() {
        #expect(CourseBook.stage(of: 13, nextClass: 13) == .next)
        #expect(CourseBook.stage(of: 12, nextClass: 13) == .current)
        #expect(CourseBook.stage(of: 11, nextClass: 13) == .review)
        #expect(CourseBook.stage(of: 14, nextClass: 13) == .later)
    }

    @Test func drillRepeatsMissedCardsUntilEachIsKnown() {
        let words = ["가", "나", "다"].map { DrillWord(korean: $0, english: nil) }
        var session = DrillSession(words: words)
        session.again()            // 가 to the back
        session.gotIt()            // 나
        #expect(session.current?.korean == "다")
        session.gotIt()            // 다
        #expect(session.current?.korean == "가")
        session.gotIt()
        #expect(session.isFinished)
        #expect(session.done.count == 3)
        #expect(session.missed.map(\.korean) == ["가"])
    }

    @Test func lessonDecodesWithOptionalPartsMissing() throws {
        let json = """
        {"number": 11, "title": "제목", "goals": [], "expressions": [], "exercises": [],
         "vocabulary": [{"topic": "음식", "words": [{"korean": "김밥", "english": "gimbap"}]}],
         "grammar": [{"pattern": "-어서"}],
         "reading": {"text": "글", "glossary": [{"korean": "김밥", "english": "gimbap"}, {"korean": "김치", "english": "kimchi"}]}}
        """
        let lesson = try JSONDecoder().decode(Lesson.self, from: Data(json.utf8))
        // Words appear once, topic words first.
        #expect(lesson.drillWords.map(\.korean) == ["김밥", "김치"])
    }
}

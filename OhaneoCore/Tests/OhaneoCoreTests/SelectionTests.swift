import Foundation
import Testing
@testable import OhaneoCore

@Suite struct SelectorTests {
    let library = Fixtures.library()

    @Test func wordsStartAtPlacementRankAfterPriorityWords() {
        let placement = PlacementResult(startRank: 40, knownWordIDs: ["w:40"], priorityWordIDs: ["w:5", "w:12"])
        let selector = WordSelector(library: library)
        #expect(selector.next(kind: .word, placement: placement, excluded: [])?.id == "w:5")
        #expect(selector.next(kind: .word, placement: placement, excluded: ["w:5", "w:12"])?.id == "w:41")
    }

    @Test func phrasesIgnorePlacement() {
        let placement = PlacementResult(startRank: 40)
        #expect(WordSelector(library: library).next(kind: .phrase, placement: placement, excluded: ["p:1"])?.id == "p:2")
    }

    @Test func topicsArePreferredWithinWindow() {
        var phrases = Fixtures.phrases(10)
        phrases[3].topics = ["food"]
        let lib = SeedLibrary(words: [], phrases: phrases, grammar: [])
        #expect(WordSelector(library: lib).next(kind: .phrase, placement: nil, excluded: [], topics: ["food"])?.id == "p:4")
    }

    @Test func grammarWaitsForPrerequisites() {
        let selector = GrammarSelector(library: library)
        // -아서 needs only an assumed pattern, so it comes first.
        #expect(selector.next(seen: [], known: [], excluded: [])?.id == "g:aseo")
        // -니까 needs -아서; -는데 needs only an assumed one.
        #expect(selector.next(seen: [], known: [], excluded: ["g:aseo"])?.id == "g:neunde")
        #expect(selector.next(seen: ["g:aseo"], known: [], excluded: ["g:aseo"])?.id == "g:nikka")
    }

    @Test func grammarKnownFromPlacementIsSkippedButUnlocksOthers() {
        let selector = GrammarSelector(library: library)
        let next = selector.next(seen: [], known: ["g:aseo", "g:neunde"], excluded: [])
        #expect(next?.id == "g:nikka")
    }
}

@Suite struct PlannerTests {
    let cal = Fixtures.calendar
    let today = Fixtures.date(2026, 10, 25)

    func planner(placement: PlacementResult? = PlacementResult(startRank: 1)) -> DailyPlanner {
        var prefs = StudyPreferences()
        prefs.placement = placement
        return DailyPlanner(library: Fixtures.library(), preferences: prefs, calendar: cal)
    }

    @Test func historyAndReservedSeedsAreExcluded() {
        let history = [HistoryEntry(seedID: "w:1", kind: .word, korean: "단어1", status: .known)]
        let seed = planner().nextSeed(kinds: [.word], history: history, reserved: ["w:2"], today: today)
        #expect(seed?.id == "w:3")
    }

    @Test func skippedItemsReturnAfterThirtyDays() {
        let recent = HistoryEntry(seedID: "w:1", kind: .word, korean: "", status: .skipped, markedAt: cal.adding(days: -29, to: today))
        let old = HistoryEntry(seedID: "w:2", kind: .word, korean: "", status: .skipped, markedAt: cal.adding(days: -30, to: today))
        let excluded = planner().excludedIDs(history: [recent, old], today: today)
        #expect(excluded == ["w:1"])
    }

    @Test func fallsBackWhenAKindRunsOut() {
        let history = Fixtures.phrases(10).map { HistoryEntry(seedID: $0.id, kind: .phrase, korean: $0.korean, status: .known) }
        let seed = planner().nextSeed(kinds: [.phrase, .word, .grammar], history: history, today: today)
        #expect(seed?.kind == .word)
    }

    @Test func upcomingGrammarCountsAsSeenOnlyOnceShown() {
        let upcoming = HistoryEntry(seedID: "g:aseo", kind: .grammar, korean: "", status: .upcoming)
        let shown = HistoryEntry(seedID: "g:aseo", kind: .grammar, korean: "", status: .new)
        let p = planner()
        #expect(p.nextSeed(kinds: [.grammar], history: [upcoming], today: today)?.id == "g:neunde")
        #expect(p.nextSeed(kinds: [.grammar], history: [shown], today: today)?.id == "g:nikka")
    }

    @Test func exampleVocabularyWorksOnDayOne() {
        let vocab = planner(placement: PlacementResult(startRank: 50)).exampleVocabulary(history: [], today: today, limit: 10)
        #expect(vocab.count == 10)
        #expect(Set(vocab).count == 10)
    }

    @Test func exampleVocabularyPrefersRecentLearningWords() {
        let history = [
            HistoryEntry(seedID: "w:60", kind: .word, korean: "최근", status: .learning, markedAt: today),
            HistoryEntry(seedID: "w:61", kind: .word, korean: "건너뜀", status: .skipped, markedAt: today),
        ]
        let vocab = planner(placement: PlacementResult(startRank: 50)).exampleVocabulary(history: history, today: today, limit: 6)
        #expect(vocab.first == "최근")
        #expect(!vocab.contains("건너뜀"))
    }

    @Test func upcomingKindsCoverNextThreeDays() {
        // Sunday → Mon (vocab), Tue (grammar), Wed (vocab).
        let kinds = planner().upcomingKinds(after: today)
        #expect(kinds.count == 3)
        #expect(kinds[1] == .grammar)
        #expect(kinds[0] != .grammar && kinds[2] != .grammar)
    }
}

@Suite struct PlacementTests {
    let library = Fixtures.library(words: 1000)

    @Test func planSamplesEachBandInOrder() {
        let plan = Placement.plan(library: library)
        #expect(plan.bands.count == 5)
        #expect(plan.bands.allSatisfy { $0.count == Placement.wordsPerBand })
        let ranks = plan.words.map(\.rank)
        #expect(ranks == ranks.sorted())
        #expect(plan.grammar.allSatisfy { !$0.assumedKnown })
    }

    @Test func startsAtFirstBandUnderHalfKnown() {
        let plan = Placement.plan(library: library)
        // Know every word in bands 0 and 1, two of six in band 2.
        var known = Set(plan.bands[0].map(\.id) + plan.bands[1].map(\.id))
        known.formUnion(plan.bands[2].prefix(2).map(\.id))
        known.insert(plan.bands[3][0].id)
        let result = Placement.result(plan: plan, knownWordIDs: known, knownGrammarIDs: [], library: library)
        #expect(result.startRank == 251) // band 2 starts at 25%
        #expect(result.knownWordIDs.contains(plan.bands[3][0].id))
        #expect(result.priorityWordIDs.isEmpty)
    }

    @Test func unknownWordsBelowStartBecomePriority() {
        let plan = Placement.plan(library: library)
        let missed = plan.bands[0][0].id
        let known = Set(plan.bands[0].dropFirst().map(\.id))
        let result = Placement.result(plan: plan, knownWordIDs: known, knownGrammarIDs: [], library: library)
        #expect(result.startRank == 101)
        #expect(result.priorityWordIDs == [missed])
    }

    @Test func knowingNothingStartsAtTheBeginning() {
        let plan = Placement.plan(library: library)
        let result = Placement.result(plan: plan, knownWordIDs: [], knownGrammarIDs: [], library: library)
        #expect(result.startRank == 1)
    }

    @Test func knownGrammarIncludesPrerequisites() {
        let plan = Placement.plan(library: library)
        let result = Placement.result(plan: plan, knownWordIDs: [], knownGrammarIDs: ["g:nikka"], library: library)
        #expect(result.knownGrammarIDs == ["g:nikka", "g:aseo", "g:ayo"])
    }
}

@Suite struct CheckedGeneratorTests {
    actor Script: ContentGenerator {
        var responses: [[Example]]
        var calls = 0
        init(_ responses: [[Example]]) { self.responses = responses }

        func vocabContent(for word: SeedWord, vocabulary: [String]) async throws -> VocabContent {
            VocabContent(examples: next())
        }

        func grammarExamples(for pattern: GrammarPattern, vocabulary: [String]) async throws -> [Example] {
            next()
        }

        private func next() -> [Example] {
            defer { calls += 1 }
            return responses[min(calls, responses.count - 1)]
        }
    }

    let good1 = Example(korean: "가는데 좋아요", english: "", highlight: "가는데")
    let good2 = Example(korean: "먹는데 맛있어요", english: "", highlight: "먹는데")
    let bad = Example(korean: "가니까 좋아요", english: "", highlight: "가는데")
    let pattern = Fixtures.grammar[2]

    @Test func validExamplesNeedOneCall() async throws {
        let script = Script([[good1, good2]])
        let result = try await CheckedGenerator(base: script).grammarExamples(for: pattern, vocabulary: [])
        #expect(result == [good1, good2])
        #expect(await script.calls == 1)
    }

    @Test func badExampleIsReplacedFromRetry() async throws {
        let script = Script([[good1, bad], [bad, good2]])
        let result = try await CheckedGenerator(base: script).grammarExamples(for: pattern, vocabulary: [])
        #expect(result == [good1, good2])
        #expect(await script.calls == 2)
    }

    @Test func dictionaryFormOfAPredicateIsRejected() {
        let word = SeedWord(id: "w:1", korean: "어떻다", meaning: "how", partOfSpeech: "adjective", rank: 1)
        #expect(!Example(korean: "영화가 너무 어떻다!", english: "", highlight: "어떻다").isValid(for: word))
        #expect(!Example(korean: "날씨가 어때요? 어떻다", english: "", highlight: "어때요").isValid(for: word))
        #expect(Example(korean: "날씨가 어때요?", english: "", highlight: "어때요").isValid(for: word))
        #expect(Example(korean: "그 영화가 어떻다고 했어요?", english: "", highlight: "어떻다고").isValid(for: word))
        let noun = SeedWord(id: "w:2", korean: "학교", meaning: "school", partOfSpeech: "noun", rank: 2)
        #expect(Example(korean: "학교에 가요.", english: "", highlight: "학교").isValid(for: noun))
    }

    @Test func unconjugatedVocabExampleIsReplacedFromRetry() async throws {
        let bad = Example(korean: "영화가 너무 어떻다!", english: "", highlight: "어떻다")
        let good = Example(korean: "그 영화 어땠어요?", english: "", highlight: "어땠어요")
        let script = Script([[bad], [good]])
        let word = SeedWord(id: "w:1", korean: "어떻다", meaning: "how", partOfSpeech: "adjective", rank: 1)
        let result = try await CheckedGenerator(base: script).vocabContent(for: word, vocabulary: [])
        #expect(result.examples == [good])
    }

    @Test func stillBadAfterRetryIsDropped() async throws {
        let script = Script([[good1, bad], [bad]])
        let word = SeedWord(id: "w:1", korean: "가다", meaning: "go", rank: 1)
        let result = try await CheckedGenerator(base: script).vocabContent(for: word, vocabulary: [])
        #expect(result.examples == [good1])
    }
}

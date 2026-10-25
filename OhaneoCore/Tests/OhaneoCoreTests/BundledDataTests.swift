import Foundation
import Testing
@testable import OhaneoCore

@Suite struct BundledDataTests {
    @Test func bundledListsLoadAndValidate() throws {
        let library = try SeedLibrary.bundled()
        #expect(library.words.count > 5000)
        #expect(!library.phrases.isEmpty)
        #expect(!library.grammar.isEmpty)
        #expect(library.validate() == [])
    }

    @Test func checkedOnlyGrammarIsConsistent() throws {
        let library = try SeedLibrary.bundled().checkedOnly()
        #expect(library.validate() == [])
    }

    @Test func wordRanksAreUniqueAndStartAtOne() throws {
        let library = try SeedLibrary.bundled()
        let ranks = library.words.map(\.rank)
        #expect(ranks.first == 1)
        #expect(Set(ranks).count == ranks.count)
        let phraseRanks = library.phrases.map(\.rank)
        #expect(Set(phraseRanks).count == phraseRanks.count)
    }

    @Test func phrasesListOnlyKnownWords() {
        var phrase = Fixtures.phrases(1)[0]
        phrase.wordIDs = ["w:1", "w:999"]
        let lib = SeedLibrary(words: Fixtures.words(5), phrases: [phrase], grammar: [])
        #expect(lib.validate() == ["p:1 lists unknown word w:999"])
        #expect(lib.words(in: phrase).map(\.id) == ["w:1"])
    }

    @Test func noRomanizationInKorean() throws {
        let library = try SeedLibrary.bundled()
        let latin = (library.words + library.phrases).filter { $0.korean.range(of: "[A-Za-z]", options: .regularExpression) != nil }
        #expect(latin.map(\.korean) == [])
        let patterns = library.grammar.filter { $0.pattern.range(of: "[A-Za-z]", options: .regularExpression) != nil }
        #expect(patterns.map(\.pattern) == [])
    }

    @Test func verbsAndAdjectivesHaveForms() throws {
        let library = try SeedLibrary.bundled()
        let predicates = library.words.filter(\.isPredicate)
        let missing = predicates.filter { $0.forms == nil }.map(\.korean)
        #expect(missing.count < 20, "missing forms: \(missing.prefix(20))")
        let eotteota = try #require(library.words.first { $0.korean == "어떻다" })
        #expect(eotteota.forms == WordForms(polite: "어때요", politePast: "어땠어요", formal: "어떻습니다"))
        #expect(!eotteota.meaning.contains("such"))
    }

    @Test func placementPlanFromBundledData() throws {
        let plan = Placement.plan(library: try SeedLibrary.bundled())
        #expect(plan.words.count == 30)
        #expect(plan.grammar.count <= 10)
    }
}

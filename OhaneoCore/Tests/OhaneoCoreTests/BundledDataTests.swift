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

    @Test func noRomanizationInKorean() throws {
        let library = try SeedLibrary.bundled()
        let latin = (library.words + library.phrases).filter { $0.korean.range(of: "[A-Za-z]", options: .regularExpression) != nil }
        #expect(latin.map(\.korean) == [])
        let patterns = library.grammar.filter { $0.pattern.range(of: "[A-Za-z]", options: .regularExpression) != nil }
        #expect(patterns.map(\.pattern) == [])
    }

    @Test func placementPlanFromBundledData() throws {
        let plan = Placement.plan(library: try SeedLibrary.bundled())
        #expect(plan.words.count == 30)
        #expect(plan.grammar.count <= 10)
    }
}

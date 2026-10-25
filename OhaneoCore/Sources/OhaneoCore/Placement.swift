import Foundation

/// The outcome of the placement swipe.
public struct PlacementResult: Codable, Equatable, Sendable {
    /// Words ranked below this are assumed known.
    public var startRank: Int
    /// Words at or above `startRank` you said you know. Never shown.
    public var knownWordIDs: Set<String>
    /// Words below `startRank` you said you don't know. Shown first.
    public var priorityWordIDs: [String]
    /// Grammar you said you know, plus everything it builds on.
    public var knownGrammarIDs: Set<String>

    public init(startRank: Int, knownWordIDs: Set<String> = [], priorityWordIDs: [String] = [], knownGrammarIDs: Set<String> = []) {
        self.startRank = startRank
        self.knownWordIDs = knownWordIDs
        self.priorityWordIDs = priorityWordIDs
        self.knownGrammarIDs = knownGrammarIDs
    }
}

/// Which words and patterns the placement swipe asks about.
public struct PlacementPlan: Sendable, Equatable {
    /// Sampled words for each frequency band, easiest band first.
    public var bands: [[SeedWord]]
    public var grammar: [GrammarPattern]

    public var words: [SeedWord] { bands.flatMap { $0 } }
}

public enum Placement {
    /// Band edges as fractions of the word list. Narrow at the start, where the
    /// starting point matters most for an upper beginner.
    public static let bandEdges: [Double] = [0, 0.10, 0.25, 0.45, 0.70, 1.0]
    public static let wordsPerBand = 6
    public static let grammarCount = 10

    public static func plan(library: SeedLibrary) -> PlacementPlan {
        let words = library.words
        var bands: [[SeedWord]] = []
        for i in 0..<(bandEdges.count - 1) {
            let lower = Int(Double(words.count) * bandEdges[i])
            let upper = Int(Double(words.count) * bandEdges[i + 1])
            guard upper > lower else { continue }
            let band = Array(words[lower..<upper])
            let n = min(wordsPerBand, band.count)
            // Evenly spaced, centered within each slice of the band.
            let samples = (0..<n).map { j in band[(j * band.count + band.count / 2) / n] }
            bands.append(samples)
        }
        let grammar = library.grammar.filter { !$0.assumedKnown }.prefix(grammarCount)
        return PlacementPlan(bands: bands, grammar: Array(grammar))
    }

    /// Starts at the first band where you know fewer than half the sampled words.
    public static func result(
        plan: PlacementPlan,
        knownWordIDs: Set<String>,
        knownGrammarIDs: Set<String>,
        library: SeedLibrary
    ) -> PlacementResult {
        let startBand = plan.bands.firstIndex { band in
            let known = band.filter { knownWordIDs.contains($0.id) }.count
            return known * 2 < band.count
        } ?? max(plan.bands.count - 1, 0)

        let startRank = plan.bands.indices.contains(startBand)
            ? bandStartRank(band: startBand, library: library)
            : 1

        let sampled = plan.words
        let knownAbove = sampled.filter { $0.rank >= startRank && knownWordIDs.contains($0.id) }.map(\.id)
        let unknownBelow = sampled.filter { $0.rank < startRank && !knownWordIDs.contains($0.id) }.map(\.id)

        var grammar = Set<String>()
        func addWithPrerequisites(_ id: String) {
            guard grammar.insert(id).inserted, let pattern = library.pattern(id: id) else { return }
            pattern.prerequisites.forEach(addWithPrerequisites)
        }
        knownGrammarIDs.forEach(addWithPrerequisites)

        return PlacementResult(
            startRank: startRank,
            knownWordIDs: Set(knownAbove),
            priorityWordIDs: unknownBelow,
            knownGrammarIDs: grammar
        )
    }

    private static func bandStartRank(band: Int, library: SeedLibrary) -> Int {
        let index = Int(Double(library.words.count) * bandEdges[band])
        return library.words.indices.contains(index) ? library.words[index].rank : 1
    }
}

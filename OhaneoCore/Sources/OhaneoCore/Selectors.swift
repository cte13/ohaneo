import Foundation

/// Picks the next word or phrase: placement leftovers first, then list order.
public struct WordSelector: Sendable {
    public var library: SeedLibrary

    public init(library: SeedLibrary) {
        self.library = library
    }

    public func next(kind: ItemKind, placement: PlacementResult?, excluded: Set<String>, topics: Set<String> = []) -> SeedWord? {
        switch kind {
        case .word:
            let placement = placement ?? PlacementResult(startRank: 1)
            for id in placement.priorityWordIDs where !excluded.contains(id) {
                if let word = library.word(id: id) { return word }
            }
            let candidates = library.words.lazy.filter {
                $0.rank >= placement.startRank
                    && !excluded.contains($0.id)
                    && !placement.knownWordIDs.contains($0.id)
            }
            return preferTopics(candidates, topics: topics)
        case .phrase:
            return preferTopics(library.phrases.lazy.filter { !excluded.contains($0.id) }, topics: topics)
        case .grammar:
            return nil
        }
    }

    /// The first item matching a chosen topic within the next 50, else the first item.
    private func preferTopics<S: Sequence>(_ items: S, topics: Set<String>) -> SeedWord? where S.Element == SeedWord {
        guard !topics.isEmpty else { return items.first { _ in true } }
        let window = Array(items.prefix(50))
        return window.first { !topics.isDisjoint(with: $0.topics) } ?? window.first
    }
}

/// Picks the next grammar pattern: curriculum order, prerequisites first.
public struct GrammarSelector: Sendable {
    public var library: SeedLibrary

    public init(library: SeedLibrary) {
        self.library = library
    }

    /// - Parameters:
    ///   - seen: patterns already shown, in any status.
    ///   - known: patterns marked known in placement.
    ///   - excluded: patterns that can't be picked now.
    public func next(seen: Set<String>, known: Set<String>, excluded: Set<String>) -> GrammarPattern? {
        let assumed = Set(library.grammar.filter(\.assumedKnown).map(\.id))
        let satisfied = seen.union(known).union(assumed)
        return library.grammar.first { pattern in
            !pattern.assumedKnown
                && !known.contains(pattern.id)
                && !excluded.contains(pattern.id)
                && pattern.prerequisites.allSatisfy(satisfied.contains)
        }
    }
}

import Foundation

/// The bundled word, phrase and grammar lists.
public struct SeedLibrary: Sendable {
    /// Words sorted by rank.
    public let words: [SeedWord]
    /// Phrases sorted by rank.
    public let phrases: [SeedWord]
    /// Grammar sorted by curriculum order.
    public let grammar: [GrammarPattern]

    private let wordsByID: [String: SeedWord]
    private let grammarByID: [String: GrammarPattern]

    public init(words: [SeedWord], phrases: [SeedWord] = [], grammar: [GrammarPattern]) {
        self.words = words.sorted { $0.rank < $1.rank }
        self.phrases = phrases.sorted { $0.rank < $1.rank }
        self.grammar = grammar.sorted { $0.order < $1.order }
        self.wordsByID = Dictionary((words + phrases).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.grammarByID = Dictionary(grammar.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    public func word(id: String) -> SeedWord? { wordsByID[id] }
    public func pattern(id: String) -> GrammarPattern? { grammarByID[id] }

    /// The dictionary words a phrase is built from, in phrase order.
    public func words(in phrase: SeedWord) -> [SeedWord] {
        (phrase.wordIDs ?? []).compactMap { wordsByID[$0] }.filter { $0.kind == .word }
    }

    public func seed(id: String) -> Seed? {
        if let w = wordsByID[id] { return .word(w) }
        if let g = grammarByID[id] { return .grammar(g) }
        return nil
    }

    /// The same library with unchecked grammar removed.
    public func checkedOnly() -> SeedLibrary {
        SeedLibrary(words: words, phrases: phrases, grammar: grammar.filter(\.checked))
    }

    // MARK: Loading

    private struct ListFile<Item: Decodable>: Decodable {
        var items: [Item]
    }

    public static func load(words: URL, phrases: URL?, grammar: URL) throws -> SeedLibrary {
        let decoder = JSONDecoder()
        let w = try decoder.decode(ListFile<SeedWord>.self, from: Data(contentsOf: words)).items
        let p = try phrases.map { try decoder.decode(ListFile<SeedWord>.self, from: Data(contentsOf: $0)).items } ?? []
        let g = try decoder.decode(ListFile<GrammarPattern>.self, from: Data(contentsOf: grammar)).items
        return SeedLibrary(words: w, phrases: p, grammar: g)
    }

    public enum LoadError: Error {
        case missingResource(String)
    }

    /// The lists bundled with this package.
    public static func bundled() throws -> SeedLibrary {
        func url(_ name: String) throws -> URL {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
                throw LoadError.missingResource(name)
            }
            return url
        }
        return try load(words: url("words"), phrases: url("phrases"), grammar: url("grammar"))
    }

    // MARK: Validation

    /// Problems with the data. Empty when the lists are consistent.
    public func validate() -> [String] {
        var problems: [String] = []

        let allIDs = (words + phrases).map(\.id) + grammar.map(\.id)
        let duplicates = Dictionary(grouping: allIDs, by: { $0 }).filter { $1.count > 1 }.keys
        problems += duplicates.sorted().map { "duplicate id \($0)" }

        for w in words where w.kind != .word { problems.append("\(w.id) in words list has kind \(w.kind)") }
        for p in phrases where p.kind != .phrase { problems.append("\(p.id) in phrases list has kind \(p.kind)") }
        for w in words + phrases where w.korean.isEmpty || w.meaning.isEmpty {
            problems.append("\(w.id) is missing Korean or meaning")
        }

        let wordIDs = Set(words.map(\.id))
        for p in phrases {
            for id in p.wordIDs ?? [] where !wordIDs.contains(id) {
                problems.append("\(p.id) lists unknown word \(id)")
            }
        }
        for w in words where w.wordIDs != nil { problems.append("\(w.id) is a word but lists words") }

        for g in grammar {
            for p in g.prerequisites {
                guard let pre = grammarByID[p] else {
                    problems.append("\(g.id) has unknown prerequisite \(p)")
                    continue
                }
                if pre.order >= g.order { problems.append("\(g.id) prerequisite \(p) is not earlier in order") }
                if g.checked && !pre.checked && !pre.assumedKnown {
                    problems.append("\(g.id) is checked but its prerequisite \(p) is not")
                }
            }
            for c in g.contrasts where grammarByID[c.patternID] == nil {
                problems.append("\(g.id) contrasts with unknown pattern \(c.patternID)")
            }
            if g.formation.isEmpty { problems.append("\(g.id) has no formation rules") }
        }

        if let cycle = prerequisiteCycle() { problems.append("prerequisite cycle through \(cycle)") }
        return problems
    }

    private func prerequisiteCycle() -> String? {
        var state: [String: Int] = [:] // 1 = visiting, 2 = done
        func visit(_ id: String) -> String? {
            if state[id] == 2 { return nil }
            if state[id] == 1 { return id }
            state[id] = 1
            for p in grammarByID[id]?.prerequisites ?? [] {
                if let found = visit(p) { return found }
            }
            state[id] = 2
            return nil
        }
        for g in grammar {
            if let found = visit(g.id) { return found }
        }
        return nil
    }
}

import Foundation

/// The AI-written parts of a vocab card.
public struct VocabContent: Sendable, Equatable {
    public var examples: [Example]
    public var nuance: String?
    public var mnemonic: String?

    public init(examples: [Example], nuance: String? = nil, mnemonic: String? = nil) {
        self.examples = examples
        self.nuance = nuance
        self.mnemonic = mnemonic
    }
}

/// Writes the personalized parts of a card. Facts (meaning, formation rules)
/// always come from the bundled lists, never from here.
public protocol ContentGenerator: Sendable {
    /// - Parameter vocabulary: words the learner knows, to reuse in examples.
    func vocabContent(for word: SeedWord, vocabulary: [String]) async throws -> VocabContent
    func grammarExamples(for pattern: GrammarPattern, vocabulary: [String]) async throws -> [Example]
}

/// Wraps a generator and enforces the highlight check: each example must contain
/// its highlight text. If any example fails, the request runs once more and the
/// failures are replaced from the second attempt; anything still failing is dropped.
public struct CheckedGenerator: ContentGenerator {
    public let base: any ContentGenerator

    public init(base: any ContentGenerator) {
        self.base = base
    }

    public func vocabContent(for word: SeedWord, vocabulary: [String]) async throws -> VocabContent {
        var first = try await base.vocabContent(for: word, vocabulary: vocabulary)
        let wanted = first.examples.count
        let valid = first.examples.filter(\.hasValidHighlight)
        guard valid.count < wanted else { return first }
        let retry = (try? await base.vocabContent(for: word, vocabulary: vocabulary))?.examples ?? []
        first.examples = Self.fill(valid, from: retry, upTo: wanted)
        return first
    }

    public func grammarExamples(for pattern: GrammarPattern, vocabulary: [String]) async throws -> [Example] {
        let first = try await base.grammarExamples(for: pattern, vocabulary: vocabulary)
        let valid = first.filter(\.hasValidHighlight)
        guard valid.count < first.count else { return first }
        let retry = (try? await base.grammarExamples(for: pattern, vocabulary: vocabulary)) ?? []
        return Self.fill(valid, from: retry, upTo: first.count)
    }

    static func fill(_ valid: [Example], from retry: [Example], upTo count: Int) -> [Example] {
        var result = valid
        for example in retry where example.hasValidHighlight && result.count < count {
            if !result.contains(where: { $0.korean == example.korean }) { result.append(example) }
        }
        return result
    }
}

/// Fixed content for previews, tests and simulators without Apple Intelligence.
public struct FakeContentGenerator: ContentGenerator {
    public var delay: Duration

    public init(delay: Duration = .zero) {
        self.delay = delay
    }

    public func vocabContent(for word: SeedWord, vocabulary: [String]) async throws -> VocabContent {
        try await Task.sleep(for: delay)
        let friend = vocabulary.first ?? "친구"
        return VocabContent(
            examples: [
                Example(korean: "오늘 \(friend)하고 \(word.korean) 이야기를 했어요.", english: "Today I talked about “\(word.meaning)” with \(friend).", highlight: word.korean),
                Example(korean: "\(word.korean)? 처음 들어 봤어요.", english: "“\(word.meaning)”? I've never heard that before.", highlight: word.korean),
            ],
            nuance: "Sample note: in real use the on-device model explains when and how people say “\(word.korean)”.",
            mnemonic: "Sample memory hook for “\(word.meaning)”."
        )
    }

    public func grammarExamples(for pattern: GrammarPattern, vocabulary: [String]) async throws -> [Example] {
        try await Task.sleep(for: delay)
        return pattern.formation.prefix(3).map { rule in
            Example(korean: "\(rule.example) 예문이에요.", english: "A sample sentence using \(rule.example).", highlight: rule.example)
        }
    }
}

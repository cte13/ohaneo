import Foundation

/// Learner level, matching the NIKL 초급 / 중급 / 고급 grading.
public enum Level: String, Codable, CaseIterable, Comparable, Sendable {
    case beginner, intermediate, advanced

    public var korean: String {
        switch self {
        case .beginner: "초급"
        case .intermediate: "중급"
        case .advanced: "고급"
        }
    }

    private var order: Int {
        switch self {
        case .beginner: 0
        case .intermediate: 1
        case .advanced: 2
        }
    }

    public static func < (lhs: Level, rhs: Level) -> Bool { lhs.order < rhs.order }
}

public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case word, phrase, grammar

    public var isVocab: Bool { self != .grammar }
}

public enum ItemStatus: String, Codable, CaseIterable, Sendable {
    /// Prepared ahead of time, not shown yet.
    case upcoming
    /// Shown, no response yet.
    case new
    case learning
    case known
    case skipped
}

/// One example sentence. `highlight` is the exact text in `korean` to emphasize.
public struct Example: Codable, Hashable, Sendable {
    public var korean: String
    public var english: String
    public var highlight: String?

    public init(korean: String, english: String, highlight: String? = nil) {
        self.korean = korean
        self.english = english
        self.highlight = highlight
    }

    /// True when there is a highlight and it appears in the sentence.
    public var hasValidHighlight: Bool {
        guard let highlight, !highlight.isEmpty else { return false }
        return korean.contains(highlight)
    }
}

/// A word or phrase from the bundled lists.
public struct SeedWord: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var korean: String
    public var kind: ItemKind
    public var meaning: String
    public var definition: String?
    public var partOfSpeech: String?
    public var hanja: String?
    public var level: Level
    /// Presentation order within its list. Lower comes first.
    public var rank: Int
    public var topics: [String]

    public init(
        id: String, korean: String, kind: ItemKind = .word, meaning: String,
        definition: String? = nil, partOfSpeech: String? = nil, hanja: String? = nil,
        level: Level = .beginner, rank: Int, topics: [String] = []
    ) {
        self.id = id
        self.korean = korean
        self.kind = kind
        self.meaning = meaning
        self.definition = definition
        self.partOfSpeech = partOfSpeech
        self.hanja = hanja
        self.level = level
        self.rank = rank
        self.topics = topics
    }
}

public enum FormationTarget: String, Codable, CaseIterable, Sendable {
    case verb, adjective, noun, past

    public var label: String {
        switch self {
        case .verb: "Verb"
        case .adjective: "Adjective"
        case .noun: "Noun"
        case .past: "Past"
        }
    }
}

public struct FormationRule: Codable, Hashable, Sendable {
    public var appliesTo: FormationTarget
    public var form: String
    public var example: String

    public init(appliesTo: FormationTarget, form: String, example: String) {
        self.appliesTo = appliesTo
        self.form = form
        self.example = example
    }
}

public struct Contrast: Codable, Hashable, Sendable {
    public var patternID: String
    public var note: String

    public init(patternID: String, note: String) {
        self.patternID = patternID
        self.note = note
    }
}

/// A grammar pattern from the curated curriculum.
public struct GrammarPattern: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var pattern: String
    public var meaning: String
    public var level: Level
    /// Curriculum position. Prerequisites always have a lower order.
    public var order: Int
    public var prerequisites: [String]
    public var contrasts: [Contrast]
    public var formation: [FormationRule]
    public var register: String?
    public var commonMistake: String?
    /// Basic patterns the learner already knows. Never shown as a daily item.
    public var assumedKnown: Bool
    /// Verified by a person. Release builds only ship checked entries.
    public var checked: Bool
    public var source: String

    public init(
        id: String, pattern: String, meaning: String, level: Level = .intermediate, order: Int,
        prerequisites: [String] = [], contrasts: [Contrast] = [], formation: [FormationRule] = [],
        register: String? = nil, commonMistake: String? = nil, assumedKnown: Bool = false,
        checked: Bool = true, source: String = ""
    ) {
        self.id = id
        self.pattern = pattern
        self.meaning = meaning
        self.level = level
        self.order = order
        self.prerequisites = prerequisites
        self.contrasts = contrasts
        self.formation = formation
        self.register = register
        self.commonMistake = commonMistake
        self.assumedKnown = assumedKnown
        self.checked = checked
        self.source = source
    }
}

/// Either kind of seed, as chosen by the planner.
public enum Seed: Hashable, Sendable {
    case word(SeedWord)
    case grammar(GrammarPattern)

    public var id: String {
        switch self {
        case .word(let w): w.id
        case .grammar(let g): g.id
        }
    }

    public var kind: ItemKind {
        switch self {
        case .word(let w): w.kind
        case .grammar: .grammar
        }
    }
}

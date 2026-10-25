import Foundation
import OhaneoCore
import SwiftData

/// One word, phrase or grammar pattern you've seen or will see.
///
/// Kept CloudKit-compatible so iCloud sync can be switched on later without a
/// migration: no unique constraints, every property has a default or is optional,
/// and the relationship is optional with an inverse. Enums are stored as raw
/// strings so they work in predicates; structured content is stored as JSON.
@Model
final class StudyItem {
    var id: UUID = UUID()
    /// Stable key into the bundled lists, e.g. "w:73276" or "g:neunde".
    var seedID: String = ""
    var kindRaw: String = ItemKind.word.rawValue
    var korean: String = ""
    var meaning: String = ""
    var definition: String?
    var levelRaw: String = Level.beginner.rawValue
    var examplesData: Data?

    // Vocab only. Meaning, POS and Hanja come from the dictionary; nuance and
    // mnemonic are written by the AI.
    var partOfSpeech: String?
    var hanja: String?
    /// Verbs and adjectives: polite, polite past and formal forms (JSON).
    var formsData: Data?
    var nuance: String?
    var mnemonic: String?

    // Grammar only, copied from grammar.json so history stays stable.
    var grammarData: Data?

    // Progress
    var statusRaw: String = ItemStatus.upcoming.rawValue
    var createdAt: Date = Date()
    /// Start of the local day it was shown.
    var scheduledFor: Date?
    var markedAt: Date?
    /// 0 = not in review, 1–4 = Leitner box.
    var reviewBox: Int = 0
    var nextReviewAt: Date?
    var lastReviewedAt: Date?

    // AI content state
    var generatedAt: Date?
    var generationFailed: Bool = false
    /// Which version of the generator rules wrote the AI content.
    var contentVersion: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.item)
    var chat: [ChatMessage]? = []

    init(seedID: String, kind: ItemKind, korean: String, meaning: String) {
        self.seedID = seedID
        self.kindRaw = kind.rawValue
        self.korean = korean
        self.meaning = meaning
    }

    var kind: ItemKind {
        get { ItemKind(rawValue: kindRaw) ?? .word }
        set { kindRaw = newValue.rawValue }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue }
    }

    var level: Level {
        get { Level(rawValue: levelRaw) ?? .beginner }
        set { levelRaw = newValue.rawValue }
    }

    var examples: [Example] {
        get { examplesData.flatMap { try? JSONDecoder().decode([Example].self, from: $0) } ?? [] }
        set { examplesData = try? JSONEncoder().encode(newValue) }
    }

    var forms: WordForms? {
        get { formsData.flatMap { try? JSONDecoder().decode(WordForms.self, from: $0) } }
        set { formsData = try? newValue.map { try JSONEncoder().encode($0) } }
    }

    var grammar: GrammarDetail? {
        get { grammarData.flatMap { try? JSONDecoder().decode(GrammarDetail.self, from: $0) } }
        set { grammarData = try? newValue.map { try JSONEncoder().encode($0) } }
    }

    var hasGeneratedContent: Bool { generatedAt != nil }

    var historyEntry: HistoryEntry {
        HistoryEntry(seedID: seedID, kind: kind, korean: korean, status: status, markedAt: markedAt, scheduledFor: scheduledFor)
    }
}

/// The curated facts for a grammar card.
struct GrammarDetail: Codable, Hashable {
    struct Comparison: Codable, Hashable {
        var patternID: String
        var pattern: String
        var note: String
    }

    var patternID: String
    var formation: [FormationRule]
    var contrasts: [Comparison]
    var register: String?
    var commonMistake: String?
}

/// A message in an "Ask about this" chat (Phase 3). Declared now so the schema is stable.
@Model
final class ChatMessage {
    var id: UUID = UUID()
    var roleRaw: String = "user"
    var text: String = ""
    var createdAt: Date = Date()
    var item: StudyItem?

    init(role: String, text: String) {
        self.roleRaw = role
        self.text = text
    }
}

extension StudyItem {
    /// A new item filled in from a bundled seed.
    convenience init(seed: Seed, library: SeedLibrary) {
        switch seed {
        case .word(let w):
            self.init(seedID: w.id, kind: w.kind, korean: w.korean, meaning: w.meaning)
            definition = w.definition
            partOfSpeech = w.partOfSpeech
            hanja = w.hanja
            forms = w.forms
            level = w.level
        case .grammar(let g):
            self.init(seedID: g.id, kind: .grammar, korean: g.pattern, meaning: g.meaning)
            level = g.level
            grammar = GrammarDetail(
                patternID: g.id,
                formation: g.formation,
                contrasts: g.contrasts.map { c in
                    GrammarDetail.Comparison(patternID: c.patternID, pattern: library.pattern(id: c.patternID)?.pattern ?? c.patternID, note: c.note)
                },
                register: g.register,
                commonMistake: g.commonMistake
            )
        }
    }

    /// The seed this item came from, rebuilt from the item if the lists changed.
    func seedWord(in library: SeedLibrary) -> SeedWord {
        library.word(id: seedID) ?? SeedWord(
            id: seedID, korean: korean, kind: kind, meaning: meaning, definition: definition,
            partOfSpeech: partOfSpeech, hanja: hanja, level: level, rank: 0, forms: forms
        )
    }

    /// Copies corrected facts from the bundled lists (meanings, forms, Hanja).
    /// Returns true when anything changed.
    @discardableResult
    func syncFacts(from library: SeedLibrary) -> Bool {
        guard kind != .grammar, let w = library.word(id: seedID), w.korean == korean else { return false }
        var changed = false
        func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<StudyItem, T>, _ value: T) {
            if self[keyPath: keyPath] != value {
                self[keyPath: keyPath] = value
                changed = true
            }
        }
        set(\.meaning, w.meaning)
        set(\.definition, w.definition)
        set(\.partOfSpeech, w.partOfSpeech)
        set(\.hanja, w.hanja)
        if forms != w.forms {
            forms = w.forms
            changed = true
        }
        return changed
    }

    func grammarPattern(in library: SeedLibrary) -> GrammarPattern {
        library.pattern(id: seedID) ?? GrammarPattern(
            id: seedID, pattern: korean, meaning: meaning, level: level, order: 0,
            formation: grammar?.formation ?? [], register: grammar?.register, commonMistake: grammar?.commonMistake
        )
    }
}

import Foundation

/// What the planner needs to know about an item already in the store.
public struct HistoryEntry: Sendable, Equatable {
    public var seedID: String
    public var kind: ItemKind
    public var korean: String
    public var status: ItemStatus
    public var markedAt: Date?
    public var scheduledFor: Date?

    public init(seedID: String, kind: ItemKind, korean: String, status: ItemStatus, markedAt: Date? = nil, scheduledFor: Date? = nil) {
        self.seedID = seedID
        self.kind = kind
        self.korean = korean
        self.status = status
        self.markedAt = markedAt
        self.scheduledFor = scheduledFor
    }
}

/// Chooses items using the lists, your history and your preferences.
public struct DailyPlanner: Sendable {
    public static let skipCooldownDays = 30
    public static let maxSkipsPerDay = 3
    public static let prepareDays = 3

    public var library: SeedLibrary
    public var preferences: StudyPreferences
    public var calendar: StudyCalendar

    public init(library: SeedLibrary, preferences: StudyPreferences, calendar: StudyCalendar = StudyCalendar()) {
        self.library = library
        self.preferences = preferences
        self.calendar = calendar
    }

    public var mix: MixScheduler {
        MixScheduler(grammarDaysPerWeek: preferences.grammarDaysPerWeek, phrasePercent: preferences.phrasePercent, calendar: calendar)
    }

    /// Kinds for the days after `today` that should have items prepared.
    public func upcomingKinds(after today: Date, days: Int = prepareDays) -> [ItemKind] {
        (1...max(days, 1)).map { mix.kind(for: calendar.adding(days: $0, to: today)) }
    }

    /// Seeds that can't be picked: anything in the store, except items skipped
    /// more than 30 days ago.
    public func excludedIDs(history: [HistoryEntry], today: Date) -> Set<String> {
        Set(history.compactMap { entry in
            if entry.status == .skipped, let marked = entry.markedAt ?? entry.scheduledFor,
               calendar.daysBetween(marked, today) >= Self.skipCooldownDays {
                return nil
            }
            return entry.seedID
        })
    }

    /// The next seed, trying `kinds` in order.
    public func nextSeed(kinds: [ItemKind], history: [HistoryEntry], reserved: Set<String> = [], today: Date) -> Seed? {
        let excluded = excludedIDs(history: history, today: today).union(reserved)
        let words = WordSelector(library: library)
        let grammar = GrammarSelector(library: library)
        let seenGrammar = Set(history.filter { $0.kind == .grammar && $0.status != .upcoming }.map(\.seedID))
        let placement = preferences.placement

        for kind in kinds {
            switch kind {
            case .word, .phrase:
                if let word = words.next(kind: kind, placement: placement, excluded: excluded, topics: Set(preferences.topics)) {
                    return .word(word)
                }
            case .grammar:
                if let pattern = grammar.next(seen: seenGrammar, known: placement?.knownGrammarIDs ?? [], excluded: excluded) {
                    return .grammar(pattern)
                }
            }
        }
        return nil
    }

    /// Words to reuse in example sentences: recent Learning and Known words, topped
    /// up with words from below your starting point (always available on day one).
    public func exampleVocabulary(history: [HistoryEntry], today: Date, limit: Int = 20) -> [String] {
        let recent = history
            .filter { $0.kind.isVocab && ($0.status == .learning || $0.status == .known) }
            .sorted { ($0.markedAt ?? .distantPast) > ($1.markedAt ?? .distantPast) }
            .map(\.korean)

        var result: [String] = []
        for word in recent where !result.contains(word) && result.count < limit / 2 {
            result.append(word)
        }

        let startRank = preferences.placement?.startRank ?? 1
        let assumed = library.words.filter { $0.rank < startRank }
        if !assumed.isEmpty {
            // Rotate through the assumed-known words day by day.
            // The step shares no factor with the count, so every word is visited once.
            let offset = (calendar.dayNumber(today) * 37) % assumed.count
            let step = [7, 11, 13, 17].first { Self.gcd($0, assumed.count) == 1 } ?? 1
            var i = 0
            while result.count < limit && i < assumed.count {
                let word = assumed[(offset + i * step) % assumed.count].korean
                if !result.contains(word) { result.append(word) }
                i += 1
            }
        }
        for word in recent where !result.contains(word) && result.count < limit {
            result.append(word)
        }
        return result
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }
}

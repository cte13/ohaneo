import Foundation
import OhaneoCore
import Observation
import SwiftData

/// Chooses today's item, prepares the next few days, runs reviews and fills in
/// AI content. All store access happens on the main actor; the AI calls run
/// asynchronously and their results are written back here.
@MainActor
@Observable
final class StudyService {
    let library: SeedLibrary
    let preferences: PreferencesStore
    /// Held so the store outlives any AI task still running.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    private let generator: any ContentGenerator
    private let calendar: StudyCalendar
    private let now: () -> Date

    /// Today's card.
    private(set) var today: StudyItem?
    /// Review prompts for today: answered ones first, then due ones (3 at most).
    private(set) var reviews: [StudyItem] = []
    /// Items whose AI content is being written right now.
    private(set) var generating: Set<UUID> = []

    private var generationTask: Task<Void, Never>?

    init(
        container: ModelContainer,
        library: SeedLibrary,
        preferences: PreferencesStore,
        generator: any ContentGenerator,
        calendar: StudyCalendar = StudyCalendar(),
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.library = library
        self.preferences = preferences
        self.generator = CheckedGenerator(base: generator)
        self.calendar = calendar
        self.now = now
    }

    private var planner: DailyPlanner {
        DailyPlanner(library: library, preferences: preferences.preferences, calendar: calendar)
    }

    private var reviewScheduler: ReviewScheduler { ReviewScheduler(calendar: calendar) }

    var currentDay: Date { calendar.day(now()) }

    // MARK: Daily flow

    /// Call on launch and whenever the app comes to the foreground.
    func refresh() {
        guard preferences.preferences.placement != nil else { return }
        let day = currentDay
        let items = allItems()

        if let current = items
            .filter({ $0.scheduledFor == day && $0.status != .skipped && $0.status != .upcoming })
            .max(by: { $0.createdAt < $1.createdAt }) {
            today = current
        } else {
            today = show(kinds: planner.mix.kinds(for: day), on: day)
        }

        loadReviews()
        preparePool()
        save()
        generateMissingContent()
    }

    var skipsLeftToday: Int {
        let day = currentDay
        let skipped = allItems().filter { $0.scheduledFor == day && $0.status == .skipped }.count
        return max(0, DailyPlanner.maxSkipsPerDay - skipped)
    }

    func mark(_ item: StudyItem, as status: ItemStatus) {
        switch status {
        case .learning:
            let state = reviewScheduler.startLearning(today: now())
            item.status = .learning
            item.reviewBox = state.box
            item.nextReviewAt = state.nextReviewAt
        case .known:
            item.status = .known
            item.reviewBox = 0
            item.nextReviewAt = nil
        default:
            return
        }
        item.markedAt = now()
        save()
    }

    /// Replaces today's card with the next item from the same track.
    func skip() {
        guard let current = today, current.status == .new, skipsLeftToday > 0 else { return }
        current.status = .skipped
        current.markedAt = now()
        let day = currentDay
        let order = [current.kind] + planner.mix.kinds(for: day).filter { $0 != current.kind }
        today = show(kinds: order, on: day)
        preparePool()
        save()
        generateMissingContent()
    }

    func answerReview(_ item: StudyItem, _ answer: ReviewAnswer) {
        let state = reviewScheduler.answer(answer, box: item.reviewBox, today: now())
        item.status = state.status
        item.reviewBox = state.box
        item.nextReviewAt = state.nextReviewAt
        item.lastReviewedAt = now()
        if state.status == .known { item.markedAt = now() }
        save()
    }

    func retryGeneration(for item: StudyItem) {
        item.generationFailed = false
        save()
        generateMissingContent()
    }

    /// Placement finished or settings that affect selection changed: drop
    /// prepared items and pick again.
    func selectionChanged() {
        for item in allItems() where item.status == .upcoming {
            context.delete(item)
        }
        save()
        refresh()
    }

    /// Wipes all study data (debug and "reset" use).
    func eraseAll() {
        try? context.delete(model: StudyItem.self)
        today = nil
        reviews = []
        save()
    }

    // MARK: Notifications

    /// What each of the next days will show, for notification text. Days beyond
    /// the prepared items return nil.
    func upcomingPreview(days: Int = 7) -> [(day: Date, item: StudyItem?)] {
        let day = currentDay
        var pool = Dictionary(grouping: pooledItems(), by: \.kind)
        return (1...days).map { offset in
            let date = calendar.adding(days: offset, to: day)
            let kind = planner.mix.kind(for: date)
            let item = pool[kind]?.first
            if item != nil { pool[kind]?.removeFirst() }
            return (date, item)
        }
    }

    // MARK: Picking items

    private func show(kinds: [ItemKind], on day: Date) -> StudyItem? {
        for kind in kinds {
            if let pooled = pooledItems().first(where: { $0.kind == kind }) {
                pooled.status = .new
                pooled.scheduledFor = day
                return pooled
            }
            if let seed = planner.nextSeed(kinds: [kind], history: allItems().map(\.historyEntry), today: day) {
                let item = item(for: seed)
                item.status = .new
                item.scheduledFor = day
                return item
            }
        }
        return nil
    }

    /// Keeps enough prepared items for the next few days.
    private func preparePool() {
        let day = currentDay
        let needed = Dictionary(grouping: planner.upcomingKinds(after: day), by: { $0 }).mapValues(\.count)
        for (kind, count) in needed.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let have = pooledItems().filter { $0.kind == kind }.count
            guard have < count else { continue }
            for _ in have..<count {
                guard let seed = planner.nextSeed(kinds: [kind], history: allItems().map(\.historyEntry), today: day) else { break }
                item(for: seed).status = .upcoming
            }
        }
    }

    /// Reuses an existing record for the seed (a skip that has come back) or makes one.
    private func item(for seed: Seed) -> StudyItem {
        let id = seed.id
        let existing = try? context.fetch(FetchDescriptor<StudyItem>(predicate: #Predicate { $0.seedID == id })).first
        if let existing {
            existing.markedAt = nil
            existing.createdAt = now()
            return existing
        }
        let item = StudyItem(seed: seed, library: library)
        item.createdAt = now()
        context.insert(item)
        return item
    }

    private func loadReviews() {
        let day = currentDay
        let learning = statusRaw(.learning)
        let candidates = (try? context.fetch(FetchDescriptor<StudyItem>(
            predicate: #Predicate { $0.statusRaw == learning || $0.lastReviewedAt != nil }
        ))) ?? []
        let answeredToday = candidates
            .filter { $0.lastReviewedAt.map { calendar.isSameDay($0, day) } ?? false }
            .sorted { ($0.lastReviewedAt ?? .distantPast) < ($1.lastReviewedAt ?? .distantPast) }

        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id.uuidString, $0) })
        let due = reviewScheduler.dueToday(
            candidates.map { item in
                ReviewCandidate(
                    id: item.id.uuidString,
                    box: item.reviewBox,
                    nextReviewAt: item.status == .learning ? (item.nextReviewAt ?? .distantFuture) : .distantFuture,
                    lastReviewedAt: item.lastReviewedAt
                )
            },
            today: day
        ).compactMap { byID[$0.id] }

        reviews = (answeredToday + due).filter { $0.id != today?.id }
    }

    // MARK: AI content

    private func generateMissingContent() {
        guard generationTask == nil else { return }
        generationTask = Task { [weak self] in
            while let self, let item = self.nextItemNeedingContent() {
                await self.generate(item)
            }
            self?.generationTask = nil
        }
    }

    private func nextItemNeedingContent() -> StudyItem? {
        let needsContent = { (item: StudyItem) in
            item.modelContext != nil && !item.hasGeneratedContent && !item.generationFailed
        }
        if let today, needsContent(today) { return today }
        return pooledItems().first(where: needsContent)
    }

    private func generate(_ item: StudyItem) async {
        generating.insert(item.id)
        defer { generating.remove(item.id) }

        let vocabulary = planner.exampleVocabulary(history: allItems().map(\.historyEntry), today: now())
        do {
            switch item.kind {
            case .word, .phrase:
                let content = try await generator.vocabContent(for: item.seedWord(in: library), vocabulary: vocabulary)
                guard item.modelContext != nil else { return }
                item.examples = content.examples
                item.nuance = content.nuance
                item.mnemonic = content.mnemonic
            case .grammar:
                let examples = try await generator.grammarExamples(for: item.grammarPattern(in: library), vocabulary: vocabulary)
                guard item.modelContext != nil else { return }
                item.examples = examples
            }
            item.generatedAt = now()
            item.generationFailed = false
        } catch {
            guard item.modelContext != nil else { return }
            item.generationFailed = true
        }
        save()
    }

    // MARK: Store helpers

    private func allItems() -> [StudyItem] {
        (try? context.fetch(FetchDescriptor<StudyItem>())) ?? []
    }

    private func pooledItems() -> [StudyItem] {
        let upcoming = statusRaw(.upcoming)
        let descriptor = FetchDescriptor<StudyItem>(
            predicate: #Predicate { $0.statusRaw == upcoming },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func statusRaw(_ status: ItemStatus) -> String { status.rawValue }

    private func save() {
        try? context.save()
    }
}

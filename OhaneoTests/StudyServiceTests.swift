import Foundation
import OhaneoCore
import SwiftData
import Testing
@testable import Ohaneo

/// Runs the daily flow against an in-memory store with fixed content and a
/// movable clock.
@MainActor
@Suite struct StudyServiceTests {
    final class Clock {
        var date: Date
        init(_ date: Date) { self.date = date }
        func advance(days: Int) { date = Calendar.current.date(byAdding: .day, value: days, to: date)! }
    }

    let container: ModelContainer
    let preferences: PreferencesStore
    let clock: Clock
    let service: StudyService

    init() throws {
        let schema = Schema([StudyItem.self, ChatMessage.self])
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        preferences = PreferencesStore(defaults: defaults)
        preferences.preferences.placement = PlacementResult(startRank: 100)
        // A Sunday, so tomorrow is a vocab day and Tuesday a grammar day.
        clock = Clock(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 9))!)
        let clock = clock
        service = StudyService(
            container: container,
            library: try SeedLibrary.bundled(),
            preferences: preferences,
            generator: FakeContentGenerator(),
            now: { clock.date }
        )
    }

    private func allItems() throws -> [StudyItem] {
        try container.mainContext.fetch(FetchDescriptor<StudyItem>())
    }

    @Test func refreshPicksTodayAndPreparesThreeDays() throws {
        service.refresh()
        let today = try #require(service.today)
        #expect(today.status == .new)
        #expect(today.kind != .grammar)
        let upcoming = try allItems().filter { $0.status == .upcoming }
        #expect(upcoming.count == 3)
        #expect(upcoming.filter { $0.kind == .grammar }.count == 1)
    }

    @Test func refreshIsStableWithinADay() throws {
        service.refresh()
        let first = service.today?.id
        service.refresh()
        #expect(service.today?.id == first)
        #expect(try allItems().count == 4)
    }

    @Test func nextDayUsesAPreparedItem() throws {
        service.refresh()
        let prepared = try allItems().filter { $0.status == .upcoming }.map(\.id)
        clock.advance(days: 1)
        service.refresh()
        let today = try #require(service.today)
        #expect(prepared.contains(today.id))
    }

    @Test func missedDaysDontPileUp() throws {
        service.refresh()
        clock.advance(days: 5)
        service.refresh()
        let shown = try allItems().filter { $0.status != .upcoming }
        #expect(shown.count == 2)
    }

    @Test func skipShowsAnotherItemOfTheSameKindUpToThreeTimes() throws {
        service.refresh()
        let kind = try #require(service.today).kind
        for left in [2, 1, 0] {
            let before = service.today?.id
            service.skip()
            #expect(service.today?.id != before)
            #expect(service.today?.kind == kind)
            #expect(service.skipsLeftToday == left)
        }
        let last = service.today?.id
        service.skip()
        #expect(service.today?.id == last)
    }

    @Test func learningItemComesBackForReviewTomorrow() throws {
        service.refresh()
        let item = try #require(service.today)
        service.mark(item, as: .learning)
        #expect(service.reviews.isEmpty)

        clock.advance(days: 1)
        service.refresh()
        #expect(service.reviews.map(\.id) == [item.id])

        service.answerReview(item, .gotIt)
        #expect(item.reviewBox == 2)
        service.refresh()
        // Answered reviews stay listed for the rest of the day.
        #expect(service.reviews.map(\.id) == [item.id])

        clock.advance(days: 1)
        service.refresh()
        #expect(service.reviews.isEmpty)
    }

    @Test func reviewsAreCappedAtThree() throws {
        for _ in 0..<5 {
            service.refresh()
            service.mark(try #require(service.today), as: .learning)
            clock.advance(days: 1)
        }
        service.refresh()
        #expect(service.reviews.count == 3)
    }

    @Test func contentIsGeneratedForToday() async throws {
        service.refresh()
        let item = try #require(service.today)
        for _ in 0..<50 where !item.hasGeneratedContent {
            try await Task.sleep(for: .milliseconds(20))
        }
        let examples = item.examples
        #expect(item.hasGeneratedContent)
        #expect(examples.count > 0)
        #expect(examples.allSatisfy { $0.hasValidHighlight })
    }

    @Test func savedCardsPickUpCorrectedFactsAndNewContent() async throws {
        let library = try SeedLibrary.bundled()
        let word = try #require(library.words.first { $0.korean == "어떻다" })
        // A card saved by an older build: old gloss, no forms, old AI content.
        let old = StudyItem(seed: .word(word), library: library)
        old.meaning = "such"
        old.forms = nil
        old.status = .new
        old.scheduledFor = Calendar.current.startOfDay(for: clock.date)
        old.examples = [Example(korean: "영화가 너무 어떻다!", english: "", highlight: "어떻다")]
        old.generatedAt = clock.date
        container.mainContext.insert(old)

        service.refresh()
        #expect(service.today?.id == old.id)
        #expect(old.meaning == word.meaning)
        #expect(old.forms?.polite == "어때요")

        for _ in 0..<50 where old.contentVersion < StudyService.contentVersion {
            try await Task.sleep(for: .milliseconds(20))
        }
        let examples = old.examples
        #expect(old.contentVersion == StudyService.contentVersion)
        #expect(examples.allSatisfy { $0.isValid(for: word) })
    }

    @Test func selectionChangeDropsPreparedItems() throws {
        service.refresh()
        let prepared = Set(try allItems().filter { $0.status == .upcoming }.map(\.id))
        preferences.preferences.placement = PlacementResult(startRank: 2000)
        service.selectionChanged()
        let now = Set(try allItems().filter { $0.status == .upcoming }.map(\.id))
        #expect(prepared.isDisjoint(with: now))
        #expect(now.count == 3)
    }

    @Test func upcomingPreviewNamesPreparedItems() throws {
        service.refresh()
        let preview = service.upcomingPreview()
        #expect(preview.count == 7)
        #expect(preview.prefix(3).allSatisfy { $0.item != nil })
        #expect(preview[1].item?.kind == .grammar)
    }
}

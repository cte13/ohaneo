import Foundation

public enum ReviewAnswer: Sendable {
    case gotIt, notYet
}

/// Review progress for one item.
public struct ReviewState: Equatable, Sendable {
    public var status: ItemStatus
    /// 0 = not in review, 1–4 = Leitner box.
    public var box: Int
    public var nextReviewAt: Date?

    public init(status: ItemStatus, box: Int, nextReviewAt: Date?) {
        self.status = status
        self.box = box
        self.nextReviewAt = nextReviewAt
    }
}

/// An item that might be due for review.
public struct ReviewCandidate: Sendable, Equatable {
    public var id: String
    public var box: Int
    public var nextReviewAt: Date
    public var lastReviewedAt: Date?

    public init(id: String, box: Int, nextReviewAt: Date, lastReviewedAt: Date? = nil) {
        self.id = id
        self.box = box
        self.nextReviewAt = nextReviewAt
        self.lastReviewedAt = lastReviewedAt
    }
}

/// Light Leitner review: 1 → 3 → 7 → 21 days, then known.
public struct ReviewScheduler: Sendable {
    /// Days until the next review for an item sitting in each box.
    public static let intervals: [Int: Int] = [1: 1, 2: 3, 3: 7, 4: 21]
    public static let maxBox = 4
    public static let dailyCap = 3

    public var calendar: StudyCalendar

    public init(calendar: StudyCalendar = StudyCalendar()) {
        self.calendar = calendar
    }

    /// Marking an item Learning puts it in box 1, due tomorrow.
    public func startLearning(today: Date) -> ReviewState {
        ReviewState(status: .learning, box: 1, nextReviewAt: due(box: 1, from: today))
    }

    public func answer(_ answer: ReviewAnswer, box: Int, today: Date) -> ReviewState {
        let box = min(max(box, 1), Self.maxBox)
        switch answer {
        case .gotIt:
            if box == Self.maxBox {
                return ReviewState(status: .known, box: 0, nextReviewAt: nil)
            }
            return ReviewState(status: .learning, box: box + 1, nextReviewAt: due(box: box + 1, from: today))
        case .notYet:
            return ReviewState(status: .learning, box: max(1, box - 1), nextReviewAt: calendar.adding(days: 1, to: today))
        }
    }

    /// Items to show today: due ones, most overdue first, up to the daily cap minus
    /// reviews already answered today.
    public func dueToday(_ candidates: [ReviewCandidate], today: Date) -> [ReviewCandidate] {
        let start = calendar.day(today)
        let answeredToday = candidates.filter { c in
            c.lastReviewedAt.map { calendar.isSameDay($0, today) } ?? false
        }.count
        let remaining = max(0, Self.dailyCap - answeredToday)
        return candidates
            .filter { $0.nextReviewAt <= start }
            .sorted { a, b in
                if a.nextReviewAt != b.nextReviewAt { return a.nextReviewAt < b.nextReviewAt }
                if a.box != b.box { return a.box < b.box }
                return a.id < b.id
            }
            .prefix(remaining)
            .map { $0 }
    }

    private func due(box: Int, from today: Date) -> Date {
        calendar.adding(days: Self.intervals[box] ?? 1, to: today)
    }
}

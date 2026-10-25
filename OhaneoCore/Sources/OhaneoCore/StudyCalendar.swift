import Foundation

/// Local calendar days. A study day starts at local midnight.
public struct StudyCalendar: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Start of the local day containing `date`.
    public func day(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: day(date)) ?? day(date)
    }

    public func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    /// Whole days from `a` to `b`, counted in calendar days (safe across DST changes).
    public func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: day(a), to: day(b)).day ?? 0
    }

    /// A stable number for each day, counted from 1 Jan 2001.
    public func dayNumber(_ date: Date) -> Int {
        let reference = calendar.date(from: DateComponents(year: 2001, month: 1, day: 1)) ?? Date(timeIntervalSinceReferenceDate: 0)
        return daysBetween(reference, date)
    }

    /// Monday = 0 … Sunday = 6.
    public func weekdayIndex(_ date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        return (weekday + 5) % 7
    }
}

import Foundation

/// Settings that shape what you see. Stored as JSON in the App Group defaults.
public struct StudyPreferences: Codable, Equatable, Sendable {
    public var grammarDaysPerWeek: Int = 2
    public var phrasePercent: Int = 30
    public var topics: [String] = []
    public var notificationsEnabled: Bool = true
    public var notificationHour: Int = 8
    public var notificationMinute: Int = 0
    /// Nil until placement is done.
    public var placement: PlacementResult?

    public init() {}

    /// The parts that change which items get picked. Prepared items are thrown
    /// away when these change.
    public var selectionKey: SelectionKey {
        SelectionKey(grammarDaysPerWeek: grammarDaysPerWeek, phrasePercent: phrasePercent, topics: topics, placement: placement)
    }

    public struct SelectionKey: Equatable, Sendable {
        var grammarDaysPerWeek: Int
        var phrasePercent: Int
        var topics: [String]
        var placement: PlacementResult?
    }
}

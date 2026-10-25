import Foundation
import OhaneoCore
import Observation

enum AppGroup {
    static let identifier = "group.dev.ohaneo.app"
    static var defaults: UserDefaults { UserDefaults(suiteName: identifier) ?? .standard }
}

/// Study preferences, saved as JSON in the App Group defaults so widgets can read them later.
@MainActor
@Observable
final class PreferencesStore {
    private static let key = "studyPreferences"
    private let defaults: UserDefaults

    var preferences: StudyPreferences {
        didSet { save() }
    }

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(StudyPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = StudyPreferences()
        }
    }

    func reset() {
        defaults.removeObject(forKey: Self.key)
        preferences = StudyPreferences()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: Self.key)
        }
    }
}

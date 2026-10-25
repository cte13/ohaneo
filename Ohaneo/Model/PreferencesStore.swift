import Foundation
import OhaneoCore
import Observation

/// The App Group shared with widgets (Phase 2). Builds without the App Group
/// entitlement fall back to the app's own storage.
enum AppGroup {
    static let identifier = "group.dev.ohaneo.app"

    /// A writable folder in the App Group container, or nil when the build
    /// doesn't have the App Group (unsigned simulator builds, or before the
    /// capability is turned on).
    static let writableDirectory: URL? = {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) else { return nil }
        let directory = root.appending(path: "Library/Application Support", directoryHint: .isDirectory)
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil,
              FileManager.default.isWritableFile(atPath: directory.path(percentEncoded: false)) else { return nil }
        return directory
    }()

    static var defaults: UserDefaults {
        guard writableDirectory != nil, let shared = UserDefaults(suiteName: identifier) else { return .standard }
        return shared
    }
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
        // Carry preferences over the first time the App Group is available.
        if defaults !== UserDefaults.standard, defaults.data(forKey: Self.key) == nil,
           let local = UserDefaults.standard.data(forKey: Self.key) {
            defaults.set(local, forKey: Self.key)
        }
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

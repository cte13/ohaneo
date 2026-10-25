import OhaneoCore
import SwiftData
import SwiftUI

@main
struct OhaneoApp: App {
    @State private var environment = AppEnvironment.make()

    var body: some Scene {
        WindowGroup {
            RootView(aiUnavailableReason: environment.aiUnavailableReason)
                .environment(environment.service)
                .environment(environment.preferences)
                .modelContainer(environment.container)
                .tint(Theme.grid)
        }
    }
}

/// Builds the store, lists, AI provider and service once at launch.
///
/// Debug launch arguments:
/// - `-fakeAI`: fixed content instead of Apple Intelligence (simulators, UI work)
/// - `-resetData`: erase study data and preferences
/// - `-demoPlacement`: skip placement with a typical upper-beginner result
/// - `-today YYYY-MM-DD`: pretend it's another day
@MainActor
final class AppEnvironment {
    let container: ModelContainer
    let preferences: PreferencesStore
    let service: StudyService
    let aiUnavailableReason: String?

    private init(container: ModelContainer, preferences: PreferencesStore, service: StudyService, aiUnavailableReason: String?) {
        self.container = container
        self.preferences = preferences
        self.service = service
        self.aiUnavailableReason = aiUnavailableReason
    }

    static func make() -> AppEnvironment {
        let arguments = ProcessInfo.processInfo.arguments
        let container = makeContainer()
        let preferences = PreferencesStore()

        var library: SeedLibrary
        do {
            library = try SeedLibrary.bundled()
        } catch {
            fatalError("Bundled word lists are missing: \(error)")
        }
        #if !DEBUG
        // Only grammar a person has verified ships in release builds.
        library = library.checkedOnly()
        #endif

        let useFake = isDebug && arguments.contains("-fakeAI")
        let generator: any ContentGenerator = useFake ? FakeContentGenerator(delay: .milliseconds(800)) : FoundationModelsGenerator()
        let reason = useFake ? nil : FoundationModelsGenerator.unavailableReason

        var now: () -> Date = { Date() }
        if isDebug, let index = arguments.firstIndex(of: "-today"), arguments.indices.contains(index + 1),
           let fixed = try? Date(arguments[index + 1], strategy: Date.ISO8601FormatStyle().year().month().day()) {
            let offset = Calendar.current.startOfDay(for: fixed).timeIntervalSince(Calendar.current.startOfDay(for: Date()))
            now = { Date().addingTimeInterval(offset) }
        }

        let service = StudyService(
            container: container,
            library: library,
            preferences: preferences,
            generator: generator,
            now: now
        )

        if isDebug && arguments.contains("-resetData") {
            service.eraseAll()
            preferences.reset()
        }
        if isDebug && arguments.contains("-demoPlacement") && preferences.preferences.placement == nil {
            let plan = Placement.plan(library: library)
            let known = Set(plan.bands.prefix(2).flatMap { $0 }.map(\.id))
            preferences.preferences.placement = Placement.result(plan: plan, knownWordIDs: known, knownGrammarIDs: [], library: library)
        }
        return AppEnvironment(container: container, preferences: preferences, service: service, aiUnavailableReason: reason)
    }

    private static var isDebug: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// The store lives in the App Group container so widgets can read it later.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([StudyItem.self, ChatMessage.self])
        // Builds without a signing team (e.g. simulator) can't write to the App
        // Group, so fall back to the app's own container when it isn't writable.
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            let directory = groupURL.appending(path: "Library/Application Support", directoryHint: .isDirectory)
            if (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil,
               FileManager.default.isWritableFile(atPath: directory.path(percentEncoded: false)) {
                let shared = ModelConfiguration(schema: schema, url: directory.appending(path: "Study.store"), cloudKitDatabase: .none)
                if let container = try? ModelContainer(for: schema, configurations: shared) {
                    return container
                }
            }
        }
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none))
        } catch {
            fatalError("Couldn't open the study store: \(error)")
        }
    }
}

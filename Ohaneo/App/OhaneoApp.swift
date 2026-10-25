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

    /// The store lives in the App Group container when the build has one (so
    /// widgets can read it later), otherwise in the app's own container. The
    /// first launch with the App Group copies an existing local store into it.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([StudyItem.self, ChatMessage.self])
        let fileManager = FileManager.default
        let localDirectory = URL.applicationSupportDirectory
        try? fileManager.createDirectory(at: localDirectory, withIntermediateDirectories: true)
        let localStore = localDirectory.appending(path: "Study.store")

        if let groupDirectory = AppGroup.writableDirectory {
            let groupStore = groupDirectory.appending(path: "Study.store")
            if !fileManager.fileExists(atPath: groupStore.path(percentEncoded: false)),
               fileManager.fileExists(atPath: localStore.path(percentEncoded: false)) {
                for suffix in ["", "-shm", "-wal"] {
                    let from = URL(filePath: localStore.path(percentEncoded: false) + suffix)
                    let to = URL(filePath: groupStore.path(percentEncoded: false) + suffix)
                    if fileManager.fileExists(atPath: from.path(percentEncoded: false)) {
                        try? fileManager.copyItem(at: from, to: to)
                    }
                }
            }
            let shared = ModelConfiguration(schema: schema, url: groupStore, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: shared) {
                return container
            }
        }
        do {
            let local = ModelConfiguration(schema: schema, url: localStore, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Couldn't open the study store: \(error)")
        }
    }
}

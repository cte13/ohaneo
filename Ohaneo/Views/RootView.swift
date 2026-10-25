import OhaneoCore
import SwiftUI

struct RootView: View {
    let aiUnavailableReason: String?

    @Environment(StudyService.self) private var service
    @Environment(PreferencesStore.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = RootView.initialTab

    var body: some View {
        Group {
            if let reason = aiUnavailableReason {
                UnavailableView(reason: reason)
            } else if preferences.preferences.placement == nil {
                PlacementView(library: service.library) { result in
                    preferences.preferences.placement = result
                    service.selectionChanged()
                    Task {
                        _ = await NotificationScheduler.requestAuthorization()
                        await rescheduleNotifications()
                    }
                }
            } else {
                tabs
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, aiUnavailableReason == nil else { return }
            service.refresh()
            Task { await rescheduleNotifications() }
        }
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "square.grid.3x1.below.line.grid.1x2", value: "today") {
                TodayView()
            }
            Tab("Class", systemImage: "book.closed", value: "class") {
                ClassView(course: ClassView.bundledCourse)
            }
            Tab("History", systemImage: "clock", value: "history") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gearshape", value: "settings") {
                SettingsView()
            }
        }
    }

    /// Debug launch argument `-tab class|history|settings` opens that tab, for screenshots.
    private static var initialTab: String {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), args.indices.contains(i + 1) { return args[i + 1] }
        #endif
        return "today"
    }

    private func rescheduleNotifications() async {
        await NotificationScheduler.reschedule(preferences: preferences.preferences, preview: service.upcomingPreview())
    }
}

/// Shown when Apple Intelligence isn't available. The MVP assumes it is.
struct UnavailableView: View {
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                ManuscriptGrid(text: "오한어", cellSize: 64, minimumCellSize: 48)
                Text("오늘의 한국어")
                    .font(.batang(17, relativeTo: .headline))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityElement(children: .combine)
            Text("Apple Intelligence is required")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(reason)
                .foregroundStyle(Theme.ink)
            Text("This app writes example sentences and notes on your device with Apple Intelligence, so it needs it turned on.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, Theme.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperBackground()
    }
}

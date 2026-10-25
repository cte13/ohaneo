import OhaneoCore
import SwiftUI

struct SettingsView: View {
    @Environment(StudyService.self) private var service
    @Environment(PreferencesStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var redoingPlacement = false
    @State private var notificationsAllowed = true
    @State private var confirmingReset = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section {
                    Toggle("Daily reminder", isOn: $store.preferences.notificationsEnabled)
                    if store.preferences.notificationsEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    if store.preferences.notificationsEnabled && !notificationsAllowed {
                        Button("Notifications are off for this app. Turn them on in iOS Settings.") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                        .font(.footnote)
                    } else {
                        Text("One notification a day, naming that day's item.")
                    }
                }

                Section {
                    if let placement = store.preferences.placement {
                        LabeledContent("New words start at", value: "#\(placement.startRank.formatted())")
                    }
                    Button("Redo placement") { redoingPlacement = true }
                } header: {
                    Text("Starting point")
                } footer: {
                    Text("Your history and review progress are kept.")
                }

                Section("About") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Word list and levels: 국립국어원 「한국어 학습용 어휘 목록」 (KOGL Type 1).")
                        Text("Meanings, definitions and Hanja: 국립국어원 「한국어기초사전」, CC BY-SA 2.0 KR.")
                        Text("Korean typeface: Gowun Batang, SIL Open Font License 1.1.")
                        Text("Example sentences and notes are written on your device by Apple Intelligence and can contain mistakes.")
                    }
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .padding(.vertical, 4)
                }

                #if DEBUG
                Section("Debug") {
                    Button("Erase all study data", role: .destructive) { confirmingReset = true }
                }
                #endif
            }
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle("Settings")
            .onChange(of: store.preferences.notificationsEnabled) { _, enabled in
                Task {
                    if enabled { _ = await NotificationScheduler.requestAuthorization() }
                    await reschedule()
                }
            }
            .onChange(of: store.preferences.notificationHour) { Task { await reschedule() } }
            .onChange(of: store.preferences.notificationMinute) { Task { await reschedule() } }
            .task { notificationsAllowed = await NotificationScheduler.isAuthorized() }
            .fullScreenCover(isPresented: $redoingPlacement) {
                PlacementView(library: service.library, onCancel: { redoingPlacement = false }) { result in
                    store.preferences.placement = result
                    redoingPlacement = false
                    service.selectionChanged()
                }
            }
            .confirmationDialog("Erase all study data?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Erase", role: .destructive) {
                    service.eraseAll()
                    store.reset()
                }
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: store.preferences.notificationHour, minute: store.preferences.notificationMinute)) ?? Date()
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            store.preferences.notificationHour = parts.hour ?? 8
            store.preferences.notificationMinute = parts.minute ?? 0
        }
    }

    private func reschedule() async {
        notificationsAllowed = await NotificationScheduler.isAuthorized()
        await NotificationScheduler.reschedule(preferences: store.preferences, preview: service.upcomingPreview())
    }
}

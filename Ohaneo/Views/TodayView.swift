import OhaneoCore
import SwiftUI

struct TodayView: View {
    @Environment(StudyService.self) private var service
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let known = service.replacedKnown, service.today?.status == .new {
                    replacedNote(known)
                }
                if let item = service.today {
                    card(for: item)
                } else {
                    finished
                }
                if !service.reviews.isEmpty {
                    GridRule()
                    ReviewSection(items: service.reviews)
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .paperBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(service.currentDay, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Text(title)
                .font(.batang(30, bold: true, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private var title: String {
        switch service.today?.kind {
        case .grammar: "오늘의 문법"
        case .phrase: "오늘의 표현"
        default: "오늘의 단어"
        }
    }

    @ViewBuilder private func card(for item: StudyItem) -> some View {
        let revealed = revealedID == item.id || item.status != .new || Self.revealForScreenshots
        VStack(alignment: .leading, spacing: 22) {
            CardFront(item: item)
            if revealed {
                CardDetails(item: item)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 12)))
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.35)) { revealedID = item.id }
                } label: {
                    Text(item.kind == .grammar ? "Show how it works" : "Show meaning")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            ResponseBar(item: item)
        }
        .id(item.id)
    }

    private func replacedNote(_ known: StudyItem) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(Text(known.korean).font(.batang(15, bold: true, relativeTo: .subheadline))) marked as known. Here's the next one.")
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Button("Undo") {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { service.undoKnown() }
            }
        }
        .font(.subheadline)
    }

    /// Debug launch argument `-reveal` opens today's card, for screenshots.
    private static var revealForScreenshots: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-reveal")
        #else
        false
        #endif
    }

    private var finished: some View {
        Text("You've seen every item in the lists. New ones arrive with app updates.")
            .foregroundStyle(Theme.inkSecondary)
    }
}

/// I know this · Learning · Skip, then a note on what happens next.
private struct ResponseBar: View {
    let item: StudyItem
    @Environment(StudyService.self) private var service

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if item.status == .new {
                HStack(spacing: 10) {
                    Button { service.mark(item, as: .known) } label: {
                        Text("I know this").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    Button { service.mark(item, as: .learning) } label: {
                        Text("Learning").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
                .controlSize(.large)
                if service.skipsLeftToday > 0 {
                    Button("Skip for now") { service.skip() }
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(statusNote)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Menu("Change") {
                        if item.status != .learning {
                            Button("Learning") { service.mark(item, as: .learning) }
                        }
                        if item.status != .known {
                            Button("I know this") { service.mark(item, as: .known) }
                        }
                    }
                    .font(.subheadline)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .overlay(Rectangle().stroke(Theme.gridFaint, lineWidth: 1))
            }
        }
    }

    private var statusNote: String {
        switch item.status {
        case .learning: "Added to review. First check tomorrow."
        case .known: "Marked as known. It won't come back."
        default: ""
        }
    }
}

import OhaneoCore
import SwiftUI

/// Up to three quick recall checks under today's card.
struct ReviewSection: View {
    let items: [StudyItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("복습")
                    .font(.batang(24, bold: true, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                    .accessibilityLabel("Review")
                    .accessibilityAddTraits(.isHeader)
                Text("Quick checks on things you're learning")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            ForEach(items) { item in
                ReviewPrompt(item: item)
                if item.id != items.last?.id { GridRule() }
            }
        }
    }
}

private struct ReviewPrompt: View {
    let item: StudyItem
    @Environment(StudyService.self) private var service
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    private var answeredToday: Bool {
        item.lastReviewedAt.map { Calendar.current.isDate($0, inSameDayAs: service.currentDay) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                ManuscriptGrid(text: item.korean, cellSize: 40, minimumCellSize: 30)
                Spacer(minLength: 8)
                if item.kind != .grammar && !answeredToday {
                    ListenButton(text: item.korean, size: .small)
                }
            }
            if answeredToday {
                Label(result, systemImage: item.status == .known ? "checkmark.seal" : "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(Theme.grid)
            } else if revealed {
                Text(item.meaning)
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { answer(.notYet) } label: { Text("Not yet").frame(maxWidth: .infinity) }
                        .buttonStyle(.glass)
                    Button { answer(.gotIt) } label: { Text("Got it").frame(maxWidth: .infinity) }
                        .buttonStyle(.glassProminent)
                }
            } else {
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) { revealed = true }
                } label: {
                    Text(item.kind == .grammar ? "Remember what it does? Check" : "Remember the meaning? Check")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func answer(_ answer: ReviewAnswer) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            service.answerReview(item, answer)
        }
    }

    private var result: String {
        if item.status == .known { return "Got it. Moved to known." }
        guard let next = item.nextReviewAt else { return "Done" }
        let days = Calendar.current.dateComponents([.day], from: service.currentDay, to: next).day ?? 1
        return days <= 1 ? "Back tomorrow." : "Next check in \(days) days."
    }
}

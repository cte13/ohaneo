import OhaneoCore
import SwiftUI

/// Flashcards for a lesson's words. Tap to flip; "Again" sends the card to the
/// back of the deck, so the round ends when every card has been "Got it" once.
struct DrillView: View {
    let title: String
    let words: [DrillWord]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: DrillSession
    @State private var flipped = false
    @State private var englishFirst = false

    init(title: String, words: [DrillWord]) {
        self.title = title
        self.words = words
        _session = State(initialValue: DrillSession(words: words.shuffled()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProgressView(value: Double(session.done.count), total: Double(max(session.total, 1)))
                    .tint(Theme.grid)
                if let word = session.current {
                    card(word)
                    Spacer(minLength: 0)
                    if flipped {
                        HStack(spacing: 12) {
                            Button { next(gotIt: false) } label: { Text("Again").frame(maxWidth: .infinity) }
                                .buttonStyle(.glass)
                            Button { next(gotIt: true) } label: { Text("Got it").frame(maxWidth: .infinity) }
                                .buttonStyle(.glassProminent)
                        }
                        .controlSize(.large)
                    } else {
                        Button { flip() } label: { Text("Show").frame(maxWidth: .infinity) }
                            .buttonStyle(.glass)
                            .controlSize(.large)
                    }
                } else {
                    finished
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 16)
            .paperBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu("Options", systemImage: "ellipsis") {
                        Toggle("Show English first", isOn: $englishFirst)
                        Button("Start over", systemImage: "arrow.counterclockwise") { restart(words) }
                    }
                }
            }
        }
    }

    private func card(_ word: DrillWord) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if englishFirst {
                english(word)
                if flipped { korean(word) }
            } else {
                korean(word)
                if flipped { english(word) }
            }
            if flipped, let example = word.example {
                GridRule()
                VStack(alignment: .leading, spacing: 4) {
                    Text(example)
                        .font(.koreanBody)
                        .foregroundStyle(Theme.ink)
                    if let exampleEnglish = word.exampleEnglish {
                        Text(exampleEnglish).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .topLeading)
        .background(Theme.paperRaised)
        .overlay(Rectangle().stroke(Theme.grid, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { if !flipped { flip() } }
        .accessibilityAddTraits(.isButton)
    }

    private func korean(_ word: DrillWord) -> some View {
        HStack(alignment: .center) {
            Text(word.korean)
                .font(.batang(34, bold: true, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            ListenButton(text: word.korean)
        }
    }

    private func english(_ word: DrillWord) -> some View {
        Text(word.english ?? "—")
            .font(.title2.weight(.semibold))
            .foregroundStyle(englishFirst ? Theme.ink : Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var finished: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Done: \(session.total) words")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.ink)
            if session.missed.isEmpty {
                Text("You knew every word the first time.").foregroundStyle(Theme.inkSecondary)
            } else {
                Text("\(session.missed.count) needed another look:")
                    .foregroundStyle(Theme.inkSecondary)
                Text(missedInOrder.map(\.korean).joined(separator: " · "))
                    .font(.batang(19, bold: true, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
            }
            Spacer()
            if !session.missed.isEmpty {
                Button { restart(missedInOrder) } label: {
                    Text("Drill those again").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
            }
            Button { restart(words) } label: { Text("Start over").frame(maxWidth: .infinity) }
                .buttonStyle(.glass)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missedInOrder: [DrillWord] {
        words.filter(session.missed.contains)
    }

    private func flip() {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { flipped = true }
    }

    private func next(gotIt: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
            if gotIt { session.gotIt() } else { session.again() }
            flipped = false
        }
    }

    private func restart(_ deck: [DrillWord]) {
        session = DrillSession(words: deck.shuffled())
        flipped = false
    }
}

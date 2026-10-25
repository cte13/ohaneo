import OhaneoCore
import SwiftUI

/// A two-minute "know / not yet" swipe through 30 words and 10 grammar patterns.
struct PlacementView: View {
    let library: SeedLibrary
    var onCancel: (() -> Void)?
    let onFinish: (PlacementResult) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Stage = .intro
    @State private var answers: [Bool] = []
    @State private var drag: CGFloat = 0

    private enum Stage { case intro, questions, done }

    private struct Question {
        let id: String
        let korean: String
        let isGrammar: Bool
    }

    private let plan: PlacementPlan
    private let questions: [Question]

    init(library: SeedLibrary, onCancel: (() -> Void)? = nil, onFinish: @escaping (PlacementResult) -> Void) {
        self.library = library
        self.onCancel = onCancel
        self.onFinish = onFinish
        let plan = Placement.plan(library: library)
        self.plan = plan
        self.questions = plan.words.map { Question(id: $0.id, korean: $0.korean, isGrammar: false) }
            + plan.grammar.map { Question(id: $0.id, korean: $0.pattern, isGrammar: true) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch stage {
            case .intro: intro
            case .questions: questionScreen
            case .done: summary
            }
        }
        .padding(.horizontal, Theme.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .paperBackground()
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let onCancel {
                Button("Cancel", action: onCancel).padding(.top, 8)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                ManuscriptGrid(text: "오한어", cellSize: 64, minimumCellSize: 48)
                Text("오늘의 한국어")
                    .font(.batang(17, relativeTo: .headline))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityElement(children: .combine)
            Text("Let's find your starting point")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("You'll see 30 words and 10 grammar patterns. Answer “I know it” if you'd understand it in a sentence. It takes about two minutes.")
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Swipe right for “I know it”, left for “Not yet”, or use the buttons.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Button {
                withAnimation(reduceMotion ? nil : .smooth) { stage = .questions }
            } label: {
                Text("Start").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .padding(.bottom, 12)
        }
    }

    // MARK: Questions

    @ViewBuilder private var questionScreen: some View {
        let index = answers.count
        if questions.indices.contains(index) {
            let question = questions[index]
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Button("Back") { goBack() }
                        .disabled(answers.isEmpty)
                    Spacer()
                    Text("\(index + 1) of \(questions.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.inkSecondary)
                }
                .padding(.top, 8)
                ProgressSquares(total: questions.count, answered: index)
                Spacer()
                Text(question.isGrammar ? "Do you know this grammar pattern?" : "Do you know this word?")
                    .font(.headline)
                    .foregroundStyle(Theme.inkSecondary)
                ManuscriptGrid(text: question.korean, cellSize: 72, minimumCellSize: 44)
                    .offset(x: drag)
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag / 40)))
                    .gesture(swipe)
                    .id(question.id)
                    .transition(.opacity)
                Spacer()
                HStack(spacing: 10) {
                    Button { answer(false) } label: { Text("Not yet").frame(maxWidth: .infinity) }
                        .buttonStyle(.glass)
                    Button { answer(true) } label: { Text("I know it").frame(maxWidth: .infinity) }
                        .buttonStyle(.glassProminent)
                }
                .controlSize(.large)
                .padding(.bottom, 12)
            }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { drag = $0.translation.width }
            .onEnded { value in
                let width = value.translation.width
                if abs(width) > 90 {
                    answer(width > 0)
                } else {
                    withAnimation(.snappy) { drag = 0 }
                }
            }
    }

    private func answer(_ known: Bool) {
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            drag = 0
            answers.append(known)
            if answers.count == questions.count { stage = .done }
        }
    }

    private func goBack() {
        guard !answers.isEmpty else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { _ = answers.popLast() }
    }

    // MARK: Summary

    private var result: PlacementResult {
        let known = Set(zip(questions, answers).filter { $0.1 }.map { $0.0.id })
        return Placement.result(
            plan: plan,
            knownWordIDs: known.filter { !$0.hasPrefix("g:") },
            knownGrammarIDs: known.filter { $0.hasPrefix("g:") },
            library: library
        )
    }

    private var summary: some View {
        let result = result
        let firstWord = WordSelector(library: library).next(kind: .word, placement: result, excluded: [])
        let firstGrammar = GrammarSelector(library: library).next(seen: [], known: result.knownGrammarIDs, excluded: [])
        return VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text("Your starting point")
                .font(.title.weight(.semibold))
                .foregroundStyle(Theme.ink)
            VStack(alignment: .leading, spacing: 14) {
                if let firstWord {
                    summaryLine("New words start around #\(result.startRank.formatted()) of \(library.words.count.formatted()), with words like", firstWord.korean)
                }
                if let firstGrammar {
                    summaryLine("Grammar starts with", firstGrammar.pattern)
                }
                if !result.priorityWordIDs.isEmpty {
                    Text("The \(result.priorityWordIDs.count) easier words you didn't know come first.")
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Text("You can redo this any time in Settings.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Button { onFinish(result) } label: {
                Text("Begin").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            Button("Go back and change answers") {
                withAnimation(reduceMotion ? nil : .smooth) {
                    _ = answers.popLast()
                    stage = .questions
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 12)
        }
    }

    private func summaryLine(_ text: String, _ korean: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text).foregroundStyle(Theme.ink)
            Text(korean)
                .font(.koreanRow)
                .foregroundStyle(Theme.ink)
        }
    }
}

/// One small square per question, filled in as you answer.
private struct ProgressSquares: View {
    let total: Int
    let answered: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { i in
                Rectangle()
                    .fill(i < answered ? Theme.grid : Color.clear)
                    .overlay(Rectangle().stroke(i == answered ? Theme.grid : Theme.gridFaint, lineWidth: 1))
                    .frame(height: 10)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Question \(min(answered + 1, total)) of \(total)")
    }
}

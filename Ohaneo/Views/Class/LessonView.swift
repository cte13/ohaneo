import OhaneoCore
import SwiftUI

/// One textbook lesson, split into short sections you can flip between.
struct LessonView: View {
    let lesson: Lesson
    let stage: CourseBook.Stage

    @State private var section: Section = LessonView.initialSection
    @State private var drilling = false

    enum Section: String, CaseIterable, Identifiable {
        case words = "Words", grammar = "Grammar", practice = "Practice", texts = "Texts"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                Picker("Section", selection: $section) {
                    ForEach(Section.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                switch section {
                case .words: LessonWords(lesson: lesson)
                case .grammar: LessonGrammar(lesson: lesson)
                case .practice: LessonPractice(lesson: lesson)
                case .texts: LessonTexts(lesson: lesson)
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .paperBackground()
        .navigationTitle("\(lesson.number)과")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Drill words", systemImage: "rectangle.on.rectangle.angled") { drilling = true }
            }
        }
        .fullScreenCover(isPresented: $drilling) {
            DrillView(title: "\(lesson.number)과 words", words: lesson.drillWords)
        }
    }

    /// Debug launch argument `-lessonSection words|grammar|practice|texts`.
    private static var initialSection: Section {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-lessonSection"), args.indices.contains(i + 1),
           let section = Section.allCases.first(where: { $0.rawValue.lowercased() == args[i + 1] }) {
            return section
        }
        #endif
        return .words
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lesson.title)
                .font(.batang(26, bold: true, relativeTo: .title))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let english = lesson.titleEnglish {
                Text(english).foregroundStyle(Theme.inkSecondary)
            }
            if let hint = stageHint {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(Rectangle().stroke(Theme.gridFaint, lineWidth: 1))
            }
        }
    }

    private var stageHint: String? {
        switch stage {
        case .next: "Next class. Drill the words, then read the grammar and the dialogue."
        case .current: "Homework. The Practice section has every exercise with its answer hidden."
        case .review: "Review. Drill the words and skim the grammar."
        case .later: nil
        }
    }
}

// MARK: Words

private struct LessonWords: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(lesson.vocabulary, id: \.topic) { group in
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading([group.topic, group.topicEnglish].compactMap { $0 }.joined(separator: " · "))
                    WordTable(rows: group.words.map { ($0.korean, $0.english, $0.example) })
                }
            }
            let extra = (lesson.glossary ?? []) + (lesson.reading?.glossary ?? [])
            if !extra.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading("More words from this lesson")
                    WordTable(rows: extra.map { ($0.korean, $0.english, nil) })
                }
            }
            if !lesson.expressions.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeading("Expressions")
                    ForEach(lesson.expressions, id: \.pattern) { expression in
                        VStack(alignment: .leading, spacing: 6) {
                            KoreanLine(expression.pattern, english: expression.english, bold: true)
                            ForEach(expression.examples, id: \.korean) { example in
                                KoreanLine(example.korean, english: example.english)
                                    .padding(.leading, 12)
                            }
                            if let note = expression.note { TipText(note) }
                        }
                    }
                }
            }
        }
    }
}

/// Korean word, meaning and an optional example, ruled like manuscript paper.
private struct WordTable: View {
    let rows: [(korean: String, english: String?, example: String?)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { GridRule() }
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(row.korean)
                                .font(.batang(19, bold: true, relativeTo: .body))
                                .foregroundStyle(Theme.ink)
                            if let english = row.english {
                                Text(english)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.inkSecondary)
                            }
                        }
                        if let example = row.example {
                            Text(example)
                                .font(.batang(15, relativeTo: .subheadline))
                                .foregroundStyle(Theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    ListenButton(text: row.korean, size: .small)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .overlay(Rectangle().stroke(Theme.grid, lineWidth: 1))
    }
}

// MARK: Grammar

private struct LessonGrammar: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 36) {
            ForEach(lesson.grammar, id: \.pattern) { point in
                VStack(alignment: .leading, spacing: 12) {
                    Text(point.pattern)
                        .font(.batang(26, bold: true, relativeTo: .title))
                        .foregroundStyle(Theme.redPen)
                    if let english = point.meaningEnglish {
                        Text(english).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    if let meaning = point.meaning {
                        Text(meaning)
                            .font(.batang(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let form = point.form {
                        Text(form)
                            .font(.batang(17, bold: true, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                    }
                    if let table = point.table, !table.isEmpty {
                        ConjugationTable(rows: table)
                    }
                    if let dialogue = point.dialogue, !dialogue.isEmpty {
                        DialogueView(lines: dialogue)
                    }
                    if let note = point.note { TipText(note) }
                }
            }
        }
    }
}

private struct ConjugationTable: View {
    let rows: [[String]]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 { GridRule().gridCellUnsizedAxes(.horizontal) }
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { column, cell in
                        Text(cell)
                            .font(column == 0 ? .subheadline : .batang(17, bold: column == row.count - 1, relativeTo: .body))
                            .foregroundStyle(column == row.count - 1 ? Theme.redPen : (column == 0 ? Theme.inkSecondary : Theme.ink))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(.horizontal, 12)
        .overlay(Rectangle().stroke(Theme.grid, lineWidth: 1))
    }
}

// MARK: Practice

private struct LessonPractice: View {
    let lesson: Lesson
    @State private var revealed: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack {
                Text("Tap an item to check your answer.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                Button(revealed.isEmpty ? "Show all" : "Hide all") {
                    revealed = revealed.isEmpty ? allKeys : []
                }
                .font(.subheadline)
            }
            ForEach(Array(lesson.exercises.enumerated()), id: \.offset) { index, exercise in
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading(exercise.section + (exercise.number.map { " \($0)" } ?? ""))
                    Text(exercise.instruction)
                        .font(.batang(17, bold: true, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                    if let english = exercise.instructionEnglish {
                        Text(english).font(.caption).foregroundStyle(Theme.inkSecondary)
                    }
                    if let choices = exercise.choices, !choices.isEmpty {
                        Text(choices.joined(separator: "   "))
                            .font(.batang(15, relativeTo: .subheadline))
                            .foregroundStyle(Theme.ink)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .overlay(Rectangle().stroke(Theme.gridFaint, lineWidth: 1))
                    }
                    ForEach(Array(exercise.items.enumerated()), id: \.offset) { itemIndex, item in
                        let key = "\(index)-\(itemIndex)"
                        ExerciseItemView(number: itemIndex + 1, count: exercise.items.count, item: item, revealed: revealed.contains(key))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if revealed.contains(key) { revealed.remove(key) } else { revealed.insert(key) }
                            }
                    }
                }
            }
        }
    }

    private var allKeys: Set<String> {
        Set(lesson.exercises.enumerated().flatMap { index, exercise in
            exercise.items.indices.map { "\(index)-\($0)" }
        })
    }
}

private struct ExerciseItemView: View {
    let number: Int
    let count: Int
    let item: Lesson.Exercise.Item
    let revealed: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if count > 1 {
                Text("\(number))").font(.subheadline).foregroundStyle(Theme.inkSecondary)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let picture = item.picture {
                    Label(picture, systemImage: "photo")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                if let prompt = item.prompt {
                    Text(prompt)
                        .font(.batang(17, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let options = item.options {
                    Text(options.enumerated().map { "\(Self.circled($0.offset)) \($0.element)" }.joined(separator: "   "))
                        .font(.batang(15, relativeTo: .subheadline))
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    if revealed {
                        Text(item.answer ?? "No answer in the book")
                            .font(.batang(17, bold: true, relativeTo: .body))
                            .foregroundStyle(Theme.redPen)
                    } else {
                        Text("Show answer")
                            .font(.subheadline)
                            .foregroundStyle(Theme.grid)
                    }
                }
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.vertical, 4)
    }

    static func circled(_ index: Int) -> String {
        let marks = ["①", "②", "③", "④", "⑤", "⑥"]
        return marks.indices.contains(index) ? marks[index] : "\(index + 1)."
    }
}

// MARK: Texts

private struct LessonTexts: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            if !lesson.goals.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeading("Goals")
                    ForEach(lesson.goals, id: \.self) { goal in
                        Text("• \(goal)").font(.batang(16, relativeTo: .body)).foregroundStyle(Theme.ink)
                    }
                }
            }
            if let listening = lesson.listening, !listening.script.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionHeading("Dialogue")
                        Spacer()
                        ListenButton(text: listening.script.map(\.text).joined(separator: " "), size: .small)
                    }
                    DialogueView(lines: listening.script)
                }
            }
            if let reading = lesson.reading {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionHeading("Reading")
                        Spacer()
                        ListenButton(text: reading.text, size: .small)
                    }
                    Text(reading.text)
                        .font(.koreanBody)
                        .lineSpacing(6)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            if let prompts = lesson.speaking, !prompts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeading("Speaking practice")
                    ForEach(prompts, id: \.self) { prompt in
                        KoreanLine(prompt, english: nil)
                    }
                }
            }
            if let writing = lesson.writing {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeading("Writing task")
                    KoreanLine(writing.task, english: writing.taskEnglish)
                    if let example = writing.example {
                        Text(example)
                            .font(.batang(16, relativeTo: .body))
                            .lineSpacing(5)
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(12)
                            .overlay(Rectangle().stroke(Theme.gridFaint, lineWidth: 1))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: Shared pieces

private struct DialogueView: View {
    let lines: [Lesson.Line]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                GridRow {
                    Text(line.speaker ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.grid)
                    HStack(alignment: .firstTextBaseline) {
                        Text(line.text)
                            .font(.batang(17, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        ListenButton(text: line.text, size: .small)
                            .frame(height: 24)
                    }
                }
            }
        }
    }
}

private struct KoreanLine: View {
    let korean: String
    let english: String?
    var bold = false

    init(_ korean: String, english: String?, bold: Bool = false) {
        self.korean = korean
        self.english = english
        self.bold = bold
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(korean)
                .font(.batang(bold ? 19 : 17, bold: bold, relativeTo: .body))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let english {
                Text(english).font(.caption).foregroundStyle(Theme.inkSecondary)
            }
        }
    }
}

private struct TipText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Label {
            Text(text)
                .font(.batang(14, relativeTo: .footnote))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lightbulb")
        }
        .foregroundStyle(Theme.inkSecondary)
    }
}

import OhaneoCore
import SwiftUI

/// The front of a card: the item on manuscript paper, with its type and level.
struct CardFront: View {
    let item: StudyItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ManuscriptGrid(text: item.korean)
            HStack(alignment: .center, spacing: 10) {
                if let pos = item.partOfSpeech {
                    Text(pos.capitalized)
                        .foregroundStyle(Theme.inkSecondary)
                } else if item.kind == .grammar {
                    Text("Grammar")
                        .foregroundStyle(Theme.inkSecondary)
                }
                Text(item.level.korean)
                    .font(.batang(15, bold: true, relativeTo: .subheadline))
                    .foregroundStyle(Theme.grid)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .overlay(Rectangle().stroke(Theme.grid.opacity(0.6), lineWidth: 1))
                    .accessibilityLabel("Level \(item.level.rawValue)")
                Spacer()
                if item.kind != .grammar {
                    ListenButton(text: item.korean)
                }
            }
            .font(.subheadline)
            if item.kind == .grammar {
                Text(item.meaning)
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Everything behind "Show meaning": curated facts plus AI-written examples and notes.
struct CardDetails: View {
    let item: StudyItem
    @Environment(StudyService.self) private var service

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            if item.kind == .grammar {
                grammarDetails
            } else {
                vocabDetails
            }
        }
    }

    // MARK: Vocab

    @ViewBuilder private var vocabDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.meaning)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let hanja = item.hanja {
                    Text(hanja)
                        .font(.batang(22, relativeTo: .title2))
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityLabel("Hanja \(hanja)")
                }
            }
            if let definition = item.definition {
                Text(definition)
                    .font(.callout)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let forms = item.forms {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading("Forms")
                FormsTable(forms: forms)
            }
        }
        examples
        if let nuance = item.nuance {
            note("How it's used", nuance)
        }
        if let mnemonic = item.mnemonic {
            note("Memory hook", mnemonic)
        }
    }

    // MARK: Grammar

    @ViewBuilder private var grammarDetails: some View {
        if let grammar = item.grammar {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeading("How to form it")
                FormationTable(rules: grammar.formation)
            }
            examples
            if !grammar.contrasts.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeading("Compared with similar patterns")
                    ForEach(grammar.contrasts, id: \.patternID) { contrast in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(contrast.pattern)
                                .font(.batang(18, bold: true, relativeTo: .headline))
                                .foregroundStyle(Theme.ink)
                            Text(contrast.note)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let register = grammar.register {
                note("When to use it", register)
            }
            if let mistake = grammar.commonMistake {
                note("Common mistake", mistake)
            }
        }
    }

    // MARK: Shared

    @ViewBuilder private var examples: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeading("Examples")
            if service.generating.contains(item.id) || (!item.hasGeneratedContent && !item.generationFailed) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Writing examples with words you know…")
                        .foregroundStyle(Theme.inkSecondary)
                }
                .font(.subheadline)
            } else if item.generationFailed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apple Intelligence couldn't write examples this time.")
                        .foregroundStyle(Theme.inkSecondary)
                    Button("Try again") { service.retryGeneration(for: item) }
                        .buttonStyle(.glass)
                }
                .font(.subheadline)
            } else if item.examples.isEmpty {
                Text("No examples passed the check this time.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                ForEach(item.examples, id: \.korean) { example in
                    ExampleView(example: example)
                }
            }
        }
    }

    private func note(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeading(title)
            Text(text)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Polite, polite past and formal forms of a verb or adjective, each with a
/// listen button.
struct FormsTable: View {
    let forms: WordForms

    private var rows: [(label: String, register: String, form: String)] {
        [
            ("Polite", "해요체", forms.polite),
            ("Polite past", "해요체", forms.politePast),
            ("Formal", "합니다체", forms.formal),
        ]
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    GridRule().gridCellUnsizedAxes(.horizontal)
                }
                GridRow {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.label)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                        Text(row.register)
                            .font(.batang(13, relativeTo: .caption))
                            .foregroundStyle(Theme.inkSecondary.opacity(0.8))
                    }
                    Text(row.form)
                        .font(.batang(19, bold: true, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ListenButton(text: row.form, size: .small)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .overlay(Rectangle().stroke(Theme.grid, lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

/// Verb / adjective / noun / past rows, drawn like a ruled table.
struct FormationTable: View {
    let rules: [FormationRule]

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 0) {
            ForEach(Array(rules.enumerated()), id: \.offset) { index, rule in
                if index > 0 {
                    GridRule().gridCellUnsizedAxes(.horizontal)
                }
                GridRow {
                    Text(rule.appliesTo.label)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                    Text(rule.form)
                        .font(.batang(17, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                    Text(rule.example)
                        .font(.batang(17, bold: true, relativeTo: .body))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 9)
            }
        }
        .padding(.horizontal, 12)
        .overlay(Rectangle().stroke(Theme.grid, lineWidth: 1))
    }
}

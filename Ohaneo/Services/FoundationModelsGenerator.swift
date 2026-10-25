import Foundation
import FoundationModels
import OhaneoCore

/// Writes examples, nuance notes and memory hooks with the on-device model.
/// Facts (meanings, formation rules) are passed in from the bundled lists and
/// the model is told not to change them.
struct FoundationModelsGenerator: ContentGenerator {
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings › Apple Intelligence & Siri."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still downloading. Try again in a few minutes."
        case .unavailable:
            return "Apple Intelligence isn't available right now."
        }
    }

    private static let instructions = """
    You write study material for an English-speaking learner of Korean at upper-beginner level. \
    Write natural, everyday Korean in the polite 해요체 style unless told otherwise. \
    Keep sentences short and concrete. Never use romanization. \
    The facts you are given about a word or grammar pattern are correct; do not contradict them.
    """

    func vocabContent(for word: SeedWord, vocabulary: [String]) async throws -> VocabContent {
        let session = LanguageModelSession(instructions: Self.instructions)
        var prompt = """
        Target \(word.kind == .phrase ? "expression" : "word"): \(word.korean)
        Meaning: \(word.meaning)
        """
        if let pos = word.partOfSpeech { prompt += "\nPart of speech: \(pos)" }
        if let definition = word.definition { prompt += "\nDictionary definition: \(definition)" }
        if let hanja = word.hanja { prompt += "\nHanja: \(hanja)" }
        if let forms = word.forms {
            prompt += """

            Conjugated forms: \(forms.polite) (polite present), \(forms.politePast) (polite past), \(forms.formal) (formal).
            This is a \(word.partOfSpeech ?? "verb"), so it must always be conjugated inside a sentence. \
            Never write the dictionary form \(word.korean) inside a sentence.
            """
        }
        prompt += """

        Write 2 short, natural example sentences that use the target with exactly this meaning. \
        Where it sounds natural, reuse some of these words the learner already knows: \(vocabulary.joined(separator: ", ")).
        For each example, `highlight` must be copied exactly from the Korean sentence: the part where the target appears, \
        including any conjugation or particle attached to it.
        Then write a short note on how Koreans use it: common situations and word pairings. \
        Base the note only on the meaning given; don't invent extra meanings or feelings. \
        Finally, a short memory hook.
        """
        let response = try await session.respond(to: prompt, generating: GeneratedVocab.self, options: GenerationOptions(temperature: 0.5))
        let content = response.content
        return VocabContent(
            examples: content.examples.map(\.example),
            nuance: content.nuance.trimmed,
            mnemonic: content.mnemonic.trimmed
        )
    }

    func grammarExamples(for pattern: GrammarPattern, vocabulary: [String]) async throws -> [Example] {
        let session = LanguageModelSession(instructions: Self.instructions)
        let rules = pattern.formation.map { "\($0.appliesTo.rawValue): \($0.form) (e.g. \($0.example))" }.joined(separator: "; ")
        var prompt = """
        Grammar pattern: \(pattern.pattern)
        What it does: \(pattern.meaning)
        How to form it: \(rules)
        """
        if let register = pattern.register { prompt += "\nUsage note: \(register)" }
        if let mistake = pattern.commonMistake { prompt += "\nCommon mistake to avoid: \(mistake)" }
        prompt += """

        Write 3 different example sentences that use this pattern correctly, following the formation rules exactly. \
        Where it sounds natural, reuse some of these words the learner already knows: \(vocabulary.joined(separator: ", ")).
        For each example, `highlight` must be copied exactly from the Korean sentence: the conjugated word that contains the pattern.
        """
        let response = try await session.respond(to: prompt, generating: GeneratedGrammar.self, options: GenerationOptions(temperature: 0.6))
        return response.content.examples.map(\.example)
    }
}

@Generable
struct GeneratedExample {
    @Guide(description: "A short, natural Korean sentence in polite 해요체. Hangul only, no romanization.")
    var korean: String
    @Guide(description: "A natural English translation of the Korean sentence.")
    var english: String
    @Guide(description: "Text copied character for character from the Korean sentence: where the target appears.")
    var highlight: String

    var example: Example {
        Example(korean: korean.trimmed, english: english.trimmed, highlight: highlight.trimmed)
    }
}

@Generable
struct GeneratedVocab {
    @Guide(description: "Two example sentences.", .count(2))
    var examples: [GeneratedExample]
    @Guide(description: "One or two sentences in English on when and how Koreans use this, its tone, and common word pairings.")
    var nuance: String
    @Guide(description: "One short sentence in English that helps remember the meaning, for example through its sound or Hanja.")
    var mnemonic: String
}

@Generable
struct GeneratedGrammar {
    @Guide(description: "Three example sentences.", .count(3))
    var examples: [GeneratedExample]
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

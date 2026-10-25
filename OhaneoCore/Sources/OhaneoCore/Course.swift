import Foundation

/// A textbook transcribed lesson by lesson, for the Class tab. Everything here
/// is copied from the book; the app adds nothing to it.
public struct CourseBook: Codable, Sendable, Equatable {
    public var title: String
    public var lessons: [Lesson]

    public init(title: String, lessons: [Lesson]) {
        self.title = title
        self.lessons = lessons.sorted { $0.number < $1.number }
    }

    public func lesson(_ number: Int) -> Lesson? {
        lessons.first { $0.number == number }
    }

    /// One JSON file per lesson (see docs/course.md).
    public static func load(title: String, lessonFiles: [URL]) throws -> CourseBook {
        let decoder = JSONDecoder()
        let lessons = try lessonFiles.map { try decoder.decode(Lesson.self, from: Data(contentsOf: $0)) }
        return CourseBook(title: title, lessons: lessons)
    }

    /// Where a lesson sits relative to the next class.
    public enum Stage: Equatable, Sendable {
        /// Covered two or more classes ago.
        case review
        /// The most recent class: homework time.
        case current
        /// The next class: preparing.
        case next
        case later
    }

    public static func stage(of lesson: Int, nextClass: Int) -> Stage {
        switch lesson - nextClass {
        case ..<(-1): .review
        case -1: .current
        case 0: .next
        default: .later
        }
    }
}

public struct Lesson: Codable, Sendable, Equatable, Identifiable {
    public var number: Int
    public var title: String
    public var titleEnglish: String?
    public var goals: [String]
    public var thinkAbout: [String]?
    public var vocabulary: [VocabularyGroup]
    public var glossary: [GlossaryWord]?
    public var expressions: [Expression]
    public var grammar: [GrammarPoint]
    public var listening: Listening?
    public var reading: Reading?
    public var speaking: [String]?
    public var writing: Writing?
    public var exercises: [Exercise]

    public var id: Int { number }

    /// Every word to drill: the topic words, then glossary words from the
    /// vocabulary, expressions and reading pages.
    public var drillWords: [DrillWord] {
        var seen = Set<String>()
        var result: [DrillWord] = []
        func add(_ word: DrillWord) {
            guard seen.insert(word.korean).inserted else { return }
            result.append(word)
        }
        for group in vocabulary {
            for w in group.words {
                add(DrillWord(korean: w.korean, english: w.english, example: w.example, exampleEnglish: w.exampleEnglish))
            }
        }
        for w in (glossary ?? []) + (reading?.glossary ?? []) {
            add(DrillWord(korean: w.korean, english: w.english))
        }
        return result
    }

    public struct VocabularyGroup: Codable, Sendable, Equatable {
        public var topic: String
        public var topicEnglish: String?
        public var words: [Word]
    }

    public struct Word: Codable, Sendable, Equatable {
        public var korean: String
        public var english: String?
        public var example: String?
        public var exampleEnglish: String?
    }

    public struct GlossaryWord: Codable, Sendable, Equatable {
        public var korean: String
        public var english: String?
    }

    public struct Sentence: Codable, Sendable, Equatable {
        public var korean: String
        public var english: String?
    }

    public struct Expression: Codable, Sendable, Equatable {
        public var pattern: String
        public var english: String?
        public var examples: [Sentence]
        public var note: String?
    }

    public struct Line: Codable, Sendable, Equatable {
        public var speaker: String?
        public var text: String
    }

    public struct GrammarPoint: Codable, Sendable, Equatable {
        public var pattern: String
        public var meaning: String?
        public var meaningEnglish: String?
        public var form: String?
        public var formEnglish: String?
        /// Rows of [condition, dictionary form, result], as printed.
        public var table: [[String]]?
        public var dialogue: [Line]?
        public var note: String?
    }

    public struct Listening: Codable, Sendable, Equatable {
        public var intro: String?
        public var script: [Line]
    }

    public struct Reading: Codable, Sendable, Equatable {
        public var text: String
        public var glossary: [GlossaryWord]?
    }

    public struct Writing: Codable, Sendable, Equatable {
        public var task: String
        public var taskEnglish: String?
        public var example: String?
    }

    public struct Exercise: Codable, Sendable, Equatable {
        public var section: String
        public var number: Int?
        public var instruction: String
        public var instructionEnglish: String?
        public var choices: [String]?
        public var items: [Item]

        public struct Item: Codable, Sendable, Equatable {
            public var prompt: String?
            public var options: [String]?
            /// A short description when the item depends on a picture.
            public var picture: String?
            public var answer: String?
        }
    }
}

/// One flashcard.
public struct DrillWord: Sendable, Equatable, Hashable {
    public var korean: String
    public var english: String?
    public var example: String?
    public var exampleEnglish: String?

    public init(korean: String, english: String?, example: String? = nil, exampleEnglish: String? = nil) {
        self.korean = korean
        self.english = english
        self.example = example
        self.exampleEnglish = exampleEnglish
    }
}

/// A flashcard round: cards you miss go to the back of the deck until every
/// card has been answered "Got it" once.
public struct DrillSession: Sendable, Equatable {
    public private(set) var queue: [DrillWord]
    public private(set) var done: [DrillWord] = []
    public private(set) var missed: Set<DrillWord> = []
    public let total: Int

    public init(words: [DrillWord]) {
        queue = words
        total = words.count
    }

    public var current: DrillWord? { queue.first }
    public var isFinished: Bool { queue.isEmpty }

    public mutating func gotIt() {
        guard !queue.isEmpty else { return }
        done.append(queue.removeFirst())
    }

    public mutating func again() {
        guard !queue.isEmpty else { return }
        let word = queue.removeFirst()
        missed.insert(word)
        queue.append(word)
    }
}

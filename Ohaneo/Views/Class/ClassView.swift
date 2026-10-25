import OhaneoCore
import SwiftUI

/// The Class tab: textbook lessons for the course you're taking, grouped by
/// where they sit relative to your next class.
struct ClassView: View {
    let course: CourseBook?

    @AppStorage("nextClassLesson") private var nextClass = 13
    @State private var path: [Int] = ClassView.initialPath

    /// Lesson files bundled from Ohaneo/Resources/Course (kept out of git).
    static let bundledCourse: CourseBook? = {
        let files = (Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("sejong1-") }
        guard !files.isEmpty else { return nil }
        return try? CourseBook.load(title: "바로 배워 바로 쓰는 세종학당 한국어 1", lessonFiles: files)
    }()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let course, !course.lessons.isEmpty {
                    list(course)
                } else {
                    ContentUnavailableView(
                        "No textbook loaded",
                        systemImage: "book.closed",
                        description: Text("Add lesson files to Ohaneo/Resources/Course and rebuild. See docs/course.md.")
                    )
                }
            }
            .paperBackground()
            .navigationTitle("Class")
            .navigationDestination(for: Int.self) { number in
                if let lesson = course?.lesson(number) {
                    LessonView(lesson: lesson, stage: CourseBook.stage(of: number, nextClass: nextClass))
                }
            }
        }
    }

    /// Debug launch argument `-lesson N` opens that lesson, for screenshots.
    private static var initialPath: [Int] {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-lesson"), args.indices.contains(i + 1), let n = Int(args[i + 1]) { return [n] }
        #endif
        return []
    }

    private func list(_ course: CourseBook) -> some View {
        let groups = sections(course)
        return List {
            Section {
                Picker("Next class", selection: $nextClass) {
                    ForEach(course.lessons) { lesson in
                        Text("\(lesson.number)과").tag(lesson.number)
                    }
                }
            } footer: {
                Text(course.title)
            }
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.lessons) { lesson in
                        NavigationLink(value: lesson.number) { LessonRow(lesson: lesson) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func sections(_ course: CourseBook) -> [(title: String, lessons: [Lesson])] {
        let stages: [(CourseBook.Stage, String)] = [
            (.next, "Prepare for class"),
            (.current, "Homework"),
            (.review, "Review"),
            (.later, "Coming up"),
        ]
        return stages.compactMap { stage, title in
            var lessons = course.lessons.filter { CourseBook.stage(of: $0.number, nextClass: nextClass) == stage }
            if stage == .review { lessons.reverse() }
            return lessons.isEmpty ? nil : (title, lessons)
        }
    }
}

private struct LessonRow: View {
    let lesson: Lesson

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(lesson.number)과")
                    .font(.batang(15, bold: true, relativeTo: .subheadline))
                    .foregroundStyle(Theme.grid)
                Text(lesson.title)
                    .font(.batang(18, bold: true, relativeTo: .body))
                    .foregroundStyle(Theme.ink)
            }
            if let english = lesson.titleEnglish {
                Text(english)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Text(summary)
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.vertical, 4)
    }

    private var summary: String {
        let grammar = lesson.grammar.map(\.pattern).joined(separator: " · ")
        return "\(lesson.drillWords.count) words · \(grammar)"
    }
}

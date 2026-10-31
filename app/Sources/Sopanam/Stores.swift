import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class CourseStore: ObservableObject {
    @Published private(set) var course: Course = .empty
    @Published private(set) var revision = 0
    @Published var errorMessage: String?

    private(set) var lessonByID: [String: Lesson] = [:]
    private(set) var unitByLesson: [String: CourseUnit] = [:]
    private(set) var cardsByLesson: [String: [Card]] = [:]
    private(set) var lessons: [Lesson] = []

    init() { load() }

    /// The copy inside the .app, or the SwiftPM resource bundle when run with `swift run`.
    func load() {
        guard let url = Bundle.main.url(forResource: "course", withExtension: "json")
            ?? Bundle.module.url(forResource: "course", withExtension: "json") else {
            errorMessage = "course.json is missing from the app."
            return
        }
        do {
            course = try JSONDecoder().decode(Course.self, from: Data(contentsOf: url))
            lessons = course.lessons
            lessonByID = Dictionary(uniqueKeysWithValues: lessons.map { ($0.id, $0) })
            unitByLesson = [:]
            for unit in course.units {
                for lesson in unit.lessons { unitByLesson[lesson.id] = unit }
            }
            cardsByLesson = Dictionary(grouping: course.cards, by: \.lesson)
            revision += 1
        } catch {
            errorMessage = "Could not read course.json: \(error)"
        }
    }
}

/// Spaced-review state of one card: box 0–5 and the day it is next due.
struct Review: Codable, Hashable {
    var b: Int
    var d: Int
}

@MainActor
final class ProgressStore: ObservableObject {
    /// Review intervals in days for boxes 1–5. A missed card drops to box 0, due tomorrow.
    static let intervals = [1, 3, 7, 16, 35]

    @Published private(set) var done: Set<String>
    @Published private(set) var srs: [String: Review]
    @Published private(set) var quizBest: [String: Int]

    private let defaults = UserDefaults.standard

    init() {
        done = Set(defaults.stringArray(forKey: "doneLessons") ?? [])
        srs = (defaults.data(forKey: "srs")).flatMap { try? JSONDecoder().decode([String: Review].self, from: $0) } ?? [:]
        quizBest = (defaults.dictionary(forKey: "quizBest") as? [String: Int]) ?? [:]
    }

    /// Days since 1970 in local time; the web app counts days the same way.
    static var today: Int {
        let now = Date().timeIntervalSince1970 + Double(TimeZone.current.secondsFromGMT())
        return Int((now / 86400).rounded(.down))
    }

    enum State { case new, learning, known, review }

    func state(_ id: String) -> State {
        guard let r = srs[id] else { return .new }
        if r.b >= 3 { return .known }
        return r.b == 0 ? .review : .learning
    }

    func isDue(_ id: String) -> Bool { (srs[id]?.d ?? .max) <= Self.today }

    func grade(_ id: String, correct: Bool) {
        let box = correct ? min((srs[id]?.b ?? 0) + 1, Self.intervals.count) : 0
        srs[id] = Review(b: box, d: Self.today + (correct ? Self.intervals[box - 1] : 1))
        save()
    }

    /// Learn mode "Known": jump to box 3 (due in a week), or undo it.
    func toggleKnown(_ id: String) {
        if let r = srs[id], r.b >= 3 {
            srs.removeValue(forKey: id)
        } else {
            srs[id] = Review(b: 3, d: Self.today + Self.intervals[2])
        }
        save()
    }

    func toggleReview(_ id: String) {
        if srs[id]?.b == 0 {
            srs.removeValue(forKey: id)
        } else {
            srs[id] = Review(b: 0, d: Self.today)
        }
        save()
    }

    func toggleDone(_ lessonID: String) {
        if done.remove(lessonID) == nil { done.insert(lessonID) }
        save()
    }

    func recordQuiz(_ lessonID: String, percent: Int) {
        quizBest[lessonID] = max(quizBest[lessonID] ?? 0, percent)
        save()
    }

    func reset() {
        let alert = NSAlert()
        alert.messageText = "Reset all progress?"
        alert.informativeText = "This clears completed lessons, card reviews and quiz scores."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        done = []
        srs = [:]
        quizBest = [:]
        save()
    }

    private struct Export: Codable {
        var done: [String]
        var srs: [String: Review]
        var quizBest: [String: Int]
    }

    /// The same JSON the web app exports, so progress can move between Mac and phone.
    func exportProgress() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "sopanam_progress.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(Export(done: done.sorted(), srs: srs, quizBest: quizBest)).write(to: url)
    }

    func importProgress() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let other = try? JSONDecoder().decode(Export.self, from: data) else { return }
        done.formUnion(other.done)
        for (id, r) in other.srs where (srs[id]?.d ?? .min) < r.d { srs[id] = r }
        for (id, p) in other.quizBest { quizBest[id] = max(quizBest[id] ?? 0, p) }
        save()
    }

    private func save() {
        defaults.set(Array(done), forKey: "doneLessons")
        defaults.set(try? JSONEncoder().encode(srs), forKey: "srs")
        defaults.set(quizBest, forKey: "quizBest")
    }
}

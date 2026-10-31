import AVFoundation
import SwiftUI

/// What the window is showing, plus the running card deck and quiz.
@MainActor
final class Session: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var mode: Mode { didSet { defaults.set(mode.rawValue, forKey: "mode") } }
    @Published var lessonID: String? { didSet { defaults.set(lessonID, forKey: "lesson") } }
    /// Lessons ticked for Cards and Quiz; nil means every lesson.
    @Published var chosen: Set<String>? {
        didSet { defaults.set(chosen.map { Array($0) }, forKey: "chosenLessons") }
    }
    @Published var study: StudyMode { didSet { defaults.set(study.rawValue, forKey: "study"); restartCards() } }
    @Published var filter: CardFilter { didSet { defaults.set(filter.rawValue, forKey: "filter"); restartCards() } }
    @Published var shuffle: Bool { didSet { defaults.set(shuffle, forKey: "shuffle"); restartCards() } }
    @Published var quizCount: Int { didSet { defaults.set(quizCount, forKey: "quizCount") } }

    // Cards
    @Published var deck: [Card] = []
    @Published var pos = 0
    @Published var flipped = false
    @Published var answers: [String: Bool] = [:]
    @Published var deckFinished = false

    // Quiz
    struct Question: Identifiable {
        let id = UUID()
        let lesson: String
        let item: QuizItem
        let order: [Int]
    }
    @Published var questions: [Question] = []
    @Published var qpos = 0
    @Published var chosenOption: Int?
    @Published var results: [Bool] = []
    @Published var quizActive = false
    @Published var quizFinished = false
    @Published var quizScope: String?

    weak var course: CourseStore?
    weak var progress: ProgressStore?

    init() {
        mode = Mode(rawValue: defaults.string(forKey: "mode") ?? "") ?? .lessons
        lessonID = defaults.string(forKey: "lesson")
        chosen = defaults.stringArray(forKey: "chosenLessons").map(Set.init)
        study = StudyMode(rawValue: defaults.string(forKey: "study") ?? "") ?? .learn
        filter = CardFilter(rawValue: defaults.string(forKey: "filter") ?? "") ?? .all
        shuffle = defaults.bool(forKey: "shuffle")
        quizCount = defaults.object(forKey: "quizCount") as? Int ?? 10
    }

    func attach(course: CourseStore, progress: ProgressStore) {
        self.course = course
        self.progress = progress
        if lessonID.flatMap({ course.lessonByID[$0] }) == nil { lessonID = course.lessons.first?.id }
        restartCards()
    }

    var selectedLessons: Set<String> {
        let all = Set(course?.lessons.map(\.id) ?? [])
        return chosen.map { $0.intersection(all) } ?? all
    }

    func setChosen(_ ids: [String], on: Bool) {
        var set = selectedLessons
        if on { set.formUnion(ids) } else { set.subtract(ids) }
        chosen = set.count == course?.lessons.count ? nil : set
        restartCards()
    }

    // MARK: Lessons

    var lessonIndex: Int? { course?.lessons.firstIndex { $0.id == lessonID } }

    func stepLesson(_ delta: Int) {
        guard let lessons = course?.lessons, let i = lessonIndex else { return }
        let j = i + delta
        if lessons.indices.contains(j) { lessonID = lessons[j].id }
    }

    // MARK: Cards

    func restartCards() {
        guard let course, let progress else { return }
        let sel = selectedLessons
        var pool = course.course.cards.filter { sel.contains($0.lesson) }
        switch filter {
        case .all: break
        case .new: pool = pool.filter { progress.state($0.id) == .new }
        case .due: pool = pool.filter { progress.isDue($0.id) }
        case .review: pool = pool.filter { progress.state($0.id) == .review }
        }
        startDeck(shuffle ? pool.shuffled() : pool)
    }

    func startDeck(_ cards: [Card]) {
        deck = cards
        pos = 0
        flipped = false
        answers = [:]
        deckFinished = false
    }

    func practise(lesson: String) {
        chosen = [lesson]
        filter = .all
        mode = .cards
        restartCards()
    }

    var card: Card? { deck[safe: pos] }

    func moveCard(_ delta: Int) {
        guard !deck.isEmpty else { return }
        pos = (pos + delta + deck.count) % deck.count
        flipped = false
    }

    func reveal() {
        if study == .test { flipped = true }
    }

    func answer(_ correct: Bool) {
        guard let card, flipped, study == .test else { return }
        answers[card.id] = correct
        progress?.grade(card.id, correct: correct)
        for step in 1...deck.count {
            let p = (pos + step) % deck.count
            if answers[deck[p].id] == nil {
                pos = p
                flipped = false
                return
            }
        }
        deckFinished = true
    }

    // MARK: Quiz

    func startQuiz(scope: String? = nil, items: [(String, QuizItem)]? = nil) {
        guard let course else { return }
        let ids = scope.map { [$0] } ?? course.lessons.map(\.id).filter(selectedLessons.contains)
        var pool = items ?? ids.flatMap { id in (course.lessonByID[id]?.quiz ?? []).map { (id, $0) } }
        pool.shuffle()
        if scope == nil && items == nil { pool = Array(pool.prefix(quizCount)) }
        questions = pool.map { Question(lesson: $0.0, item: $0.1, order: Array($0.1.options.indices).shuffled()) }
        qpos = 0
        chosenOption = nil
        results = []
        quizScope = scope
        quizFinished = false
        quizActive = true
        mode = .quiz
    }

    var question: Question? { questions[safe: qpos] }

    func choose(_ option: Int) {
        guard chosenOption == nil, let q = question else { return }
        chosenOption = option
        results.append(option == q.item.answer)
    }

    func chooseShown(_ k: Int) {
        if let q = question, let option = q.order[safe: k] { choose(option) }
    }

    func nextQuestion() {
        guard chosenOption != nil else { return }
        if qpos == questions.count - 1 {
            quizFinished = true
            if let scope = quizScope, !questions.isEmpty {
                let percent = Int((Double(results.filter { $0 }.count) / Double(questions.count) * 100).rounded())
                progress?.recordQuiz(scope, percent: percent)
            }
        } else {
            qpos += 1
            chosenOption = nil
        }
    }

    func retryMissed() {
        let missed = questions.enumerated().filter { !(results[safe: $0.offset] ?? false) }.map { ($0.element.lesson, $0.element.item) }
        startQuiz(scope: nil, items: missed)
    }
}

/// Reads verses aloud with a Hindi voice for Devanagari or a Telugu voice for Telugu script.
@MainActor
final class Speech: ObservableObject {
    private let synth = AVSpeechSynthesizer()
    @AppStorage("voice") var voice = "hi"

    private var language: String { voice == "te" ? "te-IN" : "hi-IN" }

    var available: Bool { voice != "off" && AVSpeechSynthesisVoice(language: language) != nil }

    var voiceName: String { AVSpeechSynthesisVoice(language: language)?.name ?? language }

    func speak(_ lines: [String]) {
        synth.stopSpeaking(at: .immediate)
        let text = lines.joined(separator: "। ")
            .replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
        let utterance = AVSpeechUtterance(string: voice == "te" ? Lipi.devaToTelugu(text) : text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.8
        synth.speak(utterance)
    }
}

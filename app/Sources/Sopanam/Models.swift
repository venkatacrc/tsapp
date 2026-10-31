import Foundation

/// The course as written by tools/build_course.py.
struct Course: Decodable {
    let title: String
    let summary: String
    let units: [CourseUnit]
    let cards: [Card]

    static let empty = Course(title: "", summary: "", units: [], cards: [])

    var lessons: [Lesson] { units.flatMap(\.lessons) }
}

struct CourseUnit: Decodable, Identifiable, Hashable {
    let id: String
    let num: Int
    let title: String
    let summary: String
    let lessons: [Lesson]
}

struct Lesson: Decodable, Identifiable, Hashable {
    let id: String
    let num: String
    let title: String
    let summary: String
    let blocks: [Block]
    let quiz: [QuizItem]

    static func == (a: Lesson, b: Lesson) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// One piece of a lesson. `t` is h2, h3, p, ul, ol, table, tip or ex; the other fields are
/// filled in for the kinds that use them.
struct Block: Decodable {
    let t: String
    var text: String?
    var items: [String]?
    var lit: Bool?
    // table
    var head: [String]?
    var rows: [[String]]?
    var iast: [[String?]]?
    // tip
    var kind: String?
    var title: String?
    var paragraphs: [String]?
    // example
    var src: String?
    var meter: String?
    var speaker: String?
    var sa: [String]?
    var saIast: [String]?
    var split: String?
    var splitIast: String?
    var anvaya: String?
    var anvayaIast: String?
    var words: [[String]]?
    var te: String?
    var en: String?
    var notes: [String]?

    var literal: Bool { lit ?? false }

    enum CodingKeys: String, CodingKey {
        case t, text, items, lit, head, rows, iast, kind, title, src, meter, speaker, sa, split
        case anvaya, words, te, en, notes
        case splitIast = "split_iast"
        case anvayaIast = "anvaya_iast"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        t = try c.decode(String.self, forKey: .t)
        items = try c.decodeIfPresent([String].self, forKey: .items)
        lit = try c.decodeIfPresent(Bool.self, forKey: .lit)
        head = try c.decodeIfPresent([String].self, forKey: .head)
        rows = try c.decodeIfPresent([[String]].self, forKey: .rows)
        kind = try c.decodeIfPresent(String.self, forKey: .kind)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        src = try c.decodeIfPresent(String.self, forKey: .src)
        meter = try c.decodeIfPresent(String.self, forKey: .meter)
        speaker = try c.decodeIfPresent(String.self, forKey: .speaker)
        sa = try c.decodeIfPresent([String].self, forKey: .sa)
        split = try c.decodeIfPresent(String.self, forKey: .split)
        splitIast = try c.decodeIfPresent(String.self, forKey: .splitIast)
        anvaya = try c.decodeIfPresent(String.self, forKey: .anvaya)
        anvayaIast = try c.decodeIfPresent(String.self, forKey: .anvayaIast)
        words = try c.decodeIfPresent([[String]].self, forKey: .words)
        te = try c.decodeIfPresent(String.self, forKey: .te)
        en = try c.decodeIfPresent(String.self, forKey: .en)
        notes = try c.decodeIfPresent([String].self, forKey: .notes)
        // `text` is a string for paragraphs and headings but a list of paragraphs for tips;
        // `iast` is per-cell for tables but per-line for examples.
        if t == "tip" {
            paragraphs = try c.decodeIfPresent([String].self, forKey: .text)
        } else {
            text = try c.decodeIfPresent(String.self, forKey: .text)
        }
        if t == "ex" {
            saIast = try c.decodeIfPresent([String].self, forKey: .iast)
        } else {
            iast = try c.decodeIfPresent([[String?]].self, forKey: .iast)
        }
    }
}

struct QuizItem: Decodable, Hashable {
    let q: String
    let options: [String]
    let answer: Int
    let why: String
}

struct Card: Decodable, Identifiable, Hashable {
    let id: String
    let unit: String
    let lesson: String
    let context: String
    let kind: String
    let prompt: Cell
    let answer: [Cell]
    let lit: Bool?

    struct Cell: Decodable, Hashable {
        let head: String
        let text: String
        let iast: String?
    }

    var literal: Bool { lit ?? false }
}

enum Mode: String, CaseIterable, Identifiable {
    case lessons, cards, quiz, lipi
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lessons: "పాఠాలు"
        case .cards: "Cards"
        case .quiz: "Quiz"
        case .lipi: "లిపి"
        }
    }
}

enum StudyMode: String, CaseIterable, Identifiable {
    case learn, test
    var id: String { rawValue }
    var title: String { self == .learn ? "Learn" : "Test" }
}

enum CardFilter: String, CaseIterable, Identifiable {
    case all, new, due, review
    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All cards"
        case .new: "New"
        case .due: "Due today"
        case .review: "Marked for review"
        }
    }
}

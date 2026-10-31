import Foundation

/// Transliteration between Devanagari, Telugu script and IAST. Mirrors tools/lipi.py and
/// web/lipi.js. Devanagari and Telugu share one Unicode layout, so most letters convert by a
/// fixed offset; IAST needs the inherent-vowel rule.
enum Lipi {
    enum Script: String { case te, deva, iast }

    private static let offset: UInt32 = 0x0C00 - 0x0900
    private static let devaToTeSpecial: [Character: String] = [
        "ॐ": "ఓం", "।": "।", "॥": "॥", "\u{093C}": "", "\u{0945}": "\u{0C46}", "\u{0949}": "\u{0C4A}",
    ]
    private static let vowels: [Character: String] = [
        "अ": "a", "आ": "ā", "इ": "i", "ई": "ī", "उ": "u", "ऊ": "ū", "ऋ": "ṛ", "ॠ": "ṝ", "ऌ": "ḷ", "ॡ": "ḹ",
        "ए": "e", "ऐ": "ai", "ओ": "o", "औ": "au", "ऎ": "ĕ", "ऒ": "ŏ",
    ]
    private static let signs: [Character: String] = [
        "ा": "ā", "ि": "i", "ी": "ī", "ु": "u", "ू": "ū", "ृ": "ṛ", "ॄ": "ṝ", "ॢ": "ḷ", "ॣ": "ḹ",
        "े": "e", "ै": "ai", "ो": "o", "ौ": "au", "ॆ": "ĕ", "ॊ": "ŏ",
    ]
    private static let consonants: [Character: String] = [
        "क": "k", "ख": "kh", "ग": "g", "घ": "gh", "ङ": "ṅ", "च": "c", "छ": "ch", "ज": "j", "झ": "jh", "ञ": "ñ",
        "ट": "ṭ", "ठ": "ṭh", "ड": "ḍ", "ढ": "ḍh", "ण": "ṇ", "त": "t", "थ": "th", "द": "d", "ध": "dh", "न": "n",
        "प": "p", "फ": "ph", "ब": "b", "भ": "bh", "म": "m", "य": "y", "र": "r", "ल": "l", "व": "v",
        "श": "ś", "ष": "ṣ", "स": "s", "ह": "h", "ळ": "ḻ", "ऱ": "ṟ", "ऴ": "ẓ",
    ]
    private static let other: [Character: String] = [
        "ं": "ṃ", "ः": "ḥ", "ँ": "m̐", "ऽ": "'", "ॐ": "oṃ", "।": "|", "॥": "||", "्": "", "\u{093C}": "",
        "\u{200C}": "", "\u{200D}": "",
    ]

    static func isDeva(_ s: Unicode.Scalar) -> Bool { (0x0900...0x097F).contains(s.value) }
    static func isTelugu(_ s: Unicode.Scalar) -> Bool { (0x0C00...0x0C7F).contains(s.value) }

    static func hasDeva(_ text: String) -> Bool { text.unicodeScalars.contains(where: isDeva) }

    /// Most letters are Devanagari, so a second-script line helps rather than repeats.
    static func mostlySanskrit(_ text: String) -> Bool {
        var deva = 0, rest = 0
        for s in text.unicodeScalars {
            if isDeva(s) { deva += 1 } else if isTelugu(s) || CharacterSet.letters.contains(s) && s.isASCII { rest += 1 }
        }
        return deva > 0 && deva >= 2 * rest
    }

    static func devaToTelugu(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for s in text.unicodeScalars {
            if let special = devaToTeSpecial[Character(s)] {
                out.append(contentsOf: special.unicodeScalars)
            } else if isDeva(s), let t = Unicode.Scalar(s.value + offset) {
                out.append(t)
            } else {
                out.append(s)
            }
        }
        return String(out)
    }

    /// Telugu script to Devanagari. Telugu short ఎ/ఒ become Sanskrit ए/ओ unless `keepShort`.
    static func teluguToDeva(_ text: String, keepShort: Bool = false) -> String {
        let longForms: [Unicode.Scalar: Unicode.Scalar] = ["ఎ": "ए", "ఒ": "ओ", "\u{0C46}": "े", "\u{0C4A}": "ो"]
        var out = String.UnicodeScalarView()
        for s in text.precomposedStringWithCanonicalMapping.unicodeScalars {
            if !keepShort, let long = longForms[s] {
                out.append(long)
            } else if s == "\u{0C48}" {
                out.append("\u{0948}")
            } else if s == "ౘ" {
                out.append("च")
            } else if s == "ౙ" {
                out.append("ज")
            } else if isTelugu(s), let d = Unicode.Scalar(s.value - offset) {
                out.append(d)
            } else {
                out.append(s)
            }
        }
        return String(out)
    }

    static func devaToIast(_ text: String) -> String {
        let chars = Array(text.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
            .unicodeScalars.map(Character.init))
        var out = ""
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if let c = consonants[ch] {
                out += c
                var j = i + 1
                while j < chars.count && chars[j] == "\u{093C}" { j += 1 }
                let next: Character? = j < chars.count ? chars[j] : nil
                if next == "्" {
                    i = j + 1
                    continue
                }
                if let n = next, let sign = signs[n] {
                    out += sign
                    i = j + 1
                    continue
                }
                out += "a"
                i = j
                continue
            }
            if let v = vowels[ch] {
                out += v
            } else if let s = signs[ch] {
                out += s
            } else if let o = other[ch] {
                out += o
            } else if let scalar = ch.unicodeScalars.first, (0x0966...0x096F).contains(scalar.value) {
                out += String(scalar.value - 0x0966)
            } else {
                out.append(ch)
            }
            i += 1
        }
        return out
    }

    private static let iastVowels: [(String, String, String)] = [
        ("ai", "ऐ", "ै"), ("au", "औ", "ौ"), ("ā", "आ", "ा"), ("ī", "ई", "ी"), ("ū", "ऊ", "ू"),
        ("ṝ", "ॠ", "ॄ"), ("ṛ", "ऋ", "ृ"), ("ḹ", "ॡ", "ॣ"), ("ḷ", "ऌ", "ॢ"), ("ĕ", "ऎ", "ॆ"), ("ŏ", "ऒ", "ॊ"),
        ("a", "अ", ""), ("i", "इ", "ि"), ("u", "उ", "ु"), ("e", "ए", "े"), ("o", "ओ", "ो"),
    ]
    private static let iastConsonants: [(String, String)] = consonants
        .map { (String($0.value), String($0.key)) }
        .sorted { $0.0.unicodeScalars.count > $1.0.unicodeScalars.count }
    private static let iastOther: [(String, String)] = [
        ("m̐", "ँ"), ("ṃ", "ं"), ("ṁ", "ं"), ("ḥ", "ः"), ("||", "॥"), ("|", "।"), ("'", "ऽ"), ("’", "ऽ"),
    ]

    static func iastToDeva(_ text: String) -> String {
        let s = Array(text.precomposedStringWithCanonicalMapping.lowercased().unicodeScalars)
        var out = ""
        var pending = false
        var i = 0
        func matches(_ token: String) -> Bool {
            let t = Array(token.unicodeScalars)
            return i + t.count <= s.count && Array(s[i..<i + t.count]) == t
        }
        while i < s.count {
            if let (r, d) = iastConsonants.first(where: { matches($0.0) }) {
                if pending { out += "्" }
                out += d
                pending = true
                i += r.unicodeScalars.count
                continue
            }
            if let (r, full, sign) = iastVowels.first(where: { matches($0.0) }) {
                out += pending ? sign : full
                pending = false
                i += r.unicodeScalars.count
                continue
            }
            if pending { out += "्" }
            pending = false
            if let (r, d) = iastOther.first(where: { matches($0.0) }) {
                out += d
                i += r.unicodeScalars.count
                continue
            }
            let scalar = s[i]
            if let digit = Int(String(scalar)), let d = Unicode.Scalar(0x0966 + UInt32(digit)) {
                out.unicodeScalars.append(d)
            } else {
                out.unicodeScalars.append(scalar)
            }
            i += 1
        }
        if pending { out += "्" }
        return out
    }

    static func detect(_ text: String) -> Script? {
        var te = 0, deva = 0, latin = 0
        let iastLetters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzāīūṛṝḷḹṃṁḥṅñṭḍṇśṣ")
        for s in text.lowercased().unicodeScalars {
            if isTelugu(s) { te += 1 } else if isDeva(s) { deva += 1 } else if iastLetters.contains(s) { latin += 1 }
        }
        if te == 0 && deva == 0 && latin == 0 { return nil }
        if te >= deva && te >= latin { return .te }
        return deva >= latin ? .deva : .iast
    }

    static func toDeva(_ text: String, from: Script?, keepShort: Bool = false) -> String {
        switch from {
        case .te: teluguToDeva(text, keepShort: keepShort)
        case .iast: iastToDeva(text)
        default: text
        }
    }
}

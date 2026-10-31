import SwiftUI

/// How Sanskrit is shown: the chosen script, optional second-script and IAST lines, text size.
struct ScriptPrefs {
    var telugu = true
    var secondary = true
    var iast = false
    var scale = 1.0

    /// Text in the chosen script. `[[…]]` marks text that stays as written.
    func st(_ text: String, lit: Bool = false) -> String {
        if lit { return text.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "") }
        var out = ""
        var rest = Substring(text)
        while let open = rest.range(of: "[["), let close = rest.range(of: "]]", range: open.upperBound..<rest.endIndex) {
            out += convert(String(rest[..<open.lowerBound]))
            out += rest[open.upperBound..<close.lowerBound]
            rest = rest[close.upperBound...]
        }
        return out + convert(String(rest))
    }

    private func convert(_ s: String) -> String { telugu ? Lipi.devaToTelugu(s) : s }

    /// The script the reader did not choose.
    func other(_ text: String) -> String {
        let plain = text.replacingOccurrences(of: "[[", with: "").replacingOccurrences(of: "]]", with: "")
        return telugu ? plain : Lipi.devaToTelugu(plain)
    }

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight)
    }
}

private struct ScriptPrefsKey: EnvironmentKey {
    static let defaultValue = ScriptPrefs()
}

extension EnvironmentValues {
    var script: ScriptPrefs {
        get { self[ScriptPrefsKey.self] }
        set { self[ScriptPrefsKey.self] = newValue }
    }
}

/// **bold**, *italic* and `code`.
func md(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
}

func plain(_ text: String) -> String {
    text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "*", with: "")
        .replacingOccurrences(of: "`", with: "")
}

/// Prose or a table cell in the chosen script, with second-script and IAST lines when the
/// text is mainly Sanskrit.
struct CellText: View {
    @Environment(\.script) private var script
    let text: String
    var iast: String?
    var lit = false
    var size: CGFloat = 15
    var weight: Font.Weight = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(md(script.st(text, lit: lit))).font(script.font(size, weight))
            if !lit && Lipi.mostlySanskrit(text) {
                if script.secondary {
                    Text(script.other(text)).font(script.font(size * 0.82)).foregroundStyle(.secondary)
                }
                if script.iast {
                    Text(iast ?? Lipi.devaToIast(text)).font(script.font(size * 0.8).italic()).foregroundStyle(.secondary)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Verse or sentence lines: the chosen script large, then the other script and IAST.
struct SanskritLines: View {
    @Environment(\.script) private var script
    let lines: [String]
    var iast: [String]?
    var size: CGFloat = 21
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            VStack(alignment: alignment, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(script.st(line)).font(script.font(size, .semibold))
                }
            }
            if script.secondary {
                VStack(alignment: alignment, spacing: 1) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(script.other(line)).font(script.font(size * 0.72)).foregroundStyle(.secondary)
                    }
                }
            }
            if script.iast {
                VStack(alignment: alignment, spacing: 1) {
                    ForEach(Array((iast ?? lines.map(Lipi.devaToIast)).enumerated()), id: \.offset) { _, line in
                        Text(line).font(script.font(size * 0.68).italic()).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .multilineTextAlignment(alignment == .center ? .center : .leading)
        .textSelection(.enabled)
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

extension Color {
    static let saffron = Color(red: 0.91, green: 0.39, blue: 0.10)
}

import SwiftUI

/// Type Telugu, Devanagari or IAST and see all three; tap a letter in the chart to insert it.
struct LipiView: View {
    @Environment(\.script) private var script
    @AppStorage("lipiText") private var text = "రామః వనం గచ్ఛతి"
    @AppStorage("lipiLong") private var longVowels = true

    private static let vowels = ["अ", "आ", "इ", "ई", "उ", "ऊ", "ऋ", "ॠ", "ऌ", "ए", "ऐ", "ओ", "औ", "अं", "अः"]
    private static let consonants = [
        ["क", "ख", "ग", "घ", "ङ"], ["च", "छ", "ज", "झ", "ञ"], ["ट", "ठ", "ड", "ढ", "ण"],
        ["त", "थ", "द", "ध", "न"], ["प", "फ", "ब", "भ", "म"], ["य", "र", "ल", "व"], ["श", "ष", "स", "ह", "ळ"],
        ["क्ष", "ज्ञ", "त्र", "श्र"],
    ]

    var body: some View {
        let from = Lipi.detect(text)
        let deva = Lipi.toDeva(text, from: from, keepShort: !longVowels)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("లిపి · Script converter").font(.title.bold())
                Text("Type in Telugu, Devanagari or IAST (rāmaḥ). The other scripts appear below.")
                    .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.system(size: 20))
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.3)))
                HStack {
                    Text(from.map { "Detected: " + ["te": "Telugu", "deva": "Devanagari", "iast": "IAST"][$0.rawValue]! } ?? "")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("Telugu ఎ ఒ ె ొ become Sanskrit ए ओ", isOn: $longVowels)
                    Button("Clear") { text = "" }
                }
                output("తెలుగు", Lipi.devaToTelugu(deva), size: 24)
                output("देवनागरी", deva, size: 24)
                output("IAST", Lipi.devaToIast(deva), size: 18)
                Text("అక్షరమాల · tap to insert").font(.headline).padding(.top, 8)
                chartRow(Self.vowels)
                ForEach(Array(Self.consonants.enumerated()), id: \.offset) { _, row in chartRow(row) }
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func output(_ title: String, _ value: String, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption.bold()).foregroundStyle(Color.saffron)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).help("Copy")
            }
            Text(value.isEmpty ? " " : value).font(.system(size: size)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
    }

    private func chartRow(_ letters: [String]) -> some View {
        HStack(spacing: 6) {
            ForEach(letters, id: \.self) { letter in
                let shown = script.telugu ? Lipi.devaToTelugu(letter) : letter
                Button { text += shown } label: {
                    VStack(spacing: 0) {
                        Text(shown).font(.system(size: 20))
                        Text(script.telugu ? letter : Lipi.devaToTelugu(letter)).font(.system(size: 11)).foregroundStyle(.secondary)
                        Text(Lipi.devaToIast(letter)).font(.system(size: 10).italic()).foregroundStyle(.secondary)
                    }
                    .frame(width: 52, height: 60)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

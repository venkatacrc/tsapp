import SwiftUI

struct LessonView: View {
    @Environment(\.script) private var script
    @EnvironmentObject private var progress: ProgressStore
    let lesson: Lesson
    let unit: CourseUnit?
    let cardCount: Int
    let onPractise: () -> Void
    let onQuiz: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: 0).id("top")
                    Text("\(lesson.num) · \(plain(script.st(unit?.title ?? "")))")
                        .font(script.font(12, .semibold)).foregroundStyle(.secondary)
                    Text(md(script.st(lesson.title))).font(script.font(26, .bold))
                    if !lesson.summary.isEmpty {
                        Text(md(script.st(lesson.summary))).font(script.font(15)).foregroundStyle(.secondary)
                    }
                    ForEach(Array(lesson.blocks.enumerated()), id: \.offset) { _, block in
                        BlockView(block: block)
                    }
                    footer.padding(.top, 20)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: 860, alignment: .leading)
                .frame(maxWidth: .infinity)
                .textSelection(.enabled)
            }
            .onChange(of: lesson.id) { proxy.scrollTo("top", anchor: .top) }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button { progress.toggleDone(lesson.id) } label: {
                Label(progress.done.contains(lesson.id) ? "Completed" : "Mark complete",
                      systemImage: progress.done.contains(lesson.id) ? "checkmark.circle.fill" : "checkmark.circle")
            }
            if cardCount > 0 {
                Button(action: onPractise) { Label("Practise \(cardCount) cards", systemImage: "rectangle.stack") }
            }
            if !lesson.quiz.isEmpty {
                Button(action: onQuiz) { Label("Quiz (\(lesson.quiz.count))", systemImage: "questionmark.circle") }
                    .buttonStyle(.borderedProminent)
            }
            if let best = progress.quizBest[lesson.id] {
                Text("Best quiz score \(best)%").foregroundStyle(.secondary)
            }
        }
        .controlSize(.large)
    }
}

struct BlockView: View {
    @Environment(\.script) private var script
    let block: Block

    var body: some View {
        switch block.t {
        case "h2":
            VStack(alignment: .leading, spacing: 4) {
                Text(md(script.st(block.text ?? ""))).font(script.font(20, .bold))
                Rectangle().fill(Color.saffron.opacity(0.35)).frame(height: 2)
            }
            .padding(.top, 16)
        case "h3":
            Text(md(script.st(block.text ?? ""))).font(script.font(17, .semibold)).foregroundStyle(Color.saffron)
                .padding(.top, 8)
        case "p":
            Text(md(script.st(block.text ?? "", lit: block.literal))).font(script.font(15)).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        case "ul", "ol":
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { i, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(block.t == "ol" ? "\(i + 1)." : "•").font(script.font(15)).foregroundStyle(.secondary)
                        Text(md(script.st(item, lit: block.literal))).font(script.font(15)).lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case "table":
            TableBlockView(block: block)
        case "tip":
            TipView(block: block)
        case "ex":
            ExampleView(block: block)
        default:
            EmptyView()
        }
    }
}

struct TableBlockView: View {
    @Environment(\.script) private var script
    let block: Block

    var body: some View {
        let head = block.head ?? []
        let rows = block.rows ?? []
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .topLeading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    ForEach(Array(head.enumerated()), id: \.offset) { _, h in
                        Text(md(script.st(h, lit: block.literal))).font(script.font(12, .bold)).foregroundStyle(.secondary)
                    }
                }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { r, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { k, cell in
                            CellText(text: cell, iast: block.iast?[safe: r]?[safe: k] ?? nil, lit: block.literal,
                                     weight: k == 0 ? .semibold : .regular)
                                .frame(maxWidth: 340, alignment: .leading)
                        }
                    }
                    if r < rows.count - 1 { Divider() }
                }
            }
            .padding(14)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.2)))
    }
}

struct TipView: View {
    @Environment(\.script) private var script
    let block: Block

    private var style: (String, Color) {
        switch block.kind {
        case "memory": ("🧠 జ్ఞాపకం", .purple)
        case "telugu": ("అ తెలుగులో", .saffron)
        case "compare": ("⇄ పోలిక", .blue)
        case "sutra": ("📜 సూత్రం", .brown)
        case "warning": ("⚠ జాగ్రత్త", .red)
        default: ("ℹ︎ గమనిక", .secondary)
        }
    }

    var body: some View {
        let (label, color) = style
        HStack(spacing: 0) {
            Rectangle().fill(color).frame(width: 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(label).font(script.font(11, .bold)).foregroundStyle(color)
                    if let title = block.title, !title.isEmpty {
                        Text(md(script.st(title, lit: block.literal))).font(script.font(15, .bold))
                    }
                }
                ForEach(Array((block.paragraphs ?? []).enumerated()), id: \.offset) { _, p in
                    Text(md(script.st(p, lit: block.literal))).font(script.font(15)).lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .textBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ExampleView: View {
    @Environment(\.script) private var script
    @EnvironmentObject private var speech: Speech
    @AppStorage("voice") private var voice = "hi"
    let block: Block

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(md(script.st(block.src ?? block.title ?? "ఉదాహరణ · Example")))
                    .font(script.font(13, .bold)).foregroundStyle(Color.saffron)
                if let meter = block.meter {
                    Text(script.st(meter)).font(script.font(12)).foregroundStyle(.secondary)
                }
                Spacer()
                if speech.available {
                    Button { speech.speak(block.sa ?? []) } label: { Label("Read aloud", systemImage: "speaker.wave.2") }
                        .buttonStyle(.borderless)
                        .help("Read aloud with the \(speech.voiceName) voice")
                }
            }
            if let speaker = block.speaker {
                Text(script.st(speaker)).font(script.font(13)).foregroundStyle(Color.saffron)
            }
            SanskritLines(lines: block.sa ?? [], iast: block.saIast)
            if let split = block.split { part("పదచ్ఛేదం · word split") { CellText(text: split, iast: block.splitIast) } }
            if let anvaya = block.anvaya { part("అన్వయం · prose order") { CellText(text: anvaya, iast: block.anvayaIast) } }
            if let words = block.words, !words.isEmpty {
                part("ప్రతిపదార్థం · word by word") {
                    Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 4) {
                        ForEach(Array(words.enumerated()), id: \.offset) { _, w in
                            GridRow {
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(script.st(w[safe: 0] ?? "")).font(script.font(15, .semibold))
                                    if script.iast, let i = w[safe: 2], !i.isEmpty {
                                        Text(i).font(script.font(11).italic()).foregroundStyle(.secondary)
                                    }
                                }
                                Text(md(script.st(w[safe: 1] ?? ""))).font(script.font(15))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            if let te = block.te, !te.isEmpty { part("తాత్పర్యం · Telugu") { Text(md(script.st(te))).font(script.font(15)) } }
            if let en = block.en, !en.isEmpty { part("English") { Text(md(script.st(en))).font(script.font(15)) } }
            if let notes = block.notes, !notes.isEmpty {
                part("వ్యాకరణం · grammar") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(notes.enumerated()), id: \.offset) { _, n in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•").foregroundStyle(.secondary)
                                Text(md(script.st(n))).font(script.font(14)).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.saffron.opacity(0.35)))
    }

    private func part<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(script.font(10, .bold)).foregroundStyle(Color.saffron)
            content()
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

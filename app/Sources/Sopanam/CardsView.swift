import SwiftUI

struct CardsView: View {
    @Environment(\.script) private var script
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var course: CourseStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if session.deckFinished {
                summary
            } else if let card = session.card {
                ScrollView {
                    cardBody(card)
                        .frame(maxWidth: 720)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                }
                Divider()
                controls(card)
            } else {
                empty
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Picker("", selection: $session.study) {
                ForEach(StudyMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
            Spacer()
            if !session.deck.isEmpty && !session.deckFinished {
                Text("Card \(session.pos + 1) of \(session.deck.count)").font(.callout.weight(.semibold))
                if session.study == .test {
                    let answered = session.answers.count
                    let correct = session.answers.values.filter { $0 }.count
                    Text("Score \(correct) of \(answered) · \(session.deck.count - answered) to go").foregroundStyle(.secondary)
                } else {
                    let due = session.deck.filter { progress.isDue($0.id) }.count
                    Text("\(session.filter.title) · \(due) due").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func cardBody(_ card: Card) -> some View {
        let lesson = course.lessonByID[card.lesson]
        let showAnswer = session.study == .learn || session.flipped
        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text("\(lesson?.num ?? "") · \(plain(script.st(lesson?.title ?? "")))")
                    .font(script.font(12, .semibold)).foregroundStyle(.secondary)
                switch progress.state(card.id) {
                case .new: Badge(text: "New", color: .blue)
                case .known: Badge(text: "Known", color: .green)
                case .review: Badge(text: "Review", color: .orange)
                case .learning: EmptyView()
                }
            }
            if !card.context.isEmpty {
                Text(md(script.st(card.context))).font(script.font(13)).foregroundStyle(.secondary)
            }
            VStack(alignment: .center, spacing: 8) {
                if !card.prompt.head.isEmpty {
                    Text(md(script.st(card.prompt.head, lit: card.literal))).font(script.font(12, .bold))
                        .foregroundStyle(Color.saffron)
                }
                if card.kind == "example" {
                    SanskritLines(lines: card.prompt.text.components(separatedBy: " / "),
                                  iast: card.prompt.iast?.components(separatedBy: " / "), size: 22, alignment: .center)
                } else {
                    CellText(text: card.prompt.text, iast: card.prompt.iast, lit: card.literal,
                             size: card.prompt.text.count > 40 ? 20 : 30, weight: .semibold)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            if showAnswer {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(card.answer.enumerated()), id: \.offset) { _, a in
                        VStack(alignment: .leading, spacing: 3) {
                            if !a.head.isEmpty {
                                Text(md(script.st(a.head, lit: card.literal))).font(script.font(11, .bold))
                                    .foregroundStyle(Color.saffron)
                            }
                            CellText(text: a.text, iast: a.iast, lit: card.literal, size: 16)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Recall the answer, then press Space")
                    .foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(nsColor: .textBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.saffron.opacity(0.3)))
        .contentShape(Rectangle())
        .onTapGesture { session.reveal() }
        .textSelection(.enabled)
    }

    private func controls(_ card: Card) -> some View {
        HStack(spacing: 12) {
            Button { session.moveCard(-1) } label: { Image(systemName: "chevron.left") }
                .keyboardShortcut(.leftArrow, modifiers: [])
            Spacer()
            if session.study == .test {
                if session.flipped {
                    Button { session.answer(false) } label: { Label("Missed", systemImage: "xmark") }
                        .keyboardShortcut("n", modifiers: [])
                    Button { session.answer(true) } label: { Label("Got it", systemImage: "checkmark") }
                        .keyboardShortcut("y", modifiers: [])
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Show answer") { session.reveal() }
                        .keyboardShortcut(.space, modifiers: [])
                        .buttonStyle(.borderedProminent)
                }
            } else {
                let state = progress.state(card.id)
                Button { progress.toggleReview(card.id) } label: {
                    Label("Review", systemImage: state == .review ? "flag.fill" : "flag")
                }
                .keyboardShortcut("r", modifiers: [])
                Button { progress.toggleKnown(card.id) } label: {
                    Label("Known", systemImage: state == .known ? "checkmark.seal.fill" : "checkmark.seal")
                }
                .keyboardShortcut("k", modifiers: [])
            }
            Spacer()
            Button { session.moveCard(1) } label: { Image(systemName: "chevron.right") }
                .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .controlSize(.large)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No cards to practise", systemImage: "rectangle.stack")
        } description: {
            switch session.filter {
            case .due: Text("Nothing is due today. Well done! Practise new cards, or come back tomorrow.")
            case .review: Text("No cards are marked for review in the chosen lessons.")
            case .new: Text("You have seen every card in the chosen lessons.")
            case .all: Text("Tick some lessons in the sidebar.")
            }
        }
    }

    private var summary: some View {
        let correct = session.answers.values.filter { $0 }.count
        let missed = session.deck.filter { session.answers[$0.id] == false }
        let total = session.deck.count
        return VStack(spacing: 14) {
            Text(missed.isEmpty ? "⭐" : "✅").font(.system(size: 54))
            Text("Test complete").font(.title.bold())
            Text("\(correct) of \(total) correct (\(total > 0 ? correct * 100 / total : 0)%)").font(.title3)
            Text(missed.isEmpty ? "Every card moves up a box and comes back after a longer gap."
                 : "Cards you got come back after longer gaps; the \(missed.count) you missed come back tomorrow.")
                .foregroundStyle(.secondary)
            HStack {
                if !missed.isEmpty {
                    Button("Retest the \(missed.count) missed") { session.startDeck(missed.shuffled()) }
                        .buttonStyle(.borderedProminent)
                }
                Button("Start again") { session.restartCards() }
                Button("Switch to Learn") { session.study = .learn }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

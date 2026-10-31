import SwiftUI

struct QuizView: View {
    @Environment(\.script) private var script
    @EnvironmentObject private var session: Session
    @EnvironmentObject private var course: CourseStore

    var body: some View {
        if !session.quizActive {
            start
        } else if session.quizFinished {
            summary
        } else if let q = session.question {
            question(q)
        }
    }

    private var start: some View {
        let ids = session.selectedLessons
        let count = course.lessons.filter { ids.contains($0.id) }.reduce(0) { $0 + $1.quiz.count }
        return VStack(spacing: 16) {
            Text("Quiz").font(.largeTitle.bold())
            Text("\(count) questions in the \(ids.count) lesson\(ids.count == 1 ? "" : "s") ticked in the sidebar. Each lesson also has its own quiz at the end of the lesson.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 460)
            Picker("Questions per quiz", selection: $session.quizCount) {
                ForEach([5, 10, 20, 40], id: \.self) { Text("\($0)").tag($0) }
            }
            .frame(width: 240)
            Button("Start quiz") { session.startQuiz() }
                .buttonStyle(.borderedProminent).controlSize(.large).disabled(count == 0)
                .keyboardShortcut(.return, modifiers: [])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func question(_ q: Session.Question) -> some View {
        let lesson = course.lessonByID[q.lesson]
        let answered = session.chosenOption != nil
        return VStack(spacing: 0) {
            HStack {
                Text("Question \(session.qpos + 1) of \(session.questions.count)").font(.callout.weight(.semibold))
                Spacer()
                Text("Score \(session.results.filter { $0 }.count) of \(session.results.count)").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(lesson?.num ?? "") · \(plain(script.st(lesson?.title ?? "")))")
                        .font(script.font(12, .semibold)).foregroundStyle(.secondary)
                    Text(md(script.st(q.item.q))).font(script.font(20, .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(q.order.enumerated()), id: \.offset) { k, option in
                        optionButton(q, k: k, option: option, answered: answered)
                    }
                    if let chosen = session.chosenOption {
                        (Text(chosen == q.item.answer ? "✓ Correct. " : "✗ Not quite. ").bold()
                         + Text(md(script.st(q.item.why))))
                            .font(script.font(15))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill((chosen == q.item.answer ? Color.green : Color.orange).opacity(0.12)))
                    }
                }
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(24)
                .textSelection(.enabled)
            }
            Divider()
            HStack {
                Spacer()
                Button(session.qpos == session.questions.count - 1 ? "Finish" : "Next question") { session.nextQuestion() }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(!answered)
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
    }

    private func optionButton(_ q: Session.Question, k: Int, option: Int, answered: Bool) -> some View {
        let isRight = answered && option == q.item.answer
        let isWrong = answered && option == session.chosenOption && !isRight
        return Button { session.choose(option) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(k + 1).").bold().foregroundStyle(.secondary)
                Text(md(script.st(q.item.options[option]))).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if isRight { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if isWrong { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
            }
            .font(script.font(16))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(isRight ? Color.green.opacity(0.15) : isWrong ? Color.red.opacity(0.15) : Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.25)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(answered)
        .keyboardShortcut(KeyEquivalent(Character(String(k + 1))), modifiers: [])
    }

    private var summary: some View {
        let correct = session.results.filter { $0 }.count
        let total = session.questions.count
        let missed = total - correct
        return VStack(spacing: 14) {
            Text(missed == 0 ? "⭐" : "✅").font(.system(size: 54))
            Text("Quiz complete").font(.title.bold())
            Text("\(correct) of \(total) correct (\(total > 0 ? correct * 100 / total : 0)%)").font(.title3)
            HStack {
                if missed > 0 {
                    Button("Retry the \(missed) missed") { session.retryMissed() }.buttonStyle(.borderedProminent)
                }
                Button("New quiz") { session.startQuiz(scope: session.quizScope) }
                if let scope = session.quizScope {
                    Button("Back to the lesson") {
                        session.lessonID = scope
                        session.quizActive = false
                        session.mode = .lessons
                    }
                }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

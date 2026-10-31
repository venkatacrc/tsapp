import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var course: CourseStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var session: Session
    @AppStorage("primary") private var primary = "te"
    @AppStorage("secondary") private var secondary = true
    @AppStorage("iast") private var iast = false
    @AppStorage("scale") private var scale = 1.0

    private var prefs: ScriptPrefs {
        ScriptPrefs(telugu: primary == "te", secondary: secondary, iast: iast, scale: scale)
    }

    var body: some View {
        NavigationSplitView {
            Sidebar()
                .navigationSplitViewColumnWidth(min: 260, ideal: 310, max: 420)
        } detail: {
            detail
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Picker("Mode", selection: $session.mode) {
                            ForEach(Mode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 320)
                    }
                }
        }
        .environment(\.script, prefs)
        .navigationTitle("సంస్కృత సోపానం")
        .alert("Course", isPresented: Binding(get: { course.errorMessage != nil }, set: { if !$0 { course.errorMessage = nil } })) {
            Button("OK") {}
        } message: {
            Text(course.errorMessage ?? "")
        }
        .onAppear { session.attach(course: course, progress: progress) }
    }

    @ViewBuilder private var detail: some View {
        switch session.mode {
        case .lessons:
            if let id = session.lessonID, let lesson = course.lessonByID[id] {
                LessonView(lesson: lesson, unit: course.unitByLesson[id], cardCount: course.cardsByLesson[id]?.count ?? 0,
                           onPractise: { session.practise(lesson: id) },
                           onQuiz: { session.startQuiz(scope: id) })
            } else {
                ContentUnavailableView("Choose a lesson", systemImage: "book")
            }
        case .cards: CardsView()
        case .quiz: QuizView()
        case .lipi: LipiView()
        }
    }
}

struct Sidebar: View {
    @Environment(\.script) private var script
    @EnvironmentObject private var course: CourseStore
    @EnvironmentObject private var progress: ProgressStore
    @EnvironmentObject private var session: Session

    var body: some View {
        switch session.mode {
        case .lessons, .lipi: lessonList
        case .cards, .quiz: chooser
        }
    }

    private var lessonList: some View {
        List(selection: Binding(get: { session.lessonID }, set: { id in
            session.lessonID = id
            session.mode = .lessons
        })) {
            ForEach(course.course.units) { unit in
                Section {
                    ForEach(unit.lessons) { lesson in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(lesson.num).font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
                            Text(plain(script.st(lesson.title))).lineLimit(2)
                            Spacer()
                            if let best = progress.quizBest[lesson.id] {
                                Text("\(best)%").font(.caption2).foregroundStyle(.secondary)
                            }
                            if progress.done.contains(lesson.id) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                        }
                        .tag(lesson.id)
                    }
                } header: {
                    Text("\(unit.num). \(plain(script.st(unit.title)))")
                }
            }
        }
    }

    private var chooser: some View {
        let selected = session.selectedLessons
        return VStack(spacing: 0) {
            List {
                Section {
                    Picker("Show", selection: $session.filter) {
                        ForEach(CardFilter.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Shuffle", isOn: $session.shuffle)
                    HStack {
                        Button("All") { session.setChosen(course.lessons.map(\.id), on: true) }
                        Button("None") { session.setChosen(course.lessons.map(\.id), on: false) }
                    }
                }
                ForEach(course.course.units) { unit in
                    Section {
                        ForEach(unit.lessons) { lesson in
                            Toggle(isOn: Binding(get: { selected.contains(lesson.id) },
                                                 set: { session.setChosen([lesson.id], on: $0) })) {
                                HStack {
                                    Text("\(lesson.num) \(plain(script.st(lesson.title)))").lineLimit(2)
                                    Spacer()
                                    Text(session.mode == .quiz ? "\(lesson.quiz.count) q" : "\(course.cardsByLesson[lesson.id]?.count ?? 0)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        let ids = unit.lessons.map(\.id)
                        Toggle(isOn: Binding(get: { ids.allSatisfy(selected.contains) },
                                             set: { session.setChosen(ids, on: $0) })) {
                            Text("\(unit.num). \(plain(script.st(unit.title)))")
                        }
                    }
                }
            }
            Divider()
            HStack {
                let cards = course.course.cards.filter { selected.contains($0.lesson) }
                Text("\(cards.count) cards · \(cards.filter { progress.isDue($0.id) }.count) due")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(10)
        }
    }
}

struct SettingsView: View {
    @AppStorage("primary") private var primary = "te"
    @AppStorage("secondary") private var secondary = true
    @AppStorage("iast") private var iast = false
    @AppStorage("scale") private var scale = 1.0
    @AppStorage("voice") private var voice = "hi"
    @EnvironmentObject private var progress: ProgressStore

    var body: some View {
        Form {
            Picker("Show Sanskrit in", selection: $primary) {
                Text("తెలుగు లిపి (Telugu script)").tag("te")
                Text("देवनागरी (Devanagari)").tag("deva")
            }
            .pickerStyle(.radioGroup)
            Toggle("Also show the other script", isOn: $secondary)
            Toggle("Show IAST (rāmaḥ)", isOn: $iast)
            Picker("Read aloud", selection: $voice) {
                Text("Hindi voice (Devanagari)").tag("hi")
                Text("Telugu voice (Telugu script)").tag("te")
                Text("Off").tag("off")
            }
            .pickerStyle(.radioGroup)
            Slider(value: $scale, in: 0.85...1.5, step: 0.05) { Text("Text size") }
            HStack {
                Button("Export progress…") { progress.exportProgress() }
                Button("Import progress…") { progress.importProgress() }
                Button("Reset progress…", role: .destructive) { progress.reset() }
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}

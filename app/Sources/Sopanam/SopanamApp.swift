import AppKit
import SwiftUI

@main
struct SopanamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var course = CourseStore()
    @StateObject private var progress = ProgressStore()
    @StateObject private var session = Session()
    @StateObject private var speech = Speech()

    var body: some Scene {
        WindowGroup("సంస్కృత సోపానం") {
            ContentView()
                .environmentObject(course)
                .environmentObject(progress)
                .environmentObject(session)
                .environmentObject(speech)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 820)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Lessons") { session.mode = .lessons }.keyboardShortcut("1")
                Button("Cards") { session.mode = .cards }.keyboardShortcut("2")
                Button("Quiz") { session.mode = .quiz }.keyboardShortcut("3")
                Button("Script converter") { session.mode = .lipi }.keyboardShortcut("4")
                Divider()
                Button("Previous lesson") { session.stepLesson(-1) }.keyboardShortcut("[")
                Button("Next lesson") { session.stepLesson(1) }.keyboardShortcut("]")
            }
            CommandGroup(after: .importExport) {
                Button("Export Progress…") { progress.exportProgress() }
                Button("Import Progress…") { progress.importProgress() }
            }
        }

        Settings {
            SettingsView().environmentObject(progress)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

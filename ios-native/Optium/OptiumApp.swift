import SwiftData
import SwiftUI

@main
struct OptiumApp: App {
    @State private var settings: AppSettings
    @State private var timer: TimerEngine

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _timer = State(initialValue: TimerEngine(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(timer)
        }
        .modelContainer(for: [Project.self, ProjectTask.self, FocusSession.self])
    }
}

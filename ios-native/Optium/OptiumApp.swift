import SwiftData
import SwiftUI

@main
struct OptiumApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Project.self, ProjectTask.self, FocusSession.self])
    }
}

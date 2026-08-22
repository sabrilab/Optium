import SwiftData
import SwiftUI

@main
struct OptiumApp: App {
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
        }
        .modelContainer(for: [Project.self, WorkThread.self, Resumption.self])
    }
}

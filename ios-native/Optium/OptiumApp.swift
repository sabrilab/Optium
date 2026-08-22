import SwiftData
import SwiftUI

@main
struct OptiumApp: App {
    @State private var settings = AppSettings()
    @State private var clarity = ClarityStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(clarity)
        }
        .modelContainer(for: [Project.self, WorkThread.self, Resumption.self,
                              RecordedNight.self, CoffeeIntake.self])
    }
}

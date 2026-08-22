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
                #if DEBUG
                .task {
                    // Voir `DemoData` : DEBUG seulement, et sur argument
                    // explicite.
                    if DemoData.isRequested {
                        DemoData.seed(into: ModelContext(OptiumContainer.shared))
                    }
                }
                #endif

        }
        .modelContainer(OptiumContainer.shared)
    }
}

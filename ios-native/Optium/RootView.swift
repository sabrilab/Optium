import SwiftData
import SwiftUI

private extension RootView {
    func refresh() async {
        await clarity.refresh(context: context)
        await Notifications.schedule(
            window: clarity.reading.window,
            bedtime: clarity.reading.window.start.addingTimeInterval(13 * 3600),
            threadCount: openThreads.count
        )
    }
}

enum RootTab: Hashable {
    case home, journal
}

struct RootView: View {
    @Environment(ClarityStore.self) private var clarity
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<WorkThread> { $0.closedAt == nil })
    private var openThreads: [WorkThread]

    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Aujourd’hui", systemImage: "brain", value: RootTab.home) {
                HomeScreen(isVisible: selection == .home)
            }
            Tab("Où tu en es", systemImage: "chart.line.uptrend.xyaxis", value: RootTab.journal) {
                JournalScreen()
            }
        }
        // L'application ne suit pas l'apparence d'iOS : le noir est un choix de
        // direction artistique, et la scene comme les lavis n'existent que sur
        // lui.
        .preferredColorScheme(.dark)
        .tint(Ink.control)
        // La lecture de la clarte vit ici, et non dans un ecran : elle est
        // lue par les deux onglets et par l'appel. Laissee dans l'accueil,
        // elle ne tournait pas quand l'application s'ouvrait ailleurs.
        .task {
            await clarity.requestPermission()
            await refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refresh() }
        }
    }
}

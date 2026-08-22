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

        WidgetBridge.publish(
            reading: clarity.reading,
            threadPhrase: openThreads.first?.phrase,
            tier: clarity.reading.regularity.map(Tier.init(regularity:)),
            landing: landing
        )
    }

    /// L'atterrissage, calcule une fois et partage entre l'accueil, les
    /// widgets et la Live Activity.
    var landing: Landing? {
        let history = closedThreads.map(\.resumptions.count).filter { $0 > 0 }
        let activeDays = Set(allResumptions.map { Calendar.current.startOfDay(for: $0.startedAt) })
        let capacity = activeDays.isEmpty ? 0 : Double(allResumptions.count) / Double(activeDays.count)
        return LandingEstimator.estimate(
            closedResumptions: history, openThreads: openThreads.count,
            dailyCapacity: capacity, from: Date()
        )
    }
}

enum RootTab: Hashable {
    case home, journal
}

struct RootView: View {
    @Environment(ClarityStore.self) private var clarity
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<WorkThread> { $0.closedAt == nil })
    private var openThreads: [WorkThread]

    @Query(filter: #Predicate<WorkThread> { $0.closedAt != nil })
    private var closedThreads: [WorkThread]

    @Query private var allResumptions: [Resumption]

    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab("Aujourd’hui", systemImage: "brain", value: RootTab.home) {
                HomeScreen(isVisible: selection == .home)
            }
            Tab("Où tu en es", systemImage: "chart.line.uptrend.xyaxis", value: RootTab.journal) {
                JournalScreen(isVisible: selection == .journal)
            }
        }
        // L'application ne suit pas l'apparence d'iOS : le noir est un choix de
        // direction artistique, et la scene comme les lavis n'existent que sur
        // lui.
        .preferredColorScheme(.dark)
        // Le tactile et le son sont lus ici, une fois : les vues appellent
        // `Feedback.play` sans avoir a connaitre les reglages.
        .onAppear {
            Feedback.isEnabled = settings.hapticsEnabled
            Chime.isEnabled = settings.soundsEnabled
            Feedback.prepare()
        }
        // Le moteur redescend en veille tout seul ; on le releve a chaque
        // changement d'onglet pour que le premier geste sur l'ecran suivant
        // ne soit pas le seul a manquer.
        .onChange(of: selection) { _, _ in Feedback.prepare() }
        .onChange(of: settings.hapticsEnabled) { Feedback.isEnabled = $1 }
        .onChange(of: settings.soundsEnabled) { Chime.isEnabled = $1 }
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

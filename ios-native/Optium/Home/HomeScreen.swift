import SwiftData
import SwiftUI

/// L'unique écran permanent. Un mot, une fenêtre, les fils ouverts.
///
/// Pas de chiffre de performance, pas de graphe, pas de série. Le document est
/// explicite sur la raison : les applications de productivité meurent dans
/// leur onglet Statistiques.
struct HomeScreen: View {
    let isVisible: Bool

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        filter: #Predicate<WorkThread> { $0.closedAt == nil },
        sort: \WorkThread.createdAt
    )
    private var threads: [WorkThread]

    @State private var composing = false
    @State private var showSettings = false
    @State private var active: WorkThread?

    private var clarity: Clarity { settings.claritySource.current() }
    private var window: DateInterval { settings.claritySource.window(on: Date()) }

    /// Le plafond permis par la nuit. Simulé tant que le moteur n'existe pas :
    /// il se pose juste au-dessus du niveau courant.
    private var base: Double { min(1, Double(clarity.value) / 100 + 0.12) }

    /// L'agitation est le nombre de fils ouverts. Au-delà de cinq la surface
    /// est déjà pleinement remuée : compter plus loin n'ajoute rien à lire.
    private var agitation: Double { min(1, Double(threads.count) / 5) }

    var body: some View {
        NavigationStack {
            ZStack {
                InkBackground()

                Aura(isFocus: true, intensity: 0.35 + base * 0.4)
                    .frame(height: 560)
                    .offset(y: -180)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        brain
                        clarityCard
                        threadList
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle("Aujourd’hui")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Réglages", systemImage: "gearshape")
                    }
                    .tint(Ink.control)
                }
            }
            .sheet(isPresented: $composing) { ThreadComposer() }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsScreen() }
            }
            .fullScreenCover(item: $active) { thread in
                ResumptionFlow(thread: thread)
            }
            // Un fil retenu redevient ouvert de lui-même à l'échéance. On le
            // constate à l'ouverture de l'écran plutôt que par une minuterie :
            // rien ne presse, et rien ne doit notifier.
            .onAppear(perform: releaseDueThreads)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { releaseDueThreads() }
            }
        }
    }

    @ViewBuilder
    private var brain: some View {
        if settings.brainEnabled {
            BrainView(
                fill: Double(clarity.value) / 100,
                base: base,
                agitation: agitation,
                isDay: true,
                isVisible: isVisible && scenePhase == .active
            )
            .frame(height: 260)
        }
    }

    private var clarityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CLARTÉ")
                .font(.caption2.weight(.semibold))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            // Un mot, jamais un nombre. Un score chiffré de performance
            // cognitive s'approcherait d'un diagnostic.
            Text(clarity.level.word)
                .font(.system(size: 34, weight: .light))

            WindowStrip(window: window, now: Date())

            Text(windowSentence)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.indigo, corner: 34)
    }

    private var windowSentence: String {
        let now = Date()
        if now < window.start {
            return "Ta fenêtre s’ouvre à \(window.start.formatted(date: .omitted, time: .shortened))."
        }
        if window.contains(now) {
            return "Fenêtre ouverte jusqu’à \(window.end.formatted(date: .omitted, time: .shortened))."
        }
        return "Fenêtre fermée. Elle rouvre demain matin."
    }

    @ViewBuilder
    private var threadList: some View {
        VStack(spacing: 12) {
            ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                Button {
                    active = thread
                } label: {
                    ThreadRow(thread: thread, hue: Ink.cardHues[(index + 1) % Ink.cardHues.count])
                }
                .buttonStyle(.plain)
            }

            Button {
                composing = true
            } label: {
                Label("Ouvrir un fil", systemImage: "plus")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
        }
    }

    private func releaseDueThreads() {
        let now = Date()
        for thread in threads { thread.releaseIfDue(now: now) }
    }
}

/// Un fil dans la liste.
struct ThreadRow: View {
    let thread: WorkThread
    let hue: Ink.CardHue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(thread.nature.word.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                Spacer()
                if thread.state == .held, let until = thread.heldUntil {
                    Text("retenu jusqu’à \(until.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(Ink.marker)
                }
            }

            Text(thread.phrase)
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !thread.resumptions.isEmpty {
                Text("\(thread.resumptions.count) reprise\(thread.resumptions.count > 1 ? "s" : "")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .bentoSurface(hue, corner: 30, intensity: thread.state == .held ? 0.3 : 0.55)
    }
}

/// La fenêtre du jour, en graduations. Le repère marque l'instant présent.
struct WindowStrip: View {
    let window: DateInterval
    let now: Date

    private var progress: Double {
        guard window.duration > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(window.start) / window.duration))
    }

    var body: some View {
        TickScale(progress: progress)
    }
}

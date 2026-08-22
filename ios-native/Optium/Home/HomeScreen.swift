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
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(
        filter: #Predicate<WorkThread> { $0.closedAt == nil },
        sort: \WorkThread.createdAt
    )
    private var threads: [WorkThread]

    @Query(sort: \CoffeeIntake.takenAt, order: .reverse)
    private var coffees: [CoffeeIntake]

    @Query(filter: #Predicate<WorkThread> { $0.closedAt != nil })
    private var closed: [WorkThread]

    @Query private var allResumptions: [Resumption]

    @State private var composing = false
    @State private var showSettings = false
    @State private var calling = false
    @State private var active: WorkThread?

    /// La lecture mesurée, sauf si le forçage de développement l'écrase.
    private var reading: ClarityReading {
        if let forced = settings.clarityOverride {
            return .forced(forced, window: clarityStore.reading.window)
        }
        return clarityStore.reading
    }

    private var clarity: Clarity { reading.clarity }
    private var window: DateInterval { reading.window }

    /// Le plafond permis par la nuit : ce que la régularité autorise, quelle
    /// que soit la nuit d'hier. On ne peut pas rattraper en une nuit ce que
    /// vingt-huit ont défait.
    private var base: Double {
        guard let regularity = reading.regularity else { return 1 }
        return min(1, 0.45 + regularity / 100 * 0.55)
    }

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
                    VStack(spacing: 14) {
                        brain
                        clarityCard
                        CalibrationCard(measured: clarity.level)
                        landingCard
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        calling = true
                    } label: {
                        Label("Appeler", systemImage: "waveform")
                    }
                    .tint(Ink.control)
                }
            }
            .sheet(isPresented: $composing) { ThreadComposer() }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsScreen() }
            }
            .sheet(isPresented: $calling) { CallScreen() }
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
            //
            // Et tant que l'historique est trop court, on le dit plutôt que
            // d'annoncer un mot : un oracle qui a toujours une réponse ment
            // en permanence.
            Text(reading.isConfident ? clarity.level.word : "pas encore mesurable")
                .font(.system(size: reading.isConfident ? 34 : 24, weight: .light))
                .foregroundStyle(reading.isConfident ? .primary : .secondary)

            WindowStrip(window: window, now: Date())

            Text(windowSentence)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Divider().overlay(Color.white.opacity(0.12))

            coffeeRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .bentoSurface(Ink.indigo, corner: 34)
    }

    /// Le seul geste déclaratif de l'application. Tout le reste est lu.
    ///
    /// Il agit sur la nuit projetée, donc sur la clarté de **demain** — jamais
    /// sur celle d'aujourd'hui. C'est ce qui en fait un enseignement plutôt
    /// qu'une punition.
    private var coffeeRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Café")
                    .font(.subheadline)
                Text(coffeeSentence)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                context.insert(CoffeeIntake())
                Task { await clarityStore.refresh(context: context) }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .tint(Ink.control)
            .accessibilityLabel("Noter un café")
        }
    }

    private var coffeeSentence: String {
        let today = coffees.filter { Calendar.current.isDateInToday($0.takenAt) }
        if today.isEmpty { return "aucun aujourd’hui" }
        let penalty = reading.projectedNightPenalty
        let count = "\(today.count) aujourd’hui"
        guard penalty > 0.05 else { return count }
        return "\(count) · la nuit de ce soir en pâtira"
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

    /// L'atterrissage : le seul nombre de l'application, et toujours une
    /// fourchette. Elle se tait tant qu'il n'y a rien à extrapoler — inventer
    /// une date serait pire que se taire.
    @ViewBuilder
    private var landingCard: some View {
        if let landing = landing {
            VStack(alignment: .leading, spacing: 12) {
                Text("ATTERRISSAGE")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.6)
                    .foregroundStyle(.secondary)
                Text(range(landing))
                    .font(.system(size: 26, weight: .light))
                Text("Calculé sur tes fils passés, pas sur une estimation.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .bentoSurface(Ink.violet, corner: 30, intensity: 0.5)
        }
    }

    private var landing: Landing? {
        let history = closed.map(\.resumptions.count).filter { $0 > 0 }
        let activeDays = Set(allResumptions.map { Calendar.current.startOfDay(for: $0.startedAt) })
        let capacity = activeDays.isEmpty ? 0 : Double(allResumptions.count) / Double(activeDays.count)

        return LandingEstimator.estimate(
            closedResumptions: history,
            openThreads: threads.count,
            dailyCapacity: capacity,
            from: Date()
        )
    }

    private func range(_ landing: Landing) -> String {
        let format = Date.FormatStyle.dateTime.weekday(.abbreviated).day()
        return "\(landing.earliest.formatted(format)) → \(landing.latest.formatted(format))"
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
                if let project = thread.project {
                    Circle()
                        .fill(project.hue.tint)
                        .frame(width: 6, height: 6)
                    Text(project.title.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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

import SwiftData
import SwiftUI

struct SessionScreen: View {
    let selectedTab: RootTab

    @Environment(TimerEngine.self) private var timer
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query private var projects: [Project]
    @State private var showSettings = false
    @State private var location = LocationRecorder()
    @State private var finishedMode: TimerMode?

    private var activeTask: ProjectTask? {
        guard let id = timer.activeTaskID else { return nil }
        return projects.flatMap(\.tasks).first { $0.id == id }
    }

    var body: some View {
        ZStack {
            // La scene occupe le haut de l'ecran ; les panneaux de verre
            // flottent par dessus, comme les commandes du lecteur de Musique
            // sur la pochette d'album.
            sceneArea
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                header
                Spacer()
                controls
            }
            .padding(.horizontal, 16)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsScreen() }
        }
        // Un battement par seconde tant que l'ecran est visible. Il ne
        // decremente rien : il demande au moteur de recalculer depuis sa date
        // de depart.
        .task(id: timer.isRunning) {
            guard timer.isRunning else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                timer.refresh()
            }
        }
        // Le retour au premier plan doit rattraper la suspension sans attendre
        // le prochain battement.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { timer.refresh() }
        }
        // Fin de session : detectee des que le restant atteint zero, d'ou que
        // vienne le constat — battement d'affichage ou retour au premier plan.
        .onChange(of: timer.isFinished) { _, finished in
            guard finished else { return }
            let mode = timer.mode
            let recorded = SessionCompletion.record(
                timer: timer,
                settings: settings,
                context: context,
                tasks: projects.flatMap(\.tasks),
                coordinate: location.coordinate
            )
            guard recorded else { return }
            SessionCompletion.announce(settings: settings)
            finishedMode = mode
        }
        // La notification est (re)programmee au demarrage et a l'arret, jamais
        // a chaque seconde : la reprogrammer en boucle l'annulerait sans cesse.
        .task(id: timer.isRunning) {
            if let date = timer.finishesAt {
                await TimerNotifications.schedule(at: date, mode: timer.mode)
            } else {
                await TimerNotifications.cancel()
            }
        }
        .task(id: settings.locationEnabled) {
            await location.refresh(enabled: settings.locationEnabled)
        }
        .sheet(item: $finishedMode) { mode in
            CompletionSheet(mode: mode) {
                if mode == .focus { timer.switchToRest() } else { timer.switchToFocus() }
            }
        }
    }

    @ViewBuilder
    private var sceneArea: some View {
        if settings.brainEnabled {
            ZStack {
                SceneBackdrop(isFocus: timer.mode == .focus)
                    .ignoresSafeArea(edges: .top)
                BrainView(
                    // Le fluide suit le temps restant, pas le temps ecoule.
                    progress: timer.total == 0 ? 1 : Double(timer.remaining) / Double(timer.total),
                    isFocus: timer.mode == .focus,
                    isVisible: selectedTab == .session && scenePhase == .active
                )
            }
            .frame(maxHeight: .infinity)
            .padding(.bottom, 260)
        } else {
            Text("Visualisation désactivée")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack {
            Text(timer.mode.label)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .glassEffect(.clear)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Réglages")
        }
        // Ces commandes flottent sur la scene, pas sur le fond systeme : leur
        // contenu doit se lire clair quel que soit le mode de l'appareil.
        // C'est ce que fait Musique pour ses commandes posees sur la pochette.
        .environment(\.colorScheme, .dark)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if let task = activeTask {
                taskCard(task)
            }
            timerCard
        }
        .padding(.bottom, 16)
    }

    private func taskCard(_ task: ProjectTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.project?.name ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(task.title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 4) {
                ForEach(0..<task.estimatedPomodoros, id: \.self) { index in
                    Capsule()
                        .fill(index < task.completedPomodoros ? Color.accentColor : Color(.tertiarySystemFill))
                        .frame(height: 4)
                }
            }
            .padding(.top, 4)
            .accessibilityLabel(
                "\(task.completedPomodoros) sur \(task.estimatedPomodoros) sessions terminées"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var timerCard: some View {
        VStack(spacing: 0) {
            ProgressView(value: min(1, timer.progress))
                .tint(.primary)
                .frame(width: 220)
                .padding(.bottom, 20)

            Text(formatted(timer.remaining))
                .font(.system(size: 64, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(timer.remaining / 60) minutes restantes")

            Text(timer.mode == .focus
                 ? "Session · \(settings.focusMinutes) min"
                 : "Pause · \(settings.restMinutes) min")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
                .padding(.bottom, 20)

            Button {
                if timer.isRunning { timer.pause() } else { timer.start() }
            } label: {
                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .frame(width: 68, height: 68)
            }
            .buttonStyle(.glass)
            .accessibilityLabel(timer.isRunning ? "Mettre en pause" : "Démarrer")

            if timer.progress > 0 {
                Button("Terminer maintenant") { endEarly() }
                    .font(.callout)
                    .frame(minHeight: 44)
                    .padding(.top, 8)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    /// Une session interrompue compte pour le temps reellement passe, pas pour
    /// sa duree prevue.
    private func endEarly() {
        context.insert(FocusSession(
            durationSeconds: timer.elapsed,
            isFocus: timer.mode == .focus,
            projectID: timer.activeProjectID,
            taskID: timer.activeTaskID
        ))
        if timer.mode == .focus { timer.switchToRest() } else { timer.switchToFocus() }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

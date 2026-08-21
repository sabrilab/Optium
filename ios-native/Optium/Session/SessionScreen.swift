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

    private var isFocus: Bool { timer.mode == .focus }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Session")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Réglages", systemImage: "gearshape")
                        }
                    }
                }
        }
    }

    private var content: some View {
        ZStack {
            InkBackground()

            // L'aura est posee derriere le cerveau et remonte avec lui : c'est
            // elle qui donne au noir sa profondeur.
            Aura(isFocus: isFocus, intensity: 0.55 + timer.progress * 0.45)
                .frame(height: 620)
                .offset(y: -160)
                .ignoresSafeArea()

            sceneArea
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                Spacer()
                controls
            }
            .padding(.horizontal, 16)
        }
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
            BrainView(
                // Le fluide suit le temps restant, pas le temps ecoule.
                progress: timer.total == 0 ? 1 : Double(timer.remaining) / Double(timer.total),
                isFocus: isFocus,
                isVisible: selectedTab == .session && scenePhase == .active
            )
            .frame(maxHeight: .infinity)
            .padding(.bottom, 300)
        } else {
            Text("Visualisation désactivée")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxHeight: .infinity)
        }
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 14) {
                if let task = activeTask {
                    taskCard(task)
                }
                timerCard
            }
        }
        .padding(.bottom, 12)
    }

    private func taskCard(_ task: ProjectTask) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text((task.project?.name ?? "").uppercased())
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(.secondary)
            Text(task.title)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 5) {
                ForEach(0..<task.estimatedPomodoros, id: \.self) { index in
                    Capsule()
                        .fill(index < task.completedPomodoros
                              ? Ink.marker
                              : Color.white.opacity(0.16))
                        .frame(height: 3)
                }
            }
            .padding(.top, 6)
            .accessibilityLabel(
                "\(task.completedPomodoros) sur \(task.estimatedPomodoros) sessions terminées"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private var timerCard: some View {
        VStack(spacing: 0) {
            DotMatrixText(
                text: formatted(timer.remaining),
                color: .primary,
                glow: Ink.glow(isFocus: isFocus)
            )
            .padding(.bottom, 18)
            .accessibilityLabel("\(timer.remaining / 60) minutes restantes")

            TickScale(progress: min(1, timer.progress))
                .padding(.horizontal, 8)
                .padding(.bottom, 16)

            Text(isFocus
                 ? "SESSION · \(settings.focusMinutes) MIN"
                 : "PAUSE · \(settings.restMinutes) MIN")
                .font(.caption2.weight(.medium))
                .tracking(1.6)
                .foregroundStyle(.secondary)
                .padding(.bottom, 22)

            HStack(spacing: 12) {
                if timer.progress > 0 {
                    Button("Terminer") { endEarly() }
                        .font(.footnote.weight(.medium))
                        .frame(minWidth: 96, minHeight: 44)
                        .buttonStyle(.glass)
                }

                Button {
                    if timer.isRunning { timer.pause() } else { timer.start() }
                } label: {
                    Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .frame(width: 68, height: 68)
                }
                .buttonStyle(.glassProminent)
                .tint(Ink.glow(isFocus: isFocus))
                .accessibilityLabel(timer.isRunning ? "Mettre en pause" : "Démarrer")
            }
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .bentoSurface(
            tint: Ink.glow(isFocus: isFocus),
            accent: Ink.glowFar(isFocus: isFocus),
            corner: 36
        )
    }

    /// Une session interrompue compte pour le temps reellement passe, pas pour
    /// sa duree prevue.
    private func endEarly() {
        context.insert(FocusSession(
            durationSeconds: timer.elapsed,
            isFocus: isFocus,
            projectID: timer.activeProjectID,
            taskID: timer.activeTaskID
        ))
        if isFocus { timer.switchToRest() } else { timer.switchToFocus() }
    }

    private func formatted(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

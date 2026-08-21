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
    }

    @ViewBuilder
    private var sceneArea: some View {
        if settings.brainEnabled {
            // Remplace par BrainView en Task 10.
            Color.clear
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

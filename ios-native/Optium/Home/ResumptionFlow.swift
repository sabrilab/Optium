import SwiftData
import SwiftUI

/// Le parcours d'une reprise : on travaille, puis on ferme — directement, ou
/// par la porte.
struct ResumptionFlow: View {
    let thread: WorkThread

    @Environment(AppSettings.self) private var settings
    @Environment(ActionLog.self) private var actions
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(\.dismiss) private var dismiss

    /// La lecture mesurée, sauf si le forçage de développement l'écrase.
    private var reading: ClarityReading {
        if let forced = settings.clarityOverride {
            return .forced(forced, window: clarityStore.reading.window)
        }
        return clarityStore.reading
    }

    private enum Step { case working, gate, held, closed }
    @State private var step: Step = .working

    var body: some View {
        ZStack {
            InkBackground()

            switch step {
            case .working:
                ResumptionScreen(thread: thread, onPause: pause, onClose: attemptClose)
            case .gate:
                GateScreen(thread: thread, onClosed: { step = .closed }, onHeld: { step = .held })
            case .held:
                HeldScreen(thread: thread, onDone: { dismiss() })
            case .closed:
                ClosedScreen(thread: thread, onDone: { dismiss() })
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .onAppear(perform: start)
    }

    private func start() {
        let now = Date()
        thread.startResumption(
            clarity: clarityStore.currentLevel() ?? .medium,
            inWindow: reading.window.contains(now),
            at: now
        )
        LiveActivityController.start(thread: thread, reading: reading, landing: nil)
    }

    private func pause() {
        thread.pause(at: Date())
        Task { await LiveActivityController.end() }
        dismiss()
    }

    /// **Le seul refus de l'application.**
    ///
    /// Une décision prise à clarté basse ne se ferme pas d'une tape. Tout le
    /// reste se ferme directement — et c'est cette rareté qui rend le refus
    /// acceptable plutôt qu'agaçant.
    private func attemptClose() {
        // **La porte lit l'instant, jamais le dernier rafraichissement.**
        switch thread.closingOutcome(clarity: clarityStore.currentLevel()) {
        case .gate:
            // Le retour precede l'ecran : la main sait qu'on l'arrete avant
            // que l'oeil ait lu pourquoi.
            Feedback.play(.gate)
            Chime.play(.gate)
            withAnimation(Motion.gate) { step = .gate }
        case .direct:
            thread.close(at: Date())
            actions.record("Fil fermé")
            Feedback.play(.threadClosed)
            Chime.play(.closed)
            Task { await LiveActivityController.end() }
            withAnimation(Motion.entrance) { step = .closed }
        }
    }
}

// ── Reprise en cours ──

/// « L'app est muette. Elle renseigne, elle ne demande rien. »
private struct ResumptionScreen: View {
    let thread: WorkThread
    let onPause: () -> Void
    let onClose: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(ClarityStore.self) private var clarityStore
    @Environment(\.scenePhase) private var scenePhase

    private var reading: ClarityReading {
        if let forced = settings.clarityOverride {
            return .forced(forced, window: clarityStore.reading.window)
        }
        return clarityStore.reading
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onPause) {
                    Label("Mettre en pause", systemImage: "pause.fill")
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                .tint(Ink.control)
                Spacer()
                Text(openedSince)
                    .font(.caption2.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            if settings.brainEnabled {
                BrainView(
                    fill: reading.brainFill,
                    base: reading.brainBase,
                    agitation: 0.35,
                    isDay: true,
                    isVisible: scenePhase == .active
                )
                .frame(maxHeight: .infinity)
            } else {
                Spacer()
            }

            VStack(alignment: .leading, spacing: 22) {
                Text(thread.phrase)
                    .font(.system(size: 21, weight: .light))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Le temps s'affiche mais rien ne le décompte : ce n'est pas
                // un minuteur, c'est une observation.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    DotMatrixText(
                        text: elapsed(at: context.date),
                        dot: 6,
                        gap: 3.5,
                        glow: Ink.focusGlow
                    )
                }

                Text(rank)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(action: onClose) {
                    Text("Fermer le fil")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.glass)
                .tint(Ink.control)
            }
            .padding(20)
            .bentoSurface(Ink.indigo, corner: 36)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var openedSince: String {
        let days = Calendar.current.dateComponents([.day], from: thread.createdAt, to: Date()).day ?? 0
        if days <= 0 { return "FIL OUVERT AUJOURD’HUI" }
        if days == 1 { return "FIL OUVERT DEPUIS HIER" }
        return "FIL OUVERT DEPUIS \(days) JOURS"
    }

    private var rank: String {
        let count = thread.resumptions.count
        let total = thread.summary().totalDuration
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let spent = hours > 0 ? "\(hours) h \(minutes) min en tout" : "\(minutes) min en tout"
        return "\(count)\(count == 1 ? "re" : "e") reprise · \(spent)"
    }

    /// Le temps ecoule, **au format de l'ile dynamique**.
    ///
    /// Les deux affichaient des chiffres differents pour la meme duree :
    /// « 07:42 » ici, « 7:42 » dans l'ile. Une activite en direct ne peut pas
    /// executer de code a chaque seconde — elle n'a que le style de minuterie
    /// du systeme — donc c'est l'application qui s'aligne, jamais l'inverse.
    ///
    /// Le systeme passe a `h:mm:ss` au-dela d'une heure ; on fait de meme.
    private func elapsed(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(thread.currentResumption?.startedAt ?? date)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        guard hours > 0 else { return String(format: "%d:%02d", minutes, seconds % 60) }
        return String(format: "%d:%02d:%02d", hours, minutes, seconds % 60)
    }
}

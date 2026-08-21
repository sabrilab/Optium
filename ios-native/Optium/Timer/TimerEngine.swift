import Foundation
import Observation

/// Etat du minuteur.
///
/// Volatile par nature : rien ici n'est persiste, hormis le compteur de
/// sessions qui vit dans `AppSettings`.
///
/// Le principe central : on memorise l'**instant de depart**, jamais un
/// compteur decremente. iOS suspend le processus des que l'application quitte
/// le premier plan ; un compteur cesserait alors d'etre mis a jour et
/// deriverait, alors qu'un horodatage survit intact. `refresh()` recalcule le
/// restant depuis cette date.
@Observable
@MainActor
final class TimerEngine {
    private(set) var mode: TimerMode = .focus
    private(set) var total: Int
    private(set) var remaining: Int
    private(set) var isRunning = false

    var activeTaskID: UUID?
    var activeProjectID: UUID?

    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let now: () -> Date

    init(settings: AppSettings, now: @escaping () -> Date = Date.init) {
        self.settings = settings
        self.now = now
        let seconds = settings.focusMinutes * 60
        self.total = seconds
        self.remaining = seconds
    }

    // ── Lectures derivees ──

    var elapsed: Int { total - remaining }

    var progress: Double {
        total == 0 ? 0 : Double(elapsed) / Double(total)
    }

    var isFinished: Bool { remaining <= 0 }

    /// L'instant ou la session se terminera, ou `nil` a l'arret. C'est cette
    /// date qui sert a programmer la notification locale de fin.
    var finishesAt: Date? {
        isRunning ? now().addingTimeInterval(TimeInterval(remaining)) : nil
    }

    // ── Commandes ──

    func start() {
        guard !isRunning else { return }
        // On recule l'instant de depart du temps deja ecoule : une reprise
        // apres pause repart du restant, pas du total.
        startedAt = now().addingTimeInterval(-TimeInterval(elapsed))
        isRunning = true
    }

    func pause() {
        isRunning = false
        startedAt = nil
    }

    func reset(to mode: TimerMode) {
        self.mode = mode
        let seconds = duration(for: mode)
        total = seconds
        remaining = seconds
        isRunning = false
        startedAt = nil
    }

    /// Recalcule le temps restant depuis l'instant de depart.
    ///
    /// A appeler a chaque battement d'affichage et au retour au premier plan.
    /// Idempotent : l'appeler deux fois de suite ne change rien.
    func refresh() {
        guard isRunning, let startedAt else { return }
        let spent = Int(now().timeIntervalSince(startedAt))
        remaining = max(0, total - spent)
    }

    func addTime(_ seconds: Int) {
        let previouslyElapsed = elapsed
        total += seconds
        remaining += seconds
        // L'instant de depart suit, sans quoi le prochain `refresh()` annulerait l'ajout.
        if isRunning { startedAt = now().addingTimeInterval(-TimeInterval(previouslyElapsed)) }
    }

    /// Passe en repos et le demarre. Une pause qu'il faut lancer a la main
    /// n'est pas une pause : on la demarre pour l'utilisateur.
    func switchToRest() {
        settings.sessionCount += 1
        let isLong = settings.sessionCount % settings.longRestInterval == 0
        let minutes = isLong ? settings.longRestMinutes : settings.restMinutes

        mode = .rest
        total = minutes * 60
        remaining = total
        startedAt = now()
        isRunning = true
    }

    /// Repasse en concentration, a l'arret : replonger doit rester un choix.
    func switchToFocus() {
        reset(to: .focus)
    }

    private func duration(for mode: TimerMode) -> Int {
        switch mode {
        case .focus: settings.focusMinutes * 60
        case .rest: settings.restMinutes * 60
        }
    }
}

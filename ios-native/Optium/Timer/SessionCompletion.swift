import AVFoundation
import Foundation
import SwiftData
import UIKit

/// Fin de session : carillon, retour haptique, enregistrement en base.
///
/// L'enregistrement est separe des effets sensoriels pour rester testable :
/// `record` ne joue rien et ne vibre pas, `announce` s'en charge.
enum SessionCompletion {

    /// Enregistre la session qui vient de se terminer.
    ///
    /// - Returns: `false` si le minuteur etait deja a l'arret, c'est-a-dire si
    ///   la session a deja ete enregistree. Le garde-fou est necessaire : le
    ///   battement d'affichage et le retour au premier plan peuvent tous deux
    ///   constater la fin dans la meme seconde.
    @MainActor
    @discardableResult
    static func record(
        timer: TimerEngine,
        settings: AppSettings,
        context: ModelContext,
        tasks: [ProjectTask],
        coordinate: (lat: Double, lng: Double)?
    ) -> Bool {
        guard timer.isRunning else { return false }
        let wasFocus = timer.mode == .focus
        let duration = timer.total
        let taskID = timer.activeTaskID

        timer.pause()

        context.insert(FocusSession(
            durationSeconds: duration,
            isFocus: wasFocus,
            projectID: timer.activeProjectID,
            taskID: taskID,
            latitude: coordinate?.lat,
            longitude: coordinate?.lng
        ))

        if wasFocus, let taskID, let task = tasks.first(where: { $0.id == taskID }) {
            task.incrementPomodoro()
        }

        return true
    }

    /// Carillon et vibration, selon les reglages.
    @MainActor
    static func announce(settings: AppSettings) {
        if settings.soundEnabled { playChime() }
        if settings.hapticsEnabled {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Le lecteur est cree au premier carillon, pas au lancement : rien ne
    /// justifie de reserver une ressource audio tant qu'aucune session n'est finie.
    @MainActor private static var chime: AVAudioPlayer?

    @MainActor
    private static func playChime() {
        if chime == nil {
            guard let url = Bundle.main.url(forResource: "chime", withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.prepareToPlay()
            chime = player
        }
        chime?.currentTime = 0
        chime?.play()
    }
}

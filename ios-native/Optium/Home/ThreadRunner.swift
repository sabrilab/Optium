import Foundation

/// Les gestes qui touchent a une reprise en cours.
///
/// **Ils vivent ici parce qu'ils se font depuis deux endroits.** Mettre en
/// pause se declenche desormais depuis l'ecran du fil et depuis la carte de
/// l'accueil ; dupliquer les deux lignes ferait diverger les deux chemins le
/// jour ou l'un des deux gagnerait une etape — et le symptome serait une
/// activite en direct qui survit a la pause, donc un chronometre qui continue
/// sur l'ecran verrouille alors que le fil est arrete.
@MainActor
enum ThreadRunner {
    /// Arrete la reprise et l'activite en direct.
    static func pause(_ thread: WorkThread, at date: Date = Date()) {
        thread.pause(at: date)
        Feedback.play(.held)
        Task { await LiveActivityController.end() }
    }
}

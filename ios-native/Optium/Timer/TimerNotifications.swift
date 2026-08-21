import Foundation
import UserNotifications

/// Notification locale programmee a l'avance pour l'instant de fin.
///
/// Le battement d'affichage ne tourne qu'au premier plan : quand l'application
/// est fermee, cette notification est le seul mecanisme capable de prevenir
/// l'utilisateur.
enum TimerNotifications {
    private static let identifier = "optium.session.fin"

    static func schedule(at date: Date, mode: TimerMode) async {
        await cancel()

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        switch mode {
        case .focus:
            content.title = "Session terminée 🎯"
            content.body = "C’est l’heure de la pause."
        case .rest:
            content.title = "Pause terminée ☕"
            content.body = "Prêt à replonger ?"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        )
        try? await center.add(request)
    }

    static func cancel() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
